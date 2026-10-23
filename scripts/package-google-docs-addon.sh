#!/usr/bin/env bash
# Menyiapkan proyek Apps Script add-on Google Docs ReadPaper di
# build/integrations/google-docs/ (siap untuk `clasp push`), plus zip-nya.
#
# Apps Script hanya mengenal berkas .gs/.js dan .html, jadi inti sitasi
# (integrations/core/) dibungkus menjadi berkas HTML berisi <script> yang
# disisipkan Sidebar.html lewat include().
#
#   scripts/package-google-docs-addon.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/.."
src="$repo/integrations"
out="$repo/build/integrations/google-docs"
rm -rf "$out"
mkdir -p "$out"

cp "$src/google-docs/Code.js" "$src/google-docs/Sidebar.html" "$src/google-docs/appsscript.json" "$out/"
wrap() { # wrap <berkas js> <nama html>
  { printf '<script>\n'; cat "$1"; printf '\n</script>\n'; } > "$out/$2.html"
}
wrap "$src/core/vendor/citeproc.js" rp-citeproc
wrap "$src/core/citations.js" rp-citations
wrap "$src/core/readpaper-api.js" rp-readpaper-api
wrap "$src/core/controller.js" rp-controller
wrap "$src/core/host.js" rp-host
wrap "$src/core/ui.js" rp-ui
wrap "$src/google-docs/gdocs-bridge.js" rp-gdocs-bridge
{ printf '<style>\n'; cat "$src/core/ui.css"; printf '\n</style>\n'; } > "$out/rp-ui-css.html"

# Setiap include() di Sidebar.html harus punya berkasnya.
for name in $(grep -o "include('[^']*')" "$out/Sidebar.html" | sed "s/include('//; s/')//"); do
  [ -f "$out/$name.html" ] || { echo "Berkas include tidak ada: $name.html" >&2; exit 1; }
done

version="$(grep -o '"version": *"[^"]*"' "$src/onlyoffice/config.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
zip="$repo/build/integrations/readpaper-google-docs-$version.zip"
rm -f "$zip"
(cd "$out" && zip -qrX "$zip" .)
echo "$out"
echo "$zip"
