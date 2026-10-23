#!/usr/bin/env bash
# Memaket ekstensi LibreOffice ReadPaper menjadi berkas .oxt di
# build/integrations/. Dipasang lewat Alat → Pengelola Ekstensi → Tambah, atau
#   unopkg add build/integrations/readpaper-libreoffice-<versi>.oxt
#
#   scripts/package-libreoffice-extension.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/.."
src="$repo/integrations/libreoffice"
out="$repo/build/integrations"

version="$(python3 -I -c 'import sys,xml.dom.minidom as m; print(m.parse(sys.argv[1]).getElementsByTagName("version")[0].getAttribute("value"))' "$src/description.xml")"
mkdir -p "$out"
file="$out/readpaper-libreoffice-$version.oxt"
rm -f "$file"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
stage="$work/oxt"
mkdir -p "$stage"
cp -R "$src/META-INF" "$src/description" "$src/icons" "$src/description.xml" "$src/Addons.xcu" "$stage/"
mkdir -p "$stage/python/pythonpath/readpaper_lo"
cp "$src/python/readpaper_lo.py" "$stage/python/"
cp "$src/python/pythonpath/readpaper_lo/"*.py "$stage/python/pythonpath/readpaper_lo/"
cp "$repo/LICENSE" "$stage/LICENSE.txt"
(cd "$stage" && zip -qrX "$file" .)
echo "$file"
