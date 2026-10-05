#!/usr/bin/env bash
# Memaket plugin OnlyOffice ReadPaper menjadi berkas .plugin (zip) di
# build/integrations/. Berkas itu dipasang lewat Plugin Manager OnlyOffice
# ("Pasang plugin secara manual" / "Install plugin manually").
#
# Isinya: integrations/onlyoffice/ + integrations/core/ (tanpa uji), dengan
# rujukan ../core/ di index.html diubah menjadi core/ karena di dalam paket
# keduanya satu folder.
#
#   scripts/package-onlyoffice-plugin.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/.."
src="$repo/integrations"
out="$repo/build/integrations"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$src/onlyoffice/config.json")"
guid="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["guid"])' "$src/onlyoffice/config.json")"

stage="$work/plugin"
mkdir -p "$stage/core/vendor"
cp -R "$src/onlyoffice/." "$stage/"
cp "$src/core/"*.js "$src/core/"*.css "$stage/core/"
cp "$src/core/vendor/citeproc.js" "$src/core/vendor/LICENSE-citeproc.txt" "$src/core/vendor/CITEPROC_VERSION" "$stage/core/vendor/"
cp "$repo/LICENSE" "$stage/LICENSE.txt"
sed -i 's#\.\./core/#core/#g' "$stage/index.html"

# Pastikan tidak ada rujukan yang tertinggal ke luar paket (selain ../v1/
# milik OnlyOffice sendiri).
if grep -n '\.\./' "$stage/index.html" | grep -v '\.\./v1/'; then
  echo "index.html masih merujuk ke luar paket." >&2
  exit 1
fi
for f in $(grep -o 'src="[^"]*"\|href="[^"]*"' "$stage/index.html" | sed 's/^[a-z]*="//; s/"$//' | grep -v '^https://\|^\.\./v1/'); do
  [ -f "$stage/$f" ] || { echo "Berkas tidak ada di paket: $f" >&2; exit 1; }
done
python3 - "$stage/config.json" <<'EOF'
import json, os, sys
cfg = json.load(open(sys.argv[1]))
base = os.path.dirname(sys.argv[1])
for v in cfg["variations"]:
    paths = list(v.get("icons", []))
    for theme in v.get("icons2", []):
        paths += [s["normal"] for k, s in theme.items() if isinstance(s, dict)]
    for p in paths + [v["url"]]:
        if not os.path.isfile(os.path.join(base, p)):
            sys.exit("config.json merujuk berkas yang tidak ada: " + p)
EOF

mkdir -p "$out"
name="readpaper-onlyoffice-$version.plugin"
rm -f "$out/$name"
(cd "$stage" && zip -qr -X "$out/$name" .)
echo "$out/$name  ($guid)"
