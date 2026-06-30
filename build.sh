#!/bin/sh
#nix --extra-experimental-features "nix-command flakes" build .#packages.x86_64-linux.qubes-core-qubesdb --show-trace --verbose
nix --extra-experimental-features "nix-command flakes" build .#packages.x86_64-linux.qubes-core-agent-linux --show-trace --verbose
