#!/usr/bin/env bash
# Download .deb release assets from package repositories.

set -euo pipefail

out_dir="${OUT_DIR:-dist}"
tbfix_repo="${TBFIX_REPO:-AppMana/thunderbolt-tbfix}"
tbfix_tag="${TBFIX_TAG:-v1.4}"
ibverbs_repo="${IBVERBS_REPO:-AppMana/forks-thunderbolt-ibverbs}"
ibverbs_tag="${IBVERBS_TAG:-}"

mkdir -p "$out_dir"

download_tag() {
	local repo="$1"
	local tag="$2"
	[[ -n "$tag" ]] || return 0
	printf '==> Downloading %s %s\n' "$repo" "$tag"
	gh release download "$tag" -R "$repo" -p '*.deb' -D "$out_dir" --clobber
	gh release download "$tag" -R "$repo" -p '*.deb.sha256' -D "$out_dir" --clobber || true
}

download_tag "$tbfix_repo" "$tbfix_tag"
download_tag "$ibverbs_repo" "$ibverbs_tag"

find "$out_dir" -maxdepth 1 -type f -name '*.deb' -print | sort
