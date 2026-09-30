#!/usr/bin/env python3
"""Menambah dan memperbarui gaya CSL resmi di assets/csl.

Kenapa ini ada sebagai perkakas, bukan sekadar `curl`:

Gaya CSL bukan satu berkas per nama. Sebagian **independen** — berisi seluruh
aturannya sendiri. Sebagian lagi **dependen**: hanya nama beserta penunjuk ke
induknya, dan tanpa induknya ia tidak bisa merender apa pun. "Vancouver"
adalah contoh yang paling menjebak: yang ada di repositori resmi bukan satu
gaya bernama Vancouver, melainkan **dua** gaya dependen — `vancouver-ama` yang
menunjuk AMA, dan `vancouver-nlm` yang menunjuk NLM citation-sequence —
sementara `https://www.zotero.org/styles/vancouver` diam-diam mengalihkan ke
yang NLM. Mengunduhnya dengan curl dan menyimpannya sebagai `vancouver.csl`
menghasilkan berkas yang isinya bukan yang tertulis di namanya.

Jadi perkakas ini yang memutuskan, bukan orang yang mengetik nama berkas:
    ambil berkasnya, baca <info>-nya, kalau dependen ambil induknya juga,
    lalu catat semuanya di assets/csl/styles.json apa adanya.

Isi gayanya tidak pernah disunting. Gaya yang ditambal sendiri menghasilkan
daftar pustaka yang berbeda dari Zotero, dan itu persis yang hendak dihindari.

Pemakaian:
    scripts/csl-style.py add ieee apa vancouver-nlm
    scripts/csl-style.py update            # ambil ulang semua yang tercatat
    scripts/csl-style.py list
    scripts/csl-style.py check             # dipakai uji; tanpa jaringan
"""

from __future__ import annotations

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parent.parent
CSL = ROOT / "assets" / "csl"
MANIFEST = CSL / "styles.json"
NS = {"csl": "http://purl.org/net/xbiblio/csl"}

STYLES_BASE = "https://raw.githubusercontent.com/citation-style-language/styles/master"
LOCALES_BASE = "https://raw.githubusercontent.com/citation-style-language/locales/master"


def die(message: str) -> None:
    print(f"GAGAL: {message}", file=sys.stderr)
    raise SystemExit(1)


def fetch(url: str) -> bytes | None:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        die(f"{url}: {error}")
    except OSError as error:
        die(f"{url}: {error}")
    return None


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {
        "source": {"styles": STYLES_BASE, "locales": LOCALES_BASE},
        "note": "Dikelola oleh scripts/csl-style.py. Jangan disunting tangan.",
        "styles": [],
        "locales": [],
    }


def save_manifest(manifest: dict) -> None:
    manifest["styles"].sort(key=lambda entry: entry["id"])
    manifest["locales"].sort()
    MANIFEST.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def describe(xml: bytes, wanted_id: str) -> dict:
    """Membaca <info> sebuah gaya, dan menolak yang bukan gaya CSL."""
    try:
        root = ElementTree.fromstring(xml)
    except ElementTree.ParseError as error:
        die(f"{wanted_id}: bukan XML yang sah ({error})")

    if not root.tag.endswith("}style") and root.tag != "style":
        die(f"{wanted_id}: akar berkasnya bukan <style>")

    def text(tag: str) -> str:
        found = root.find(f"csl:info/csl:{tag}", NS)
        return "" if found is None or found.text is None else found.text.strip()

    parent = ""
    for link in root.findall("csl:info/csl:link", NS):
        if link.get("rel") == "independent-parent":
            parent = (link.get("href") or "").rstrip("/").rsplit("/", 1)[-1]

    categories = [
        c.get("citation-format", "")
        for c in root.findall("csl:info/csl:category", NS)
        if c.get("citation-format")
    ]

    style_id = text("id").rstrip("/").rsplit("/", 1)[-1]
    return {
        "id": style_id or wanted_id,
        "title": text("title"),
        "kind": "dependent" if parent else "independent",
        "parent": parent,
        "format": categories[0] if categories else "",
        "class": root.get("class", ""),
    }


