#!/usr/bin/env bash
# Membuat GitHub Release untuk setiap tag yang belum punya, dengan APK-nya
# dilampirkan kalau berkasnya ada di ~/apk-share.
#
# Halaman Releases lama tertinggal jauh di belakang tag karena `git push --tags`
# hanya membuat tag; Release adalah objek terpisah. Skrip ini yang menyusulnya.
#
# Butuh salah satu:
#   gh auth login --scopes public_repo      # repo publik saja, tanpa organisasi
#   GH_TOKEN=<fine-grained token>           # dibatasi ke repo readpaper,
#                                           # izin "Contents: read and write"
#
# Aman dijalankan berulang: tag yang Release-nya sudah ada dilewati.
#
#   ./scripts/publish-releases.sh            # semua tag
#   ./scripts/publish-releases.sh v0.2.2     # satu tag saja
set -uo pipefail

REPO="${REPO:-situkangsayur/readpaper}"
APK_DIR="${APK_DIR:-$HOME/apk-share}"

command -v gh >/dev/null || { echo "gh tidak ditemukan"; exit 1; }
if [ -z "${GH_TOKEN:-}" ] && ! gh auth status >/dev/null 2>&1; then
  echo "Belum ada kredensial. Jalankan salah satu:"
  echo "  gh auth login --hostname github.com --git-protocol ssh --scopes public_repo --web"
  echo "  export GH_TOKEN=<fine-grained token untuk repo $REPO>"
  exit 1
fi

tags=("$@")
if [ ${#tags[@]} -eq 0 ]; then
  mapfile -t tags < <(git tag | sort -V)
fi

made=0; skipped=0; failed=0
for tag in "${tags[@]}"; do
  if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
    printf '  = %-9s Release sudah ada\n' "$tag"
    skipped=$((skipped+1))
    continue
  fi

  # Isi catatan rilisnya diambil dari pesan tag; kalau tag-nya ringan, dari
  # commit yang ditunjuknya. Menulis ulang di sini hanya akan berbeda dari
  # riwayat yang sudah ada.
  notes="$(git tag -l --format='%(contents)' "$tag")"
  [ -z "${notes// }" ] && notes="$(git log -1 --pretty=%B "$tag")"

  apk="$APK_DIR/readpaper_${tag}.apk"
  args=(--repo "$REPO" --title "ReadPaper ${tag#v}" --notes "$notes")
  [ "$tag" = "$(git tag | sort -V | tail -1)" ] || args+=(--latest=false)
  [ -f "$apk" ] && args+=("$apk")

  if gh release create "$tag" "${args[@]}" >/dev/null 2>&1; then
    printf '  + %-9s dibuat%s\n' "$tag" "$([ -f "$apk" ] && echo ' (APK terlampir)' || echo ' (tanpa APK)')"
    made=$((made+1))
  else
    printf '  ! %-9s GAGAL\n' "$tag"
    failed=$((failed+1))
  fi
done

echo
echo "Dibuat: $made · dilewati: $skipped · gagal: $failed"
[ $failed -gt 0 ] && exit 1

latest="$(git tag | sort -V | tail -1)"
echo
echo "Memeriksa tautan unduhan untuk $latest…"
url="https://github.com/$REPO/releases/latest/download/readpaper_${latest}.apk"
code="$(curl -sL -o /dev/null -w '%{http_code}' "$url")"
echo "  $url -> HTTP $code"
[ "$code" = "200" ] || echo "  (belum 200; aset mungkin masih diproses GitHub)"
