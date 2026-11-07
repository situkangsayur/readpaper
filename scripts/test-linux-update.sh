#!/usr/bin/env bash
# Menguji pembaruan dari dalam ReadPaper di kontainer, untuk setiap cara ia
# dipasang di Linux: tarball di ~/.local/opt, paket .deb, dan paket pacman.
#
# Rilis "0.99.0" palsu disajikan dari mesin ini (server HTTP lokal, JSON
# berbentuk jawaban GitHub, lengkap dengan sha256-nya). ReadPaper versi
# sekarang dipasang di kontainer, lalu `readpaper --perbarui` dijalankan
# dengan READPAPER_RILIS_URL menunjuk ke rilis palsu itu. Berhasil bila
# setelahnya versi terpasang 0.99.0 dan berkas penandanya ada.
#
# Pemakaian:  scripts/test-linux-update.sh   (setelah build-linux-in-debian12.sh)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

version="$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//; s/+.*//')"
dist="$here/build/linux/dist"
deb="readpaper_${version}_amd64.deb"
tar="readpaper-${version}-linux-x64.tar.gz"
[ -f "$dist/$deb" ] && [ -f "$dist/$tar" ] || { echo "Bangun dulu: scripts/build-linux-in-debian12.sh"; exit 1; }

baru=0.99.0
srv="$(mktemp -d)"
trap 'kill "${server:-0}" 2>/dev/null || true; rm -rf "$srv"' EXIT
port=$((20000 + RANDOM % 20000))
url="http://127.0.0.1:$port"

# ── Rilis palsu ─────────────────────────────────────────────────────────
kerja="$srv/kerja"
mkdir -p "$kerja"
tar -C "$kerja" -xzf "$dist/$tar"
mv "$kerja/readpaper-$version-linux-x64" "$kerja/readpaper-$baru-linux-x64"
echo "$baru" > "$kerja/readpaper-$baru-linux-x64/VERSI"
touch "$kerja/readpaper-$baru-linux-x64/TANDA-PEMBARUAN"
tar -C "$kerja" -czf "$srv/readpaper-$baru-linux-x64.tar.gz" "readpaper-$baru-linux-x64"

mkdir -p "$kerja/deb"
dpkg-deb -R "$dist/$deb" "$kerja/deb"
sed -i "s/^Version: .*/Version: $baru/" "$kerja/deb/DEBIAN/control"
touch "$kerja/deb/opt/readpaper/TANDA-PEMBARUAN"
dpkg-deb --root-owner-group -b "$kerja/deb" "$srv/readpaper_${baru}_amd64.deb" >/dev/null

sumtar="$(sha256sum "$srv/readpaper-$baru-linux-x64.tar.gz" | cut -d' ' -f1)"
cat > "$srv/PKGBUILD" <<PKGBUILD
pkgname=readpaper-bin
pkgver=$baru
pkgrel=1
pkgdesc="ReadPaper (uji pembaruan)"
arch=('x86_64')
url="https://github.com/situkangsayur/readpaper"
license=('AGPL-3.0-or-later')
depends=('gtk3' 'glib2' 'gcc-libs' 'git')
provides=('readpaper')
conflicts=('readpaper')
options=('!strip')
source=("\$pkgname-\$pkgver.tar.gz::$url/readpaper-$baru-linux-x64.tar.gz")
sha256sums=('$sumtar')
package() {
  cd "readpaper-\$pkgver-linux-x64"
  install -dm755 "\$pkgdir/opt/readpaper"
  cp -a data lib readpaper VERSI TANDA-PEMBARUAN "\$pkgdir/opt/readpaper/"
  install -dm755 "\$pkgdir/usr/bin"
  ln -s /opt/readpaper/readpaper "\$pkgdir/usr/bin/readpaper"
}
PKGBUILD

python3 - "$srv" "$url" "$baru" <<'PY'
import hashlib, json, os, sys
srv, url, v = sys.argv[1:]
assets = []
for name in sorted(os.listdir(srv)):
    path = os.path.join(srv, name)
    if not os.path.isfile(path):
        continue
    digest = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    assets.append({'name': name, 'browser_download_url': f'{url}/{name}',
                   'size': os.path.getsize(path), 'digest': f'sha256:{digest}'})
json.dump({'tag_name': f'v{v}', 'body': 'uji', 'html_url': url, 'assets': assets},
          open(os.path.join(srv, 'rilis.json'), 'w'))
PY
rm -rf "$kerja"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$srv" >/dev/null 2>&1 &
server=$!
sleep 1

