# Use the official Nix Docker image so Nix is only installed inside the container.
FROM nixos/nix:latest

WORKDIR /workspace

# Copy repository contents into the container.
COPY . /workspace

# Verify Nix is available.
RUN nix --version

CMD ["/bin/sh"]
