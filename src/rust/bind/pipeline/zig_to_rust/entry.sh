ZIG_VERSION="0.14.0" && \
    curl -sSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-aarch64-${ZIG_VERSION}.tar.xz" -o "zig.tar.xz" && \
    mkdir -p /opt/zig && \
    tar -xf zig.tar.xz -C /opt/zig --strip-components=1 && \
    rm zig.tar.xz && \
    ln -s /opt/zig/zig /usr/local/bin/zig

# Install Rust with automatic yes to all prompts
# ""
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Cargo to PATH
PATH="/root/.cargo/bin:${PATH}"

# Add common Rust components
bash -c "rustup component add rustfmt clippy" || true
bash -c "rustup default nightly" || true

# Create workspace directory and move target
mkdir -p ${WORKSPACE}
mv /target ${WORKSPACE}/${NAME}
ls -a ${WORKSPACE}

echo Complete
