#!/usr/bin/env bash
# Creates the labels and the project board ReadPaper's issues are sorted with.
#
# Run once, after `gh auth login`. It is idempotent: labels that already exist
# are updated rather than duplicated, and the board is only created if a board
# with the same name is not there yet.
#
#   gh auth login          # needs scopes: repo, project, read:org
#   ./scripts/setup-github-project.sh
set -euo pipefail

REPO="${REPO:-situkangsayur/readpaper}"
OWNER="${REPO%%/*}"
BOARD="${BOARD:-ReadPaper}"

command -v gh >/dev/null || { echo "gh tidak ditemukan"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Belum login: jalankan 'gh auth login'"; exit 1; }

label() { # name colour description
  gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force >/dev/null
  printf '  %s\n' "$1"
}

echo "Label jenis:"
label "type:bug"      "d73a4a" "Ada yang tidak bekerja"
label "type:feature"  "0e8a16" "Kemampuan baru"
label "type:docs"     "0075ca" "Dokumentasi"
label "type:chore"    "cfd3d7" "Perkakas, CI, perapian"

echo "Label area:"
label "area:reader"   "5319e7" "Pembaca PDF, anotasi, alat tulis"
label "area:sync"     "1d76db" "Git, GitHub API, LFS"
label "area:library"  "006b75" "Parser Zotero, koleksi, pencarian"
label "area:android"  "3ddc84" "Khusus Android"
label "area:desktop"  "b60205" "Khusus desktop"
label "area:plugins"  "fbca04" "Sistem plugin"
label "area:citation" "c2e0c6" "Bibliografi, CSL, integrasi editor"

echo "Label fase (mengikuti docs/backlog.md):"
for n in 5 6 7 8 9 10 11 12; do
  label "phase:$n" "ededed" "Fase $n di docs/backlog.md"
done

echo "Label lain:"
label "good first issue" "7057ff" "Titik masuk yang enak untuk kontributor baru"
label "help wanted"      "008672" "Bantuan dari luar sangat berguna di sini"
label "needs-repro"      "e99695" "Menunggu langkah yang bisa diulang"
label "blocked"          "000000" "Menunggu keputusan atau pekerjaan lain"

# --- papan proyek -----------------------------------------------------------
existing="$(gh project list --owner "$OWNER" --format json \
            --jq ".projects[] | select(.title==\"$BOARD\") | .number" 2>/dev/null || true)"

if [ -n "$existing" ]; then
  echo "Papan \"$BOARD\" sudah ada (nomor $existing)."
else
  echo "Membuat papan \"$BOARD\"..."
  gh project create --owner "$OWNER" --title "$BOARD" --format json --jq '.number'
  cat <<'NOTE'

Papan sudah dibuat. Dua langkah terakhir belum bisa diotomatiskan lewat gh dan
harus lewat antarmuka web sekali saja:

  1. Ubah kolom bawaan menjadi: Inbox -> Ready -> In progress -> Done
  2. Settings -> Workflows: nyalakan "Item added to project" (masuk ke Inbox),
     "Item closed" (pindah ke Done), dan "Pull request merged" (pindah ke Done)

Lalu sambungkan repositori ke papan lewat Settings -> Manage access, atau
tambahkan issue satu per satu dengan:

  gh project item-add <nomor> --owner OWNER --url <url-issue>
NOTE
fi

echo
echo "Selesai."
