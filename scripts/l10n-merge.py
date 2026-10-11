#!/usr/bin/env python3
"""Menggabungkan lib/l10n/parts/<area>_{id,en}.json ke lib/l10n/app_{id,en}.arb.

Teks antarmuka dikelompokkan per area (pembaca, library, catatan, …) supaya
bisa disunting terpisah tanpa saling menimpa. Berkas ARB yang dibaca
gen-l10n adalah hasil gabungan — jangan disunting langsung; sunting bagian di
lib/l10n/parts lalu jalankan skrip ini (dan `flutter gen-l10n`).

Kunci ganda antarbagian adalah galat. Aman dijalankan bersamaan (flock).
"""
import fcntl
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
l10n = root / 'lib' / 'l10n'
parts = l10n / 'parts'

with open(l10n / '.merge.lock', 'w') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    for locale in ('id', 'en'):
        merged = {'@@locale': locale}
        owner = {}
        base = json.loads((parts / f'_dasar_{locale}.json').read_text())
        for key, value in base.items():
            merged[key] = value
            owner[key] = '_dasar'
        for part in sorted(parts.glob(f'*_{locale}.json')):
            area = part.name[: -len(f'_{locale}.json')]
            if area == '_dasar':
                continue
            data = json.loads(part.read_text())
            for key, value in data.items():
                if key in merged and owner.get(key) != area:
                    sys.exit(f'Kunci ganda "{key}" di {area} dan {owner[key]} ({locale})')
                merged[key] = value
                owner[key] = area
        out = l10n / f'app_{locale}.arb'
        out.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n')
    # Kunci yang ada di Indonesia tetapi tidak di English (atau sebaliknya).
    ids = {k for k in json.loads((l10n / 'app_id.arb').read_text()) if not k.startswith('@')}
    ens = {k for k in json.loads((l10n / 'app_en.arb').read_text()) if not k.startswith('@')}
    if ids != ens:
        print('Peringatan: hanya di id:', sorted(ids - ens)[:20], 'hanya di en:', sorted(ens - ids)[:20])
