#!/usr/bin/env bash
# Download .deb release assets from package repositories.

set -euo pipefail

out_dir="${OUT_DIR:-dist}"
# tbfix, tbrxe and the provider ship from one unified repo. The current
# release tag carries the tbrxe-era stack; the legacy tag pins the last
# published thunderbolt-ibverbs generation (the legacy driver is frozen at
# that version until every host has migrated to tbrxe -- indexing a newer
# legacy deb would trigger unplanned fleet driver upgrades).
tbfix_repo="${TBFIX_REPO:-AppMana/forks-thunderbolt}"
tbfix_tag="${TBFIX_TAG:-v2.48}"
ibverbs_repo="${IBVERBS_REPO:-AppMana/forks-thunderbolt}"
ibverbs_tag="${IBVERBS_TAG:-v2.35}"
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

# Current stack: patched core, thunderbolt_frame engine (v2.42 rename of
# tbrxe: deb thunderbolt-frame-dkms, tools deb thunderbolt-frame-tools),
# userspace provider.
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-tbfix-dkms_*.deb'
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-tbfix-dkms_*.deb.sha256' || true
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-frame-dkms_*.deb'
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-frame-dkms_*.deb.sha256' || true
download_pattern "$tbfix_repo" "$tbfix_tag" 'thunderbolt-frame-tools_*.deb' || true
download_pattern "$tbfix_repo" "$tbfix_tag" "usb4-rdma-provider_*${codename}_amd64.deb"

# Legacy generation: frozen thunderbolt-ibverbs plus its matched core and
# provider, kept indexed for the not-yet-migrated hosts and for rollback.
if [[ -n "$ibverbs_tag" ]]; then
	download_pattern "$ibverbs_repo" "$ibverbs_tag" 'thunderbolt-ibverbs-dkms_*.deb'
	download_pattern "$ibverbs_repo" "$ibverbs_tag" 'thunderbolt-ibverbs-tools_*.deb' || \
		printf 'warning: release %s predates thunderbolt-ibverbs-tools\n' "$ibverbs_tag" >&2
	download_pattern "$ibverbs_repo" "$ibverbs_tag" "usb4-rdma-provider_*${codename}_amd64.deb"
	download_pattern "$ibverbs_repo" "$ibverbs_tag" 'thunderbolt-tbfix-dkms_*.deb'
	download_pattern "$ibverbs_repo" "$ibverbs_tag" 'thunderbolt-tbfix-dkms_*.deb.sha256' || true
fi

find "$out_dir" -maxdepth 1 -type f -name '*.deb' -print | sort
