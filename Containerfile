FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEVENV_VERSION=latest

USER vscode
WORKDIR /home/vscode

# install system deps
USER root
RUN apt-get update && \
    apt-get install -y curl git xz-utils sudo && \
    rm -rf /var/lib/apt/lists/*

# install nix as vscode user (single-user mode)
USER vscode
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# make nix available in future shells
RUN echo '. "$HOME/.nix-profile/etc/profile.d/nix.sh"' >> ~/.bashrc

# install devenv + tools
RUN . "$HOME/.nix-profile/etc/profile.d/nix.sh" && \
    nix profile install github:cachix/devenv/${DEVENV_VERSION} --accept-flake-config && \
    nix profile install nixpkgs#direnv nixpkgs#cachix

# enable direnv
RUN echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
