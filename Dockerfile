# syntax=docker/dockerfile:1
FROM rust:1-slim-bookworm AS builder
WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Cache dependencies: Copy only manifests first
COPY Cargo.toml Cargo.lock ./
# Create dummy source files for each crate to allow dependency pre-build (optional, but skipping for simplicity here)
# Copy all workspace manifests
COPY crates/openfang-types/Cargo.toml ./crates/openfang-types/
COPY crates/openfang-memory/Cargo.toml ./crates/openfang-memory/
COPY crates/openfang-runtime/Cargo.toml ./crates/openfang-runtime/
COPY crates/openfang-wire/Cargo.toml ./crates/openfang-wire/
COPY crates/openfang-api/Cargo.toml ./crates/openfang-api/
COPY crates/openfang-kernel/Cargo.toml ./crates/openfang-kernel/
COPY crates/openfang-cli/Cargo.toml ./crates/openfang-cli/
COPY crates/openfang-channels/Cargo.toml ./crates/openfang-channels/
COPY crates/openfang-migrate/Cargo.toml ./crates/openfang-migrate/
COPY crates/openfang-skills/Cargo.toml ./crates/openfang-skills/
COPY crates/openfang-desktop/Cargo.toml ./crates/openfang-desktop/
COPY crates/openfang-hands/Cargo.toml ./crates/openfang-hands/
COPY crates/openfang-extensions/Cargo.toml ./crates/openfang-extensions/
COPY xtask/Cargo.toml ./xtask/

# Now copy actual source and build
COPY crates ./crates
COPY xtask ./xtask
COPY agents ./agents
COPY packages ./packages
# Optional build args for dev environments to speed up compilation
# Example: docker build --build-arg LTO=false --build-arg CODEGEN_UNITS=16 .
ARG LTO=true
ARG CODEGEN_UNITS=1
ENV CARGO_PROFILE_RELEASE_LTO=${LTO} \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=${CODEGEN_UNITS}
RUN cargo build --release --bin openfang

FROM rust:1-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    ffmpeg \
    && npm install -g @anthropic-ai/claude-code \
    && pip3 install --break-system-packages playwright yt-dlp \
    && playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/release/openfang /usr/local/bin/
COPY --from=builder /build/agents /opt/openfang/agents

# Run as non-root user so Claude Code CLI allows --dangerously-skip-permissions
RUN useradd -m -s /bin/bash openfang
EXPOSE 4200
VOLUME /data
ENV OPENFANG_HOME=/data
ENV OPENFANG_API_LISTEN=0.0.0.0:4200
RUN mkdir -p /data /home/openfang/.claude && chown -R openfang:openfang /data /home/openfang/.claude
USER openfang
ENTRYPOINT ["openfang"]
CMD ["start"]
