#!/bin/sh
set -eu

target="${1:-.#qubes-core-agent-linux}"

nix --extra-experimental-features "nix-command flakes" build "$target" --show-trace --verbose
