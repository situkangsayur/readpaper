#!/usr/bin/env bash
# Mengambil citeproc-js dari paket npm resminya (`citeproc`) dan menaruhnya di
# integrations/core/vendor/ supaya bisa dimuat sebagai <script> biasa di
# OnlyOffice dan Word, sekaligus di-require() oleh uji Node.
#
# Paket npm hanya membawa citeproc_commonjs.js, yang diakhiri
# `module.exports = CSL`. Satu-satunya perubahan yang dibuat di sini adalah
# membungkus baris itu dengan pengecekan `typeof module`, supaya berkasnya
# tidak melempar galat saat dimuat di peramban. Selebihnya byte demi byte sama.
#
#   scripts/vendor-citeproc.sh            # versi yang tercatat di bawah
#   scripts/vendor-citeproc.sh 2.4.64     # versi lain
set -euo pipefail

version="${1:-2.4.63}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$here/../integrations/core/vendor"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cd "$work"
npm pack --silent "citeproc@$version" >/dev/null   # npm memeriksa integritasnya
tar xzf "citeproc-$version.tgz"

src="package/citeproc_commonjs.js"
grep -q '^module.exports = CSL' "$src" || {
  echo "Baris 'module.exports = CSL' tidak ditemukan; periksa berkas $src." >&2
  exit 1
}

mkdir -p "$dest"
sed 's/^module\.exports = CSL/if (typeof module !== "undefined" \&\& module.exports) { module.exports = CSL; }/' \
  "$src" > "$dest/citeproc.js"
cp package/LICENSE "$dest/LICENSE-citeproc.txt"
echo "$version" > "$dest/CITEPROC_VERSION"

echo "citeproc $version -> $dest/citeproc.js"
