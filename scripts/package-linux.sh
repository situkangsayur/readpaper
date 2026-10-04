#!/usr/bin/env bash
# Membungkus hasil `flutter build linux` menjadi paket yang bisa dipasang.
#
# Menghasilkan tiga bentuk, karena "Linux" bukan satu sistem:
#
#   readpaper-<versi>-linux-x64.tar.gz   portabel, jalan di mana saja
#   readpaper_<versi>_amd64.deb          Debian, Ubuntu, dan turunannya
#   PKGBUILD                             Arch, CachyOS, dan turunannya
#
# Yang dibutuhkan: flutter, rsvg-convert (librsvg2-bin), convert (imagemagick),
# dpkg-deb (dpkg). Jalankan dari mana saja:  scripts/package-linux.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

version="$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//; s/+.*//')"
build="$(grep -m1 '^version:' pubspec.yaml | sed 's/.*+//')"
out="$here/build/linux/dist"
bundle="$here/build/linux/x64/release/bundle"

echo "ReadPaper $version (build $build)"

if [ "${1:-}" != "--skip-build" ]; then
  flutter build linux --release
fi
[ -d "$bundle" ] || { echo "Bundle tidak ada: $bundle"; exit 1; }

rm -rf "$out"
mkdir -p "$out"

# --- 1. Muatan yang dipakai ketiga paket -----------------------------------
#
# `libdartjni.so` ikut terbangun karena path_provider_android adalah plugin FFI,
# dan plugin FFI dibangun untuk setiap platform. Di Linux ia tidak pernah
# dipanggil — yang dipakai path_provider_linux — tetapi ia tertaut ke
# libjvm.so, jadi membiarkannya berarti paket ini seolah menuntut Java
# terpasang. Dibuang.
payload="$out/payload"
mkdir -p "$payload"
cp -a "$bundle/." "$payload/"
rm -f "$payload/lib/libdartjni.so"
chmod 755 "$payload/readpaper"

