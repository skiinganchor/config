FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEVENV_VERSION=latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl git xz-utils sudo && \
    rm -rf /var/lib/apt/lists/*

# Install Nix (single-user)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Add nix to PATH
ENV PATH="/home/vscode/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"

# Install devenv
RUN . /home/vscode/.nix-profile/etc/profile.d/nix.sh && \
    nix profile install github:cachix/devenv/${DEVENV_VERSION} --accept-flake-config && \
    nix profile install nixpkgs#direnv nixpkgs#cachix

# Configure direnv
RUN echo 'eval "$(direnv hook bash)"' >> /home/vscode/.bashrc
