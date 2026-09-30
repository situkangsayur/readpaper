#!/usr/bin/env bash
# Menjalankan paket Linux di distribusi aslinya, di dalam kontainer.
#
# Ini bukan kemewahan. Membangun di Ubuntu 24.04 lalu menyatakan paketnya
# "jalan di Linux" sudah terbukti salah dua kali dalam satu sore:
#
#   1. Di Debian 12 paketnya terpasang, lalu mati seketika dengan
#      "undefined symbol: g_once_init_enter_pointer" — simbol yang baru ada
#      di glib 2.80, sementara Debian 12 membawa 2.74.
#   2. Di Ubuntu 24.04 yang bersih paketnya mati dengan "Couldn't open
#      libEGL.so.1". Flutter membuka pustaka itu dengan dlopen, bukan
#      menautnya, jadi ia tidak muncul di `ldd` dan tidak ada satu pun
#      perkakas yang bisa menemukannya sendiri.
#
# Keduanya tidak terlihat di mesin pengembangan, karena mesin pengembangan
# punya segalanya. Kontainer yang bersih tidak.
#
# Pemakaian:  scripts/test-linux-packages.sh [versi]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

version="${1:-$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//; s/+.*//')}"
dist="$here/build/linux/dist"
deb="readpaper_${version}_amd64.deb"
tar="readpaper-${version}-linux-x64.tar.gz"

[ -f "$dist/$deb" ] || { echo "Tidak ada $dist/$deb"; exit 1; }
[ -f "$dist/$tar" ] || { echo "Tidak ada $dist/$tar"; exit 1; }

gagal=0

jalankan() {
  local nama="$1" citra="$2" skrip="$3"
  printf '\n=== %s ===\n' "$nama"
  if docker run --rm -v "$dist":/dist:ro -e DEB="$deb" -e TAR="$tar" \
       "$citra" bash -c "$skrip" 2>&1 | sed 's/^/  /'; then
    :
  else
    echo "  GAGAL"
    gagal=$((gagal + 1))
  fi
}

# Kode keluar 124 berarti `timeout` yang menghentikannya: aplikasinya masih
# hidup saat waktu habis, yaitu justru yang ingin dibuktikan. Kode lain
# berarti ia berhenti sendiri, dan itu kegagalan.
jalan_deb='
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq "/dist/$DEB" xvfb >/dev/null 2>&1 || {
  echo "apt menolak memasang:"; apt-get install -y "/dist/$DEB" 2>&1 | grep -E "Depends" | head -4; exit 1; }
timeout 15 xvfb-run -a readpaper > /tmp/o.log 2>&1
kode=$?
grep -viE "libEGL warning|DRI3|Atk-CRITICAL|^$" /tmp/o.log | head -3
[ "$kode" = 124 ] && echo "jalan (hidup sampai waktu habis)" || { echo "berhenti sendiri, kode $kode"; exit 1; }
'

jalan_tar='
pacman -Sy --noconfirm --quiet gtk3 xorg-server-xvfb mesa >/dev/null 2>&1
cd /tmp && tar xzf "/dist/$TAR" && cd "${TAR%.tar.gz}"
ldd readpaper | grep "not found" && exit 1
timeout 15 xvfb-run -a ./readpaper > /tmp/o.log 2>&1
kode=$?
grep -viE "libEGL warning|DRI3|Atk-CRITICAL|^$" /tmp/o.log | head -3
[ "$kode" = 124 ] && echo "jalan (hidup sampai waktu habis)" || { echo "berhenti sendiri, kode $kode"; exit 1; }
'

jalankan "Debian 12 — .deb"     debian:12          "$jalan_deb"
jalankan "Ubuntu 22.04 — .deb"  ubuntu:22.04       "$jalan_deb"
jalankan "Ubuntu 24.04 — .deb"  ubuntu:24.04       "$jalan_deb"
jalankan "Arch — tar.gz"        archlinux:latest   "$jalan_tar"

printf '\n'
if [ "$gagal" -eq 0 ]; then
  echo "Keempatnya jalan."
else
  echo "$gagal dari 4 gagal."
  exit 1
fi