# Dijaga, bukan sekadar pernah dikerjakan: kalau suatu hari sebuah paket
# menyeret Java masuk lagi, paketannya gagal di sini alih-alih diam-diam
# menuntut JVM di mesin orang lain.
if ldd "$payload/readpaper" "$payload"/lib/*.so 2>/dev/null | grep -qi 'jvm\|libjava'; then
  echo "GAGAL: masih ada pustaka yang menuntut JVM:"
  ldd "$payload/readpaper" "$payload"/lib/*.so 2>/dev/null | grep -i 'jvm\|libjava'
  exit 1
fi

# --- 2. Ikon, dari SVG yang sama dengan ikon Android ------------------------
icons="$out/icons"
mkdir -p "$icons"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for size in 16 24 32 48 64 128 256 512; do
  rsvg-convert -w "$size" -h "$size" assets/icon/background.svg -o "$work/bg.png"
  rsvg-convert -w "$size" -h "$size" assets/icon/foreground.svg -o "$work/fg.png"
  radius=$(( size * 22 / 100 ))
  convert "$work/bg.png" "$work/fg.png" -composite \
    \( +clone -alpha transparent -fill white \
       -draw "roundrectangle 0,0 $((size - 1)),$((size - 1)) $radius,$radius" \) \
    -compose DstIn -composite "$icons/readpaper-$size.png"
done

# --- 3. Berkas .desktop -----------------------------------------------------
#
# Namanya **harus** sama dengan APPLICATION_ID di linux/CMakeLists.txt, yaitu
# com.situkangsayur.readpaper. Runner Flutter memanggil g_set_prgname dengan id
# itu, jadi itulah nama yang dipakai dok untuk mencari peluncurnya. Sebelumnya
# berkas ini bernama readpaper.desktop dengan Icon=readpaper, dan akibatnya
# terlihat langsung di dok Linux: aplikasinya berjalan **tanpa ikon**, dengan
# nama mentah "com.situkangsayur.readpaper". Nama ikonnya ikut app id untuk
# alasan yang sama.
#
# MimeType membuat ReadPaper muncul di "Buka dengan" untuk PDF, sama seperti
# di Android. StartupWMClass adalah cadangan untuk dok yang mencocokkan lewat
# WM_CLASS alih-alih lewat id aplikasi.
appid="com.situkangsayur.readpaper"

# Dijaga, bukan diingat: kalau APPLICATION_ID di linux/CMakeLists.txt berganti
# dan berkas .desktop-nya tidak ikut, akibatnya tidak terlihat di mana pun
# kecuali di dok orang — aplikasi berjalan tanpa ikon.
declared="$(sed -n 's/^set(APPLICATION_ID "\(.*\)")$/\1/p' linux/CMakeLists.txt)"
if [ "$declared" != "$appid" ]; then
  echo "GAGAL: APPLICATION_ID di linux/CMakeLists.txt adalah '$declared',"
  echo "       sedangkan berkas .desktop dibuat untuk '$appid'."
  echo "       Dok tidak akan bisa mencocokkan jendelanya dengan peluncurnya."
  exit 1
fi

cat > "$out/$appid.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=ReadPaper
GenericName=Pembaca paper
Comment=Membaca, menandai, dan memberi komentar pada paper dari library Zotero
Exec=readpaper %f
Icon=com.situkangsayur.readpaper
Terminal=false
Categories=Office;Education;Science;Viewer;
MimeType=application/pdf;
Keywords=zotero;paper;pdf;sitasi;anotasi;
StartupWMClass=com.situkangsayur.readpaper
DESKTOP

# --- 4. Tarball portabel ----------------------------------------------------
tarname="readpaper-$version-linux-x64"
tardir="$out/$tarname"
mkdir -p "$tardir"
cp -a "$payload/." "$tardir/"
cp "$out/$appid.desktop" "$tardir/"
cp "$icons/readpaper-512.png" "$tardir/$appid.png"
cp LICENSE "$tardir/"
# Pemasang untuk CachyOS dan Arch ikut di dalam tarball: dibongkar, lalu
# ./pasang-arch.sh — tanpa internet, karena isinya sudah ada di folder ini.
# VERSI dibacanya untuk nomor versi paket pacman.
install -m755 scripts/pasang-arch.sh "$tardir/pasang-arch.sh"
echo "$version" > "$tardir/VERSI"
cat > "$tardir/PASANG.md" <<MD
# ReadPaper $version — Linux x86-64

**CachyOS, Arch, Manjaro:** jalankan \`./pasang-arch.sh\` dari folder ini. Ia
memasang ReadPaper sebagai paket pacman (\`readpaper-bin\`), jadi muncul di menu
aplikasi dan bisa dihapus dengan \`./pasang-arch.sh --hapus\`.

Portabel: jalankan \`./readpaper\` dari folder ini, tanpa memasang apa pun.

Untuk memasangnya ke menu aplikasi (tanpa root):

    mkdir -p ~/.local/opt ~/.local/bin ~/.local/share/applications ~/.local/share/icons/hicolor/512x512/apps
    cp -r . ~/.local/opt/readpaper
    ln -sf ~/.local/opt/readpaper/readpaper ~/.local/bin/readpaper
    cp com.situkangsayur.readpaper.desktop ~/.local/share/applications/
    cp com.situkangsayur.readpaper.png ~/.local/share/icons/hicolor/512x512/apps/
    update-desktop-database ~/.local/share/applications 2>/dev/null || true

Yang dibutuhkan sistem: GTK 3.24 ke atas beserta pustaka biasanya
(glib, cairo, pango, gdk-pixbuf). Hampir setiap desktop Linux sudah punya.
MD
tar -C "$out" -czf "$out/$tarname.tar.gz" "$tarname"
rm -rf "$tardir"
echo "  $out/$tarname.tar.gz"

# --- 5. Paket Debian --------------------------------------------------------
#
# Muatannya duduk di /opt, bukan tersebar di /usr: bundel Flutter menuntut
# `data/` dan `lib/` berada tepat di sebelah binernya, dan memecahnya berarti
# menambal jalur pencarian pustaka tanpa untung apa pun.
deb="$out/deb"
mkdir -p "$deb/DEBIAN" "$deb/opt/readpaper" "$deb/usr/bin" \
         "$deb/usr/share/applications" "$deb/usr/share/doc/readpaper"
cp -a "$payload/." "$deb/opt/readpaper/"
ln -s /opt/readpaper/readpaper "$deb/usr/bin/readpaper"
cp "$out/$appid.desktop" "$deb/usr/share/applications/"
for size in 16 24 32 48 64 128 256 512; do
  dir="$deb/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  cp "$icons/readpaper-$size.png" "$dir/$appid.png"
done
cp LICENSE "$deb/usr/share/doc/readpaper/copyright"

# Dependensinya dihitung, tidak ditebak.
#
# Daftar yang ditulis tangan sebelumnya menyebut "libgtk-3-0t64 | libgtk-3-0"
# tanpa versi, dan akibatnya apt dengan senang hati memasangnya di Debian 12 —
# lalu aplikasinya mati saat dijalankan dengan "undefined symbol:
# g_once_init_enter_pointer", simbol yang baru ada di glib 2.80. Diuji di
# kontainer Debian 12, bukan ditemukan oleh pemakainya.
#
# `dpkg-shlibdeps` membaca simbol yang benar-benar dipakai binernya dan
# menghasilkan syarat versi yang tepat. Kalau sistemnya terlalu tua, apt
# menolak memasang dengan alasan yang jelas — jauh lebih baik daripada
# memasang lalu gagal.
shlibwork="$(mktemp -d)"
mkdir -p "$shlibwork/debian"
printf 'Source: readpaper\n\nPackage: readpaper\nArchitecture: amd64\n' \
  > "$shlibwork/debian/control"
computed="$(cd "$shlibwork" && dpkg-shlibdeps -O --ignore-missing-info \
  -l"$payload/lib" "$payload/readpaper" "$payload"/lib/*.so 2>/dev/null \
  | sed 's/^shlibs:Depends=//')"
rm -rf "$shlibwork"
[ -n "$computed" ] || { echo "GAGAL: dpkg-shlibdeps tidak menghasilkan apa-apa"; exit 1; }

# Yang tidak bisa dilihat dpkg-shlibdeps: Flutter membuka libEGL.so.1 dan
# libGLESv2.so.2 dengan dlopen saat berjalan, bukan menautnya. Keduanya tidak
# muncul di `ldd` sama sekali, jadi tidak ada satu pun perkakas yang bisa
# menemukannya sendiri — ketahuannya waktu aplikasinya mati di kontainer
# Ubuntu 24.04 yang bersih dengan "Couldn't open libEGL.so.1".
cat > "$deb/DEBIAN/control" <<CONTROL
Package: readpaper
Version: $version
Section: science
Priority: optional
Architecture: amd64
Maintainer: Hendri Karisma <situkangsayur@gmail.com>
Depends: $computed, libegl1, libgles2
Recommends: libgl1-mesa-dri, fonts-dejavu-core
Homepage: https://github.com/situkangsayur/readpaper
Description: Pembaca dan penganotasi paper dari library Zotero
 ReadPaper membaca library Zotero yang disinkronkan ke git: menelusuri koleksi,
 membuka PDF-nya, menandai teks dengan stabilo berwarna, menulis dan menggambar
 di halaman, serta membuat catatan. Anotasinya ditulis balik dalam format
 Zotero sendiri dan menjadi commit di repositori yang sama.
CONTROL

cat > "$deb/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
POSTINST
cp "$deb/DEBIAN/postinst" "$deb/DEBIAN/postrm"
chmod 755 "$deb/DEBIAN/postinst" "$deb/DEBIAN/postrm"

debname="readpaper_${version}_amd64.deb"
dpkg-deb --root-owner-group --build "$deb" "$out/$debname" >/dev/null
rm -rf "$deb"
echo "  $out/$debname"

# --- 6. PKGBUILD untuk Arch dan CachyOS -------------------------------------
#
# Paket -bin: ia mengambil tarball rilis, bukan membangun ulang dari sumber.
# Membangun Flutter dari sumber di mesin pemakai menuntut SDK Flutter lengkap,
# dan itu bukan harga yang pantas untuk memasang satu aplikasi.
sha="$(sha256sum "$out/$tarname.tar.gz" | cut -d' ' -f1)"
mkdir -p "$out/arch"
cat > "$out/arch/PKGBUILD" <<PKGBUILD
# Maintainer: Hendri Karisma <situkangsayur@gmail.com>
pkgname=readpaper-bin
pkgver=$version
pkgrel=1
pkgdesc="Pembaca dan penganotasi paper dari library Zotero yang disinkronkan ke git"
arch=('x86_64')
url="https://github.com/situkangsayur/readpaper"
license=('AGPL-3.0-or-later')
depends=('gtk3' 'glib2' 'gcc-libs')
provides=('readpaper')
conflicts=('readpaper')
options=('!strip')
source=("\$pkgname-\$pkgver.tar.gz::\$url/releases/download/v\$pkgver/$tarname.tar.gz")
sha256sums=('$sha')

package() {
  cd "\$srcdir/$tarname"

  install -dm755 "\$pkgdir/opt/readpaper"
  cp -a data lib readpaper "\$pkgdir/opt/readpaper/"
  chmod 755 "\$pkgdir/opt/readpaper/readpaper"

  install -dm755 "\$pkgdir/usr/bin"
  ln -s /opt/readpaper/readpaper "\$pkgdir/usr/bin/readpaper"

  install -Dm644 com.situkangsayur.readpaper.desktop \\
    "\$pkgdir/usr/share/applications/com.situkangsayur.readpaper.desktop"
  install -Dm644 com.situkangsayur.readpaper.png \\
    "\$pkgdir/usr/share/icons/hicolor/512x512/apps/com.situkangsayur.readpaper.png"
  install -Dm644 LICENSE "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
}
PKGBUILD
echo "  $out/arch/PKGBUILD"
install -m755 scripts/pasang-arch.sh "$out/pasang-arch.sh"
echo "  $out/pasang-arch.sh"

rm -rf "$payload" "$icons" "$out/$appid.desktop"
echo
echo "Selesai. Isi $out:"
ls -la "$out"
