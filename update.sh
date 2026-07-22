#!/usr/bin/env nix
#!nix shell nixpkgs#gnused nixpkgs#curl nixpkgs#jq nixpkgs#nix --command bash
set -euo pipefail

qubesVersion="${1:-${QUBES_VERSION:-4.3}}"
qubesVersionRegex="${qubesVersion//./\.}"
qubesOldVersion="${1:-${QUBES_OLD_VERSION:-4.2}}"
qubesOldVersionRegex="${qubesOldVersion//./\.}"
usbProxyMajorVersion="${USB_PROXY_MAJOR_VERSION:-${qubesVersion}}"
# Set QUBES_BRANCH to an empty value to update hashes for the selected tags.
qubesBranch="${QUBES_BRANCH-release${qubesVersion}}"

latest_tag() {
  local version_regex="$1"
  local repository="$2"
  local tags
  local tag
  local latest=""

  # Some Qubes repositories publish tags but no GitHub releases.
  tags="$(curl --fail --silent --show-error \
    "https://api.github.com/repos/QubesOS/${repository}/releases?per_page=100" \
    | jq -r '.[].tag_name' \
    | while read -r tag; do
        [[ "$tag" =~ $version_regex ]] && printf '%s\n' "$tag"
      done \
    | sort -V)"

  if [[ -z "$tags" ]]; then
    tags="$(curl --fail --silent --show-error \
      "https://api.github.com/repos/QubesOS/${repository}/tags?per_page=100" \
      | jq -r '.[].name' \
      | while read -r tag; do
          [[ "$tag" =~ $version_regex ]] && printf '%s\n' "$tag"
        done \
      | sort -V)"
  fi

  [[ -n "$tags" ]] || {
    printf 'no matching tag found for %s in %s\n' "$version_regex" "$repository" >&2
    return 1
  }

  while read -r tag; do
    [[ -n "$tag" ]] && latest="$tag"
  done <<<"$tags"
  printf '%s\n' "$latest"
}

source_hash() {
  local repository="$1"
  local ref="$2"
  local base32_hash

  base32_hash="$(nix-prefetch-url --unpack \
    "https://github.com/QubesOS/${repository}/archive/refs/${ref}.tar.gz" 2>/dev/null)"
  nix hash convert --hash-algo sha256 --from nix32 --to sri "$base32_hash"
}

update_package() {
  local version_regex="$1"
  local package="$2"
  local repository="$3"
  local package_dir="$4"
  local version
  local hash

  version="$(latest_tag "$version_regex" "$repository")"
  if [[ -n "$qubesBranch" ]]; then
    hash="$(source_hash "$repository" "heads/$qubesBranch")"
  else
    hash="$(source_hash "$repository" "tags/$version")"
  fi

  sed -i -E \
    -e "s|^  version = \"[^\"]*\";|  version = \"${version#v}\";|" \
    -e "s|^   *hash = \"[^\"]*\";|  hash = \"$hash\";|" \
    "$package_dir/default.nix"
  printf '%s: %s (%s)\n' "$package" "${version#v}" "$hash"
}

# Each row contains: version regex, flake package, GitHub repository, package directory.
packages=(
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-core-qubesdb|qubes-core-qubesdb|pkgs/qubes-core-qubesdb"
  "v(${qubesOldVersionRegex}\.[0-9.]+)|qubes-core-vchan-xen|qubes-core-vchan-xen|pkgs/qubes-core-vchan-xen"
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-gui-common|qubes-gui-common|pkgs/qubes-gui-common"
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-core-agent-linux|qubes-core-agent-linux|pkgs/qubes-core-agent-linux"
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-core-qrexec|qubes-core-qrexec|pkgs/qubes-core-qrexec"
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-gui-agent-linux|qubes-gui-agent-linux|pkgs/qubes-gui-agent-linux"
  "v(${qubesVersionRegex}\.[0-9.]+)|qubes-linux-utils|qubes-linux-utils|pkgs/qubes-linux-utils"
  "v(${usbProxyMajorVersion}\.[0-9.]+)|qubes-usb-proxy|qubes-app-linux-usb-proxy|pkgs/qubes-usb-proxy"
#"v([0-9.]+)|qubes-gpg-split|qubes-app-linux-split-gpg|pkgs/qubes-gpg-split"
)

for package_spec in "${packages[@]}"; do
  IFS='|' read -r version_regex package repository package_dir <<<"$package_spec"
  update_package "$version_regex" "$package" "$repository" "$package_dir"
done
