#!/usr/bin/env bash
# Menguji kode editor plugin OnlyOffice di OnlyOffice sungguhan
# (ONLYOFFICE DocumentBuilder, di dalam Docker Debian 12): menyisipkan
# sitasi dan daftar pustaka, menulis custom XML part, menyimpan .docx,
# membukanya lagi, lalu memeriksa semuanya bertahan.
#
# Ini tidak menguji panel plugin (itu butuh editor lengkap), hanya fungsi
# yang dikirim lewat callCommand — bagian yang paling bergantung pada API
# OnlyOffice.
#
#   scripts/test-onlyoffice-docbuilder.sh            # DocumentBuilder 9.4.0
#   DOCBUILDER_VERSION=9.3.0 scripts/test-onlyoffice-docbuilder.sh
set -euo pipefail

version="${DOCBUILDER_VERSION:-9.4.0}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/.."
cache="$repo/build/docbuilder"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$cache"
tarball="$cache/onlyoffice-documentbuilder-$version.tar.xz"
if [ ! -f "$tarball" ]; then
  echo "Mengunduh DocumentBuilder $version…"
  curl -fsSL -o "$tarball.part" \
    "https://github.com/ONLYOFFICE/DocumentBuilder/releases/download/v$version/onlyoffice-documentbuilder-linux-x86_64.tar.xz"
  mv "$tarball.part" "$tarball"
fi

mkdir -p "$work/out"
node "$repo/integrations/onlyoffice/test/docbuilder.js" gen "$work"

docker run --rm -v "$work:/work" -v "$tarball:/db.tar.xz:ro" debian:12 bash -c '
  set -e
  apt-get update -qq >/dev/null && apt-get install -y -qq xz-utils libglib2.0-0 >/dev/null
  mkdir -p /db && tar xJf /db.tar.xz -C /db
  cd /work && LD_LIBRARY_PATH=/db/opt/onlyoffice/documentbuilder \
    /db/opt/onlyoffice/documentbuilder/docbuilder test.docbuilder 2>&1 | grep -v "license is invalid" || true
  chmod -R a+rw /work/out
'

node "$repo/integrations/onlyoffice/test/docbuilder.js" check "$work"