gagal=0
jalankan() {
  local nama="$1" citra="$2" skrip="$3"
  # SAJA=Arch scripts/test-linux-update.sh — hanya jalur yang namanya cocok.
  [[ -z "${SAJA:-}" || "$nama" == *"$SAJA"* ]] || return 0
  printf '\n=== %s ===\n' "$nama"
  if docker run --rm --network host -v "$dist":/dist:ro -e DEB="$deb" -e TAR="$tar" \
       -e VERSI_LAMA="$version" -e BARU="$baru" -e READPAPER_RILIS_URL="$url/rilis.json" \
       "$citra" bash -c "$skrip" 2>&1 | sed 's/^/  /'; then
    :
  else
    echo "  GAGAL"
    gagal=$((gagal + 1))
  fi
}

# `--perbarui` tetap membuka jendela GTK sebentar, jadi butuh Xvfb.
perbarui='xvfb-run -a env READPAPER_RILIS_URL="$READPAPER_RILIS_URL" "$@" --perbarui 2>&1 | grep -vE "libEGL|DRI3|Atk-CRITICAL|Gtk-WARNING|^$"; return ${PIPESTATUS[0]}'

jalankan "Debian 12 — tarball di ~/.local/opt (tanpa root)" debian:12 "
set -o pipefail
perbarui() { $perbarui; }
export DEBIAN_FRONTEND=noninteractive
# Dependensinya dari paket .deb, lalu paketnya dibuang: yang dipakai tarball.
apt-get update -qq >/dev/null && apt-get install -y -qq /dist/\$DEB xvfb xauth >/dev/null && dpkg -r readpaper >/dev/null
useradd -m u
su u -s /bin/bash -c 'mkdir -p ~/.local/opt && tar -C ~/.local/opt -xzf /dist/\$TAR && mv ~/.local/opt/readpaper-*-linux-x64 ~/.local/opt/readpaper'
export -f perbarui
su u -s /bin/bash -c 'perbarui ~/.local/opt/readpaper/readpaper' || exit 1
v=\$(cat /home/u/.local/opt/readpaper/VERSI)
[ \"\$v\" = \"\$BARU\" ] && [ -f /home/u/.local/opt/readpaper/TANDA-PEMBARUAN ] || { echo \"versi masih \$v\"; exit 1; }
ls -A /home/u/.local/opt
echo \"✓ tarball \$VERSI_LAMA → \$v\"
"

jalankan "Ubuntu 24.04 — paket .deb (root)" ubuntu:24.04 "
set -o pipefail
perbarui() { $perbarui; }
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null && apt-get install -y -qq /dist/\$DEB xvfb xauth >/dev/null
perbarui readpaper || exit 1
v=\$(dpkg-query -W -f='\${Version}' readpaper)
[ \"\$v\" = \"\$BARU\" ] && [ -f /opt/readpaper/TANDA-PEMBARUAN ] || { echo \"versi masih \$v\"; exit 1; }
echo \"✓ deb \$VERSI_LAMA → \$v\"
"

jalankan "Debian 12 — paket .deb, pengguna biasa tanpa sudo" debian:12 "
set -o pipefail
perbarui() { $perbarui; }
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null && apt-get install -y -qq /dist/\$DEB xvfb xauth >/dev/null
useradd -m u
export -f perbarui
if su u -s /bin/bash -c 'perbarui readpaper'; then echo 'mestinya gagal tanpa hak root'; exit 1; fi
v=\$(dpkg-query -W -f='\${Version}' readpaper)
[ \"\$v\" = \"\$VERSI_LAMA\" ] || exit 1
echo \"✓ gagal dengan pesan, paket tetap \$v\"
"

jalankan "Arch — paket pacman readpaper-bin (sudo)" archlinux:latest "
set -o pipefail
perbarui() { $perbarui; }
pacman -Syu --noconfirm --needed base-devel git gtk3 xorg-server-xvfb xorg-xauth mesa sudo >/dev/null 2>&1 || exit 1
useradd -m u && echo 'u ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/u
su u -s /bin/bash -c 'cd /tmp && tar -xzf /dist/\$TAR && cd readpaper-*-linux-x64 && ./pasang-arch.sh' >/dev/null 2>&1 || { echo 'pasang-arch gagal'; exit 1; }
pacman -Q readpaper-bin
export -f perbarui
su u -s /bin/bash -c 'perbarui readpaper' || exit 1
v=\$(pacman -Q readpaper-bin | cut -d' ' -f2)
[ \"\$v\" = \"\$BARU-1\" ] && [ -f /opt/readpaper/TANDA-PEMBARUAN ] || { echo \"versi masih \$v\"; exit 1; }
echo \"✓ pacman \$VERSI_LAMA → \$v\"
"

echo
[ "$gagal" -eq 0 ] && echo "Semua jalur pembaruan Linux berhasil." || { echo "$gagal jalur gagal."; exit 1; }
