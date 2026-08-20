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

  nix store prefetch-file --unpack --json \
    "https://github.com/QubesOS/${repository}/archive/refs/${ref}.tar.gz" 2>/dev/null \
    | jq -r .hash
}

update_package() {
  local version_regex="$1"
  local package="$2"
  local repository="$3"
  local package_dir="$4"
  local pin_file="$package_dir/default.nix"
  local current_version
  local current_hash
  local version
  local hash

  current_version="$(sed -n -E 's|^  version = "([^"]*)";|\1|p' "$pin_file")"
  current_hash="$(sed -n -E 's|^ +hash = "([^"]*)";|\1|p' "$pin_file")"
  [[ -n "$current_version" && -n "$current_hash" ]] || {
    printf 'unable to read package pin from %s\n' "$pin_file" >&2
    return 1
  }

  version="$(latest_tag "$version_regex" "$repository")"
  version="${version#v}"
  if [[ -n "$qubesBranch" ]]; then
    hash="$(source_hash "$repository" "heads/$qubesBranch")"
  else
    hash="$(source_hash "$repository" "tags/v$version")"
  fi

  if [[ "$current_version" == "$version" && "$current_hash" == "$hash" ]]; then
    printf '[-] No update: %s %s\n' "$package" "$current_version"
    return
  fi

  printf '[+] Update available: %s %s -> %s\n' "$package" "$current_version" "$version"
  printf '    hash: %s -> %s\n' "$current_hash" "$hash"
  sed -i -E \
    -e "s|^  version = \"[^\"]*\";|  version = \"$version\";|" \
    -e "s|^   *hash = \"[^\"]*\";|  hash = \"$hash\";|" \
    "$pin_file"
  printf '    applied: %s\n' "$pin_file"
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
)

for package_spec in "${packages[@]}"; do
  IFS='|' read -r version_regex package repository package_dir <<<"$package_spec"
  update_package "$version_regex" "$package" "$repository" "$package_dir"
done

# split-gpg publishes tags but has no release4.x branch.
qubesBranch="" update_package "v([0-9.]+)" \
  qubes-gpg-split qubes-app-linux-split-gpg pkgs/qubes-gpg-split
