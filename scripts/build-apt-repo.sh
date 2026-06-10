#!/usr/bin/env bash
# Build a signed apt repository tree from a directory of .deb files.

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  scripts/build-apt-repo.sh <deb-dir> <public-dir>

Environment:
  CODENAME      Apt codename. Default: noble.
  COMPONENT     Apt component. Default: main.
  ORIGIN        Release Origin. Default: AppMana.
  LABEL         Release Label. Default: AppMana.
  SIGNING_KEY   Optional GPG key fingerprint/keyid to sign with.
  SIGNING_PASSPHRASE
                Optional passphrase for SIGNING_KEY.
EOF
}

case "${1:-}" in
	-h|--help) usage; exit 0 ;;
esac

deb_dir="${1:-}"
public_dir="${2:-}"
[[ -n "$deb_dir" && -n "$public_dir" ]] || { usage >&2; exit 1; }
[[ -d "$deb_dir" ]] || { printf 'error: deb dir not found: %s\n' "$deb_dir" >&2; exit 1; }

codename="${CODENAME:-noble}"
component="${COMPONENT:-main}"
origin="${ORIGIN:-AppMana}"
label="${LABEL:-AppMana}"
arch="amd64"

command -v dpkg-scanpackages >/dev/null 2>&1 || {
	printf 'error: dpkg-scanpackages is required; install dpkg-dev\n' >&2
	exit 1
}

rm -rf "$public_dir"
install -d -m 0755 \
	"$public_dir/pool/$component" \
	"$public_dir/dists/$codename/$component/binary-$arch"

find "$deb_dir" -maxdepth 1 -type f -name '*.deb' -print0 |
	while IFS= read -r -d '' deb; do
		cp "$deb" "$public_dir/pool/$component/"
	done

if ! find "$public_dir/pool/$component" -type f -name '*.deb' | grep -q .; then
	printf 'error: no .deb files found in %s\n' "$deb_dir" >&2
	exit 1
fi

(
	cd "$public_dir"
	dpkg-scanpackages -m "pool/$component" /dev/null \
		> "dists/$codename/$component/binary-$arch/Packages"
	gzip -9cn "dists/$codename/$component/binary-$arch/Packages" \
		> "dists/$codename/$component/binary-$arch/Packages.gz"
)

release="$public_dir/dists/$codename/Release"
{
	printf 'Origin: %s\n' "$origin"
	printf 'Label: %s\n' "$label"
	printf 'Suite: %s\n' "$codename"
	printf 'Codename: %s\n' "$codename"
	printf 'Date: %s\n' "$(date -Ru)"
	printf 'Architectures: %s\n' "$arch"
	printf 'Components: %s\n' "$component"
	printf 'Description: AppMana package repository\n'
	printf 'MD5Sum:\n'
	(
		cd "$public_dir/dists/$codename"
		find "$component" -type f | sort | while read -r file; do
			printf ' %s %16d %s\n' "$(md5sum "$file" | awk '{print $1}')" "$(stat -c '%s' "$file")" "$file"
		done
	)
	printf 'SHA256:\n'
	(
		cd "$public_dir/dists/$codename"
		find "$component" -type f | sort | while read -r file; do
			printf ' %s %16d %s\n' "$(sha256sum "$file" | awk '{print $1}')" "$(stat -c '%s' "$file")" "$file"
		done
	)
} > "$release"

if [[ -n "${SIGNING_KEY:-}" ]]; then
	gpg_args=(--batch --yes --local-user "$SIGNING_KEY")
	if [[ -n "${SIGNING_PASSPHRASE:-}" ]]; then
		gpg_args+=(--pinentry-mode loopback --passphrase "$SIGNING_PASSPHRASE")
	fi
	gpg "${gpg_args[@]}" --detach-sign --armor -o "$release.gpg" "$release"
	gpg "${gpg_args[@]}" --clearsign -o "$public_dir/dists/$codename/InRelease" "$release"
fi

cat > "$public_dir/index.html" <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>AppMana Apt Repository</title></head>
<body>
<h1>AppMana Apt Repository</h1>
<pre>deb [arch=amd64 signed-by=/usr/share/keyrings/appmana-archive-keyring.gpg] https://appmana.github.io/apt $codename $component</pre>
<p>Packages are under <a href="pool/$component/">pool/$component/</a>.</p>
</body>
</html>
EOF

printf 'Built apt repository at %s\n' "$public_dir"
