#!/usr/bin/env bash
# Memasang ReadPaper di CachyOS, Arch, Manjaro, EndeavourOS, dan turunan Arch
# lainnya — sebagai paket pacman `readpaper-bin`, jadi ia muncul di menu
# aplikasi, ikut `pacman -Qu`, dan bisa dihapus bersih.
#
# Dua cara memakainya:
#
#   Dari folder tarball yang sudah dibongkar (tidak butuh internet):
#       ./pasang-arch.sh
#
#   Langsung, tanpa mengunduh apa pun lebih dulu:
#       curl -fsSL http://10.100.21.22:8899/pasang-readpaper-arch.sh | bash
#
# Pilihan:
#   --hapus    menghapus ReadPaper
#   --github   mengambil dari rilis GitHub, bukan dari halaman unduh internal
#
# Kenapa lewat makepkg, bukan menyalin berkas ke /opt begitu saja: berkas yang
# disalin tangan tidak diketahui pacman, tidak pernah diperbarui, dan tertinggal
# selamanya setelah dilupakan. Paket sungguhan tidak punya masalah itu.
set -euo pipefail

NAMA=readpaper-bin
HALAMAN="${READPAPER_UNDUH:-http://10.100.21.22:8899}"
GITHUB=https://github.com/situkangsayur/readpaper

hapus=0
github=0
for arg in "$@"; do
  case "$arg" in
    --hapus) hapus=1 ;;
    --github) github=1 ;;
    -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null || true; exit 0 ;;
    *) echo "Pilihan tidak dikenal: $arg" >&2; exit 2 ;;
  esac
done

gagal() { echo "✗ $*" >&2; exit 1; }
langkah() { echo "→ $*"; }

command -v pacman >/dev/null || gagal "pacman tidak ada. Skrip ini untuk CachyOS, Arch, dan turunannya; untuk Debian/Ubuntu pakai paket .deb."
# makepkg sendiri menolak dijalankan sebagai root, dan alasannya baik: membangun
# paket tidak perlu hak root, hanya memasangnya. sudo diminta saat perlu.
[ "$(id -u)" -ne 0 ] || gagal "Jalankan sebagai pengguna biasa, bukan root. Kata sandi sudo akan diminta saat memasang."
[ "$(uname -m)" = x86_64 ] || gagal "ReadPaper untuk Linux baru tersedia untuk x86_64 (mesin ini $(uname -m))."

if [ "$hapus" -eq 1 ]; then
  if pacman -Q "$NAMA" >/dev/null 2>&1; then
    langkah "Menghapus $NAMA…"
    sudo pacman -R --noconfirm "$NAMA"
    echo "✓ ReadPaper dihapus. Library dan pengaturannya di ~/.local/share tetap ada."
  else
    echo "ReadPaper tidak terpasang sebagai paket; tidak ada yang dihapus."
  fi
  exit 0
fi

langkah "Memastikan base-devel dan git terpasang (git juga dipakai ReadPaper untuk sinkronisasi)…"
sudo pacman -S --needed --noconfirm base-devel git

kerja="$(mktemp -d)"
trap 'rm -rf "$kerja"' EXIT

# Dijalankan dari folder tarball? Maka folder itulah sumbernya. Saat dipipa
# lewat `curl | bash`, BASH_SOURCE kosong dan cabang ini dilewati.
asal=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  asal="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$asal" ] && [ -x "$asal/readpaper" ] && [ -d "$asal/data" ] && [ -f "$asal/VERSI" ]; then
  versi="$(tr -d '[:space:]' < "$asal/VERSI")"
  langkah "Memasang ReadPaper $versi dari $asal…"
  # PKGBUILD yang mengemas folder ini apa adanya. Tidak ada unduhan dan tidak
  # ada sha256 untuk diperiksa: berkasnya sudah di tangan.
  cat > "$kerja/PKGBUILD" <<PKGBUILD
pkgname=$NAMA
pkgver=$versi
pkgrel=1
pkgdesc="Pembaca dan penganotasi paper dari library Zotero yang disinkronkan ke git"
arch=('x86_64')
url="$GITHUB"
license=('AGPL-3.0-or-later')
depends=('gtk3' 'glib2' 'gcc-libs' 'git' 'git-lfs')
optdepends=('xdg-desktop-portal-gtk: dialog pilih berkas' 'zenity: dialog pilih berkas cadangan')
provides=('readpaper')
conflicts=('readpaper')
options=('!strip')

package() {
  local asal='$asal'
  install -dm755 "\$pkgdir/opt/readpaper"
  cp -a "\$asal/data" "\$asal/lib" "\$asal/readpaper" "\$pkgdir/opt/readpaper/"
  chmod 755 "\$pkgdir/opt/readpaper/readpaper"
  install -dm755 "\$pkgdir/usr/bin"
  ln -s /opt/readpaper/readpaper "\$pkgdir/usr/bin/readpaper"
  install -Dm644 "\$asal/com.situkangsayur.readpaper.desktop" \\
    "\$pkgdir/usr/share/applications/com.situkangsayur.readpaper.desktop"
  install -Dm644 "\$asal/com.situkangsayur.readpaper.png" \\
    "\$pkgdir/usr/share/icons/hicolor/512x512/apps/com.situkangsayur.readpaper.png"
  install -Dm644 "\$asal/LICENSE" "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
}
PKGBUILD
else
  cd "$kerja"
  dapat=0
  if [ "$github" -eq 0 ]; then
    langkah "Mengambil PKGBUILD dari $HALAMAN…"
    if curl -fsS --connect-timeout 5 -o PKGBUILD "$HALAMAN/readpaper-PKGBUILD"; then
      dapat=1
      versi="$(grep -m1 '^pkgver=' PKGBUILD | cut -d= -f2)"
      # Nama berkas ini persis yang dicari makepkg, jadi ia tidak mengunduhnya
      # lagi dari GitHub. Kalau gagal, makepkg mengambilnya sendiri dari rilis.
      langkah "Mengambil ReadPaper $versi…"
      curl -fS --connect-timeout 5 -o "$NAMA-$versi.tar.gz" "$HALAMAN/readpaper-linux-latest.tar.gz" ||
        rm -f "$NAMA-$versi.tar.gz"
    else
      echo "  Halaman unduh tidak terjangkau (WireGuard mati?); beralih ke GitHub."
    fi
  fi
  if [ "$dapat" -eq 0 ]; then
    langkah "Mengambil PKGBUILD rilis terbaru dari GitHub…"
    curl -fsSL --connect-timeout 10 -o PKGBUILD "$GITHUB/releases/latest/download/PKGBUILD" ||
      gagal "PKGBUILD tidak bisa diambil, baik dari $HALAMAN maupun dari GitHub. Periksa jaringan."
    versi="$(grep -m1 '^pkgver=' PKGBUILD | cut -d= -f2)"
  fi
fi

langkah "Membangun dan memasang paket $NAMA $versi…"
cd "$kerja"
makepkg -si --noconfirm

echo
echo "✓ ReadPaper $versi terpasang. Buka dari menu aplikasi, atau ketik: readpaper"
echo "  Memperbarui: jalankan skrip ini lagi.  Menghapus: sudo pacman -R $NAMA"
