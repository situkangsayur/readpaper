#!/usr/bin/env bash
# Membuat ikon PNG untuk plugin OnlyOffice dan add-in Word dari SVG ikon
# aplikasi (assets/icon/). Hasilnya di-commit, jadi skrip ini hanya perlu
# dijalankan ulang bila ikon aplikasi berubah.
#
# Butuh rsvg-convert (librsvg2-bin) dan convert (imagemagick).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
icons="$here/../assets/icon"
oo="$here/../integrations/onlyoffice/resources"
word="$here/../integrations/word/assets"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Ikon penuh warna: latar teal bersudut bulat + halaman bergaris stabilo.
# Foreground SVG dibuat untuk ikon adaptif (isi di tengah 66/108), jadi
# dipotong sedikit supaya halaman mengisi ikon kecil.
full() { # ukuran keluaran
  local size="$1" out="$2" big=432
  rsvg-convert -w "$big" -h "$big" "$icons/background.svg" -o "$work/bg.png"
  rsvg-convert -w "$big" -h "$big" "$icons/foreground.svg" -o "$work/fg.png"
  local r=$((big * 22 / 100))
  convert "$work/bg.png" "$work/fg.png" -composite \
    -gravity center -crop 76x76%+0+0 +repage -resize "${big}x${big}" \
    \( +clone -alpha transparent -fill white \
       -draw "roundrectangle 0,0 $((big - 1)),$((big - 1)) $r,$r" \) \
    -compose DstIn -composite -resize "${size}x${size}" "$out"
}

mkdir -p "$oo/light" "$oo/dark" "$word"
for spec in ":28" "@1.25x:35" "@1.5x:42" "@1.75x:49" "@2x:56"; do
  suffix="${spec%%:*}"; size="${spec##*:}"
  full "$size" "$oo/light/icon$suffix.png"
  cp "$oo/light/icon$suffix.png" "$oo/dark/icon$suffix.png"
done
for size in 16 32 64 80 128; do
  full "$size" "$word/icon-$size.png"
done
echo "Ikon dibuat di $oo dan $word"
