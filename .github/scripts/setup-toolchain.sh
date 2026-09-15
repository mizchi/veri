#!/usr/bin/env bash
set -euo pipefail

# The CI image is fixed because the Z3 distribution requires glibc 2.39.
[[ "$(uname -ms)" == 'Linux x86_64' ]]
# shellcheck source=.github/toolchain.env
source .github/toolchain.env

veri_download_dir=$(mktemp -d)
trap 'rm -rf "$veri_download_dir"' EXIT
veri_moon_dir="$HOME/.moon"
veri_moon_version=${VERI_MOON_VERSION//+/%2B}

fetch_verified() {
  local url=$1 digest=$2 destination=$3
  curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 \
    "$url" --output "$destination"
  printf '%s  %s\n' "$digest" "$destination" | sha256sum --check --status
}

fetch_verified \
  "https://cli.moonbitlang.com/binaries/$veri_moon_version/moonbit-linux-x86_64.tar.gz" \
  "$VERI_MOON_SHA256" "$veri_download_dir/moon.tar.gz"
fetch_verified \
  "https://cli.moonbitlang.com/cores/core-$veri_moon_version.tar.gz" \
  "$VERI_CORE_SHA256" "$veri_download_dir/core.tar.gz"
mkdir -p "$veri_moon_dir"
tar -xzf "$veri_download_dir/moon.tar.gz" -C "$veri_moon_dir"
tar -xzf "$veri_download_dir/core.tar.gz" -C "$veri_moon_dir/lib"
ln -sf moon "$veri_moon_dir/bin/moonx"
export PATH="$veri_moon_dir/bin:$PATH"
moon -C "$veri_moon_dir/lib/core" bundle --all --warn-list -a
moon -C "$veri_moon_dir/lib/core" bundle --target wasm-gc --warn-list -a

veri_z3_asset="z3-$VERI_Z3_VERSION-x64-glibc-2.39"
fetch_verified \
  "https://github.com/Z3Prover/z3/releases/download/z3-$VERI_Z3_VERSION/$veri_z3_asset.zip" \
  "$VERI_Z3_SHA256" "$veri_download_dir/z3.zip"
mkdir -p _build/ci-tools
unzip -q "$veri_download_dir/z3.zip" -d _build/ci-tools
node tools/setup-solvers.mjs
