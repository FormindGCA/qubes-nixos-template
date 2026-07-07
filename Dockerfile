# Use the official Nix Docker image so Nix is only installed inside the container.
FROM nixos/nix:latest

# The upstream image is usable as a single-user root container. Keep Nix from
# requiring a nixbld group, which is not present in all image revisions.
ENV NIX_CONFIG="build-users-group ="

WORKDIR /workspace

# Copy repository contents into the container.
COPY . /workspace

# Verify Nix is available.
RUN nix --version

CMD ["/bin/sh"]