def add_style(manifest: dict, wanted: str, seen: set[str]) -> None:
    if wanted in seen:
        return
    seen.add(wanted)

    # Gaya independen duduk di akar; yang dependen di dalam dependent/.
    for relative in (f"{wanted}.csl", f"dependent/{wanted}.csl"):
        xml = fetch(f"{STYLES_BASE}/{relative}")
        if xml is not None:
            break
    else:
        die(
            f"{wanted}: tidak ada di repositori gaya resmi, baik sebagai gaya "
            f"independen maupun dependen. Periksa namanya di "
            f"https://github.com/citation-style-language/styles"
        )

    info = describe(xml, wanted)

    # Nama berkasnya mengikuti id di dalam berkasnya, bukan nama yang diketik.
    # Inilah yang mencegah "vancouver.csl" yang isinya nlm-citation-sequence.
    if info["id"] != wanted:
        print(
            f"  catatan: '{wanted}' ternyata ber-id '{info['id']}'. "
            f"Yang dipakai adalah id di dalam berkasnya."
        )

    out = CSL / "styles" / f"{info['id']}.csl"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(xml)

    entry = {
        "id": info["id"],
        "file": f"styles/{info['id']}.csl",
        "title": info["title"],
        "kind": info["kind"],
        "format": info["format"],
    }
    if info["parent"]:
        entry["parent"] = info["parent"]

    manifest["styles"] = [e for e in manifest["styles"] if e["id"] != info["id"]]
    manifest["styles"].append(entry)

    kind = info["kind"].upper()
    print(f"  {kind:11s} {info['id']:28s} {info['title']}")

    # Gaya dependen tidak bisa merender apa pun sendirian, jadi induknya ikut
    # diambil. Tanpa ini "Vancouver" tersimpan sebagai berkas empat baris yang
    # gagal begitu dipakai.
    if info["parent"]:
        print(f"              ↳ butuh induknya: {info['parent']}")
        add_style(manifest, info["parent"], seen)


def add_locale(manifest: dict, language: str) -> None:
    xml = fetch(f"{LOCALES_BASE}/locales-{language}.xml")
    if xml is None:
        die(f"locale {language}: tidak ada di repositori locale resmi")
    out = CSL / "locales" / f"locales-{language}.xml"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(xml)
    if language not in manifest["locales"]:
        manifest["locales"].append(language)
    print(f"  LOCALE      {language}")


def command_add(names: list[str]) -> None:
    if not names:
        die("sebutkan setidaknya satu id gaya, misalnya: add ieee apa")
    manifest = load_manifest()
    seen: set[str] = set()
    for name in names:
        if re.fullmatch(r"[a-z]{2}(-[A-Za-z]{2,4})?", name) and "-" in name:
            add_locale(manifest, name)
        else:
            add_style(manifest, name, seen)
    save_manifest(manifest)
    print(f"\n{len(manifest['styles'])} gaya, {len(manifest['locales'])} locale tercatat.")


def command_update() -> None:
    manifest = load_manifest()
    names = [entry["id"] for entry in manifest["styles"]]
    locales = list(manifest["locales"])
    manifest["styles"] = []
    seen: set[str] = set()
    for name in names:
        add_style(manifest, name, seen)
    for language in locales:
        add_locale(manifest, language)
    save_manifest(manifest)
    print(f"\n{len(manifest['styles'])} gaya, {len(manifest['locales'])} locale diperbarui.")


def command_list() -> None:
    manifest = load_manifest()
    for entry in manifest["styles"]:
        parent = f"  → {entry['parent']}" if entry.get("parent") else ""
        print(
            f"{entry['kind'][:3].upper():4s} {entry['format']:16s} "
            f"{entry['id']:30s} {entry['title']}{parent}"
        )
    print(f"\nlocale: {', '.join(manifest['locales'])}")


def command_check() -> int:
    """Memeriksa tanpa jaringan: berkasnya ada, terbaca, dan induknya lengkap."""
    manifest = load_manifest()
    known = {entry["id"] for entry in manifest["styles"]}
    problems: list[str] = []

    for entry in manifest["styles"]:
        path = CSL / entry["file"]
        if not path.exists():
            problems.append(f"{entry['id']}: berkasnya tidak ada ({entry['file']})")
            continue
        try:
            root = ElementTree.fromstring(path.read_bytes())
        except ElementTree.ParseError as error:
            problems.append(f"{entry['id']}: XML-nya rusak ({error})")
            continue

        found = root.find("csl:info/csl:id", NS)
        actual = "" if found is None or found.text is None else found.text.rsplit("/", 1)[-1]
        if actual != entry["id"]:
            problems.append(f"{entry['id']}: isi berkasnya ber-id '{actual}'")

        if entry.get("parent"):
            if entry["parent"] not in known:
                problems.append(f"{entry['id']}: induknya '{entry['parent']}' tidak ikut")
        elif root.find("csl:citation", NS) is None:
            problems.append(f"{entry['id']}: gaya independen tanpa blok <citation>")

    for language in manifest["locales"]:
        if not (CSL / "locales" / f"locales-{language}.xml").exists():
            problems.append(f"locale {language}: berkasnya tidak ada")

    for problem in problems:
        print(f"  {problem}")
    if problems:
        print(f"\n{len(problems)} masalah.")
        return 1
    print(f"{len(manifest['styles'])} gaya dan {len(manifest['locales'])} locale, semuanya utuh.")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    command, *rest = sys.argv[1:]
    if command == "add":
        command_add(rest)
    elif command == "update":
        command_update()
    elif command == "list":
        command_list()
    elif command == "check":
        return command_check()
    else:
        die(f"perintah tidak dikenal: {command}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
