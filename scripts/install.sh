#!/usr/bin/env bash
set -euo pipefail

version=${1:-}
if [[ ! "$version" =~ ^(v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)|latest)$ ]]; then
  echo "setup-jev: version must match vMAJOR.MINOR.PATCH or latest" >&2
  exit 1
fi

repository=https://github.com/stefafafan/jev
if [[ "$version" == latest ]]; then
  release_url=$(curl --retry 3 --silent --show-error --fail --location \
    --output /dev/null --write-out '%{url_effective}' "$repository/releases/latest")
  version=${release_url##*/}
  if [[ ! "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "setup-jev: latest release did not resolve to a stable version" >&2
    exit 1
  fi
fi

case "${RUNNER_OS:-}" in
  Linux) os=linux; extension=tar.gz ;;
  macOS) os=darwin; extension=tar.gz ;;
  *) echo "setup-jev: unsupported runner OS: ${RUNNER_OS:-unknown}" >&2; exit 1 ;;
esac

case "${RUNNER_ARCH:-}" in
  X64) arch=amd64 ;;
  ARM64) arch=arm64 ;;
  *) echo "setup-jev: unsupported runner architecture: ${RUNNER_ARCH:-unknown}" >&2; exit 1 ;;
esac

release_version=${version#v}
name="jev_${release_version}_${os}_${arch}"
archive="$name.$extension"
download_url="$repository/releases/download/$version"
work_dir=$(mktemp -d "${RUNNER_TEMP:?RUNNER_TEMP is required}/setup-jev.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

curl --retry 3 --silent --show-error --fail --location \
  --output "$work_dir/$archive" "$download_url/$archive"
curl --retry 3 --silent --show-error --fail --location \
  --output "$work_dir/checksums.txt" "$download_url/checksums.txt"

expected=$(awk -v archive="$archive" '$2 == archive || $2 == "*" archive { print $1 }' "$work_dir/checksums.txt")
if [[ ! "$expected" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "setup-jev: checksum is missing for $archive" >&2
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$work_dir/$archive" | awk '{ print $1 }')
else
  actual=$(shasum -a 256 "$work_dir/$archive" | awk '{ print $1 }')
fi
if [[ "$actual" != "$expected" ]]; then
  echo "setup-jev: checksum verification failed for $archive" >&2
  exit 1
fi

tar -xzf "$work_dir/$archive" -C "$work_dir"
install_dir="$RUNNER_TEMP/setup-jev/$release_version/$os-$arch"
mkdir -p "$install_dir"
install -m 0755 "$work_dir/$name/jev" "$install_dir/jev"

installed_version=$("$install_dir/jev" --version)
if [[ "$installed_version" != "jev $release_version" ]]; then
  echo "setup-jev: installed binary reported unexpected version: $installed_version" >&2
  exit 1
fi

printf '%s\n' "$install_dir" >> "${GITHUB_PATH:?GITHUB_PATH is required}"
printf 'version=%s\n' "$release_version" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
echo "Installed jev $release_version"
