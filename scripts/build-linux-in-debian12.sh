#!/usr/bin/env bash
# Membangun ReadPaper untuk Linux di dalam kontainer Debian 12.
#
# Kenapa tidak dibangun di mesin ini saja: mesin pengembangannya Ubuntu 24.04,
# dan Ubuntu 24.04 membawa transisi `time_t` 64-bit — nama paketnya berakhiran
# `t64` dan glib-nya 2.80. Biner yang dibangun di sana memakai simbol yang
# belum ada di Debian 12 (`g_once_init_enter_pointer`), dan paketnya menuntut
# `libgtk-3-0t64` yang memang tidak ada di sana. Hasilnya, dan ini sudah
# dibuktikan di kontainer: Debian 12 memasang paketnya lalu aplikasinya mati
# seketika. Debian stable adalah dasar sebagian besar "turunan Debian", jadi
# itu bukan sudut yang bisa diabaikan.
#
# Dibangun di Debian 12, binernya berjalan di Debian 12 ke atas **dan** di
# Ubuntu 22.04 ke atas, karena glibc dan glib menjaga kompatibilitas maju.
#
# Flutter dipasang **di dalam citra**, bukan ditumpangkan dari mesin ini.
# Menumpangkan SDK yang sama ke dua sistem yang berbeda membuat artefak
# mesinnya bercampur, dan hasilnya galat yang menyesatkan seperti "Offset
# isn't defined" — yang terdengar seperti salah kode padahal salah lingkungan.
#
# Sumbernya juga disalin ke dalam kontainer, bukan disunting di tempat: tanpa
# itu `.dart_tool` milik mesin ini ikut ditulisi dan `flutter test` di luar
# kontainer patah setelahnya.
#
# Pemakaian:  scripts/build-linux-in-debian12.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

image="readpaper-build:debian12"
flutter_version="${FLUTTER_VERSION:-3.44.5}"
out="$here/build/linux/dist"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "Membangun citra $image (sekali saja, beberapa menit)…"
  docker build -t "$image" --build-arg "FLUTTER_VERSION=$flutter_version" - <<'DOCKERFILE'
FROM debian:12

# Yang dibutuhkan Flutter untuk membangun aplikasi Linux, apa adanya menurut
# `flutter doctor`. Ditambah dpkg-dev, karena paketnya dihitung dengan
# dpkg-shlibdeps di dalam sini juga — dan syarat versi yang dihasilkannya
# harus berasal dari pustaka Debian 12, bukan Ubuntu.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip \
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libstdc++-12-dev \
      dpkg-dev fakeroot rsync \
      librsvg2-bin imagemagick \
    && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.44.5
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git /opt/flutter \
    && git config --system --add safe.directory /opt/flutter \
    && /opt/flutter/bin/flutter --disable-analytics \
    && /opt/flutter/bin/flutter config --no-cli-animations \
    && /opt/flutter/bin/flutter precache --linux \
    && chmod -R a+rwX /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"
DOCKERFILE
fi

mkdir -p "$out"
echo "Membangun di dalam Debian 12…"

# Sumbernya disalin masuk; hanya hasil paketannya yang keluar.
docker run --rm \
  -e HOME=/tmp/rumah \
  -v "$here":/src:ro \
  -v "$out":/keluaran \
  "$image" bash -c '
    set -e
    export PATH=/opt/flutter/bin:$PATH
    mkdir -p "$HOME" /work
    rsync -a --exclude build/ --exclude .dart_tool/ --exclude .git/ /src/ /work/
    cd /work
    flutter build linux --release
    ./scripts/package-linux.sh --skip-build
    cp -a build/linux/dist/. /keluaran/
  ' 2>&1 | grep -vE "Telemetry|Google Analytics|Privacy Policy|analytics|opt-out|opt out|crash report|policies.google|^$"

echo
echo "Selesai. Paketnya ada di $out:"
ls -la "$out"
