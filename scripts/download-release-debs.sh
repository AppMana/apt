#!/usr/bin/env bash
# Download .deb release assets from package repositories.

set -euo pipefail

out_dir="${OUT_DIR:-dist}"
# tbfix and ibverbs now ship from one unified repo and one release tag.
tbfix_repo="${TBFIX_REPO:-AppMana/forks-thunderbolt}"
tbfix_tag="${TBFIX_TAG:-v1.9}"
ibverbs_repo="${IBVERBS_REPO:-AppMana/forks-thunderbolt}"
ibverbs_tag="${IBVERBS_TAG:-v1.9}"
codename="${CODENAME:-noble}"

mkdir -p "$out_dir"

download_pattern() {
	local repo="$1"
	local tag="$2"
	local pattern="$3"
	[[ -n "$tag" ]] || return 0
	printf '==> Downloading %s %s %s\n' "$repo" "$tag" "$pattern"
	gh release download "$tag" -R "$repo" -p "$pattern" -D "$out_dir" --clobber
}

download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-tbfix-dkms_*.deb'
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-tbfix-dkms_*.deb.sha256' || true

if [[ -n "$ibverbs_tag" ]]; then
	download_pattern "$ibverbs_repo" "$ibverbs_tag" 'thunderbolt-ibverbs-dkms_*.deb'
	download_pattern "$ibverbs_repo" "$ibverbs_tag" "usb4-rdma-provider_*~${codename}_amd64.deb"
fi

find "$out_dir" -maxdepth 1 -type f -name '*.deb' -print | sort
