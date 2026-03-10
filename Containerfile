FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEVENV_VERSION=latest
ARG DEVENV_INSTALL_URI=github:cachix/devenv/${DEVENV_VERSION}
ARG NIX_INSTALL_SCRIPT=https://nixos.org/nix/install

COPY --chmod=0755 nix-entrypoint.sh /nix-entrypoint.sh
COPY nix.conf /tmp/nix.conf

# Install system dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    acl \
    bash \
    curl \
    git \
    sudo \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Fix Nix /tmp permission issue
RUN setfacl -k /tmp

# Prepare nix config
RUN mkdir -p /etc/nix \
 && echo "filter-syscalls = false" > /etc/nix/nix.conf

# Install Nix (multi-user daemon)
RUN curl -L ${NIX_INSTALL_SCRIPT} | sh -s -- \
    --daemon \
    --no-channel-add \
    --nix-extra-conf-file /tmp/nix.conf

# Add Nix to PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

# Start daemon briefly so nix works during build
RUN /nix-entrypoint.sh sleep 5

# Install devenv + tools globally
RUN nix profile install --profile /nix/var/nix/profiles/default \
    nixpkgs#direnv \
    nixpkgs#cachix \
    ${DEVENV_INSTALL_URI} \
    --accept-flake-config

# Configure cachix for devenv
RUN USER=root cachix use devenv

# Cleanup
RUN rm -rf /root/.cache/nix /tmp/nix.conf \
 && nix-collect-garbage --delete-old

# Switch to vscode user (devcontainers default)
USER vscode

# Configure direnv
RUN mkdir -p ~/.config/direnv \
 && printf '[whitelist]\nprefix = [ "/workspaces" ]\n' > ~/.config/direnv/config.toml \
 && echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# Start nix-daemon when container starts
ENTRYPOINT ["/nix-entrypoint.sh", "sleep", "infinity"]
