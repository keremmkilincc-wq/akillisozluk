#!/usr/bin/env python3
# =============================================================================
#  VERİ ÜRETİM HATTI — Faz 0
#
#  data/seed/*.json  →  mobile/assets/dict.db  (salt okunur, uygulamayla gelir)
#
#  Bu betik verinin tek giriş noktasıdır. Elle veritabanına dokunulmaz.
#
#  Kullanım:
#     python tools/build_dict.py --seed data/seed/words_sample.json \
#                                --out  mobile/assets/dict.db
#
#  Sonraki fazda Zemberek morfoloji analizinin çıktısı da bu dosyaya
#  beslenecek (--morph kaynak.csv).
# =============================================================================

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "data" / "schema.sql"

# -----------------------------------------------------------------------------
#  Türkçe metin normalizasyonu
#
#  Python'un str.lower() metodu da Dart'ın varsayılanı gibi Türkçe için
#  YANLIŞTIR: 'I'.lower() → 'i' (doğrusu 'ı'), 'İ'.lower() → 'i̇'
#  (birleşik noktalı). Aynı hatanın iki dilde de tekrarlanması iyi bir
#  işaret: bu bir kütüphane eksiği, kural hatası değil.
# -----------------------------------------------------------------------------

_LOWER_MAP = str.maketrans({"I": "ı", "İ": "i"})


def turkish_lower(text: str) -> str:
    """Türkçe kurallarına uygun küçük harf."""
    return text.translate(_LOWER_MAP).lower()


_FOLD_MAP = str.maketrans(
    {
        "ç": "c", "ğ": "g", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u",
        "Ç": "c", "Ğ": "g", "Ö": "o", "Ş": "s", "Ü": "u", "Â": "a", "Î": "i", "Û": "u",
    }
)


def fold(text: str) -> str:
    """Arama için katlanmış hâl: diyakritikler yok, ı/i aynı."""
    lowered = turkish_lower(text)
    # NFD ile ayrıştırılan birleşik işaretleri at (İ → i + U+0307 gibi)
    decomposed = unicodedata.normalize("NFD", lowered)
    stripped = "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn")
    return unicodedata.normalize("NFC", stripped).translate(_FOLD_MAP)


def normalize(text: str) -> str:
    """Veritabanı normalized_word alanı: diyakritik KORUNUR."""
    return turkish_lower(text.strip())


# -----------------------------------------------------------------------------
#  Yazım kuralları — Modül 6'nın kalbi
#
#  Kaynak: data/seed/words_sample.json içindeki "writing_rules" dizisi.
#  Burada sabit liste TUTULMAZ; iki kaynak birbirinden ayrılırsa veri
#  sessizce tutarsızlaşır.
#
#  Bu kurallar tamamen özgündür ve dilbilgisel kurala dayanır — telif riski
#  sıfırdır. Uygulama kural tablosunu okuyup kullanıcıya anında geri bildirim
#  verir: "kitabe" yazdıysa "doğrusu: kitabı" der.
# -----------------------------------------------------------------------------

WRITING_RULE_FIELDS = (
    "base_word", "wrong_form", "correct_form",
    "rule_type", "rule_explanation", "exam_tags", "confidence",
)


def load_writing_rules(seed: dict) -> list[dict]:
    return [
        {k: r.get(k) for k in WRITING_RULE_FIELDS}
        for r in seed.get("writing_rules", [])
    ]


# -----------------------------------------------------------------------------
#  Yükleme
# -----------------------------------------------------------------------------

def load_seeds(seed_dir: Path) -> tuple[list[dict], dict, list[dict]]:
    """Tum seed dosyalarini birlestirir.

    Neden coklu: tanim yazimi parti parti ilerliyor. Her parti kendi
    dosyasinda durur (words_000_core.json, words_001_eylem.json ...) ve
    burada birlestirilir. Bu sayede bir partiyi yazmak digerlerini
    dokunmadan mumkun; dosya sayisi arttikca da sure degismez.

    Ayni kelime iki dosyada varsa SONRAKI dosya kazanir — yani yeni parti
    eskisini duzeltebilir.

    YUK SIRASI ALFABETIK DEGIL, ANLAMSALDIR. Bu ayrim kritik:

        sorted(glob('words*.json'))

    'words_sample.json' adini alfabetik olarak EN SONA koyar, cunku 's'
    rakamdan buyuktur. Ama sample EN ESKI dosyadır — calismaya baslangic
    tohumu. Boylece parti 000-003'te elden yazilmis 21 tanim EZILIYORDU;
    14 tanimde parti dosyasi daha zengin (ornegin `aci`: 4 anlam'a karsi
    3, `sabir`: 3'e karsi 2). Bu tanimlar hic yayina cikmadi.

    Dogru sira: once words_sample.json (taban), sonra parti dosyalari
    numaraya gore. Boylece niyet gerceklesir.
    """
    tum = list(seed_dir.glob("words*.json"))
    if not tum:
        raise SystemExit(f"HATA: {seed_dir} icinde words*.json yok")

    # Taban dosya en once: en eski veri, en zayif tanim.
    taban = [f for f in tum if f.name == "words_sample.json"]
    partiler = sorted(
        (f for f in tum if f.name != "words_sample.json"),
        # words_007_x.json -> 7 ; sayisal siralama, alfabetik degil.
        key=lambda f: (f.name.split("_")[1] if "_" in f.name else "999", f.name),
    )
    files = taban + partiler

    merged: dict[str, dict] = {}
    meta: dict = {}
    rules: dict[tuple, dict] = {}

    for f in files:
        data = json.loads(f.read_text(encoding="utf-8"))
        meta.update(data.get("meta", {}))
        for w in data.get("words", []):
            merged[w["word"]] = w
        # Yazim kurallari da birlesir; ayni kural iki dosyadaysa sonraki kazanir
        for r in data.get("writing_rules", []):
            rules[(r["base_word"], r["wrong_form"])] = r

    print(f"  seed dosyalari   : {len(files)}")
    print(f"    yuk sirasi     : {' -> '.join(f.name for f in files)}")
    return list(merged.values()), meta, list(rules.values())


def load_corpus(corpus_path: Path) -> list[str]:
    """Tanim bekleyen madde havuzunu dondurur (Tanim YOK — sadece kimlik).

    Bu kelimeler aranabilir, listelenebilir, morfolojisi gorunur; ama
    tanimlari UYDURULMAZ. Uydurma tanim, hic tanimden kotudur: kullanici
    dogru sanar.
    """
    if not corpus_path.exists():
        return []
    data = json.loads(corpus_path.read_text(encoding="utf-8"))
    return data.get("lemmas", [])


def build(seed_dir: Path, out_path: Path, corpus_path: Path | None = None) -> int:
    words, meta, writing_rules = load_seeds(seed_dir)
    corpus = load_corpus(corpus_path) if corpus_path else []

    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    conn = sqlite3.connect(out_path)
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))

    word_ids: dict[str, int] = {}

    for w in words:
        surface = w["word"]
        cursor = conn.execute(
            """
            INSERT INTO words (
                word, normalized_word, search_folded,
                origin, origin_period, is_pure_turkish, phonetics,
                usage_frequency, confidence, source_note, exam_tags,
                definition_status, has_audio
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'yazildi', 0)
            """,
            (
                surface,
                normalize(surface),
                fold(surface),
                w.get("origin"),
                w.get("origin_period"),
                1 if w.get("is_pure_turkish") else 0,
                w.get("phonetics"),
                float(w.get("usage_frequency", 0.5)),
                float(w.get("confidence", 1.0)),
                w.get("source_note", "Faz 0 tad testi"),
                w.get("exam_tags", ""),
            ),
        )
        word_id = int(cursor.lastrowid)
        word_ids[surface] = word_id

        for m in w.get("meanings", []):
            conn.execute(
                """
                INSERT INTO meanings (
                    word_id, meaning_order, word_type, sense_label,
                    definition, example_classic, example_author,
                    example_modern, example_note, confidence
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    word_id,
                    int(m["order"]),
                    m["type"],
                    m.get("sense", "gercek"),
                    m["definition"],
                    m.get("example_classic"),
                    m.get("example_author"),
                    m.get("example_modern"),
                    m.get("example_note"),
                    float(m.get("confidence", 1.0)),
                ),
            )

        for r in w.get("relations", []):
            conn.execute(
                """
                INSERT OR IGNORE INTO relations
                    (word_id, related_word, relation_type, note, confidence)
                VALUES (?, ?, ?, ?, 1.0)
                """,
                (word_id, r["word"], r["type"], r.get("note")),
            )

        for m in w.get("morphology", []):
            conn.execute(
                """
                INSERT OR IGNORE INTO morphology
                    (word_id, surface, root, suffixes, explanation, note)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    word_id,
                    m["surface"],
                    m["root"],
                    json.dumps(m.get("suffixes", []), ensure_ascii=False),
                    m.get("explanation"),
                    m.get("note"),
                ),
            )

    # Yazım kuralları — kaynak JSON (tek doğru kaynak)
    for rule in writing_rules:
        conn.execute(
            """
            INSERT OR IGNORE INTO writing_rules
                (base_word, wrong_form, correct_form, rule_type,
                 rule_explanation, exam_tags, confidence)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                rule["base_word"], rule["wrong_form"], rule["correct_form"],
                rule["rule_type"], rule["rule_explanation"],
                rule["exam_tags"] or "", float(rule["confidence"] or 1.0),
            ),
        )

    # -----------------------------------------------------------------------
    #  TANIM BEKLEYEN GOVDE
    #
    #  Elle yazilmis kelimeler yuklendi. Simdi kalan tum maddeler eklenir:
    #  aranabilir, listelenebilir, morfolojisi gorunur — ama tanimlari
    #  UYDURULMAZ. definition_status = 'bekliyor'.
    #
    #  Neden onemli: uygulama 58.792 madde gosterebilir ve hicbiri yanlis
    #  bilgi icermez. Tanimi olmayan madde "bu madde icin calisma suruyor"
    #  der; uydurma tanim ise kullaniciya dogruymus gibi sunulur.
    # -----------------------------------------------------------------------
    pending = 0
    if corpus:
        batch: list[tuple] = []
        for surface in corpus:
            if surface in word_ids:
                continue
            batch.append((
                surface, normalize(surface), fold(surface),
                None, None, 0, None,
                0.0, 0.0, "TDK listesi - tanim bekliyor", "",
                "bekliyor", 0,
            ))
            if len(batch) >= 5000:
                conn.executemany(
                    """
                    INSERT INTO words (
                        word, normalized_word, search_folded,
                        origin, origin_period, is_pure_turkish, phonetics,
                        usage_frequency, confidence, source_note, exam_tags,
                        definition_status, has_audio
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    batch,
                )
                pending += len(batch)
                batch.clear()

        if batch:
            conn.executemany(
                """
                INSERT INTO words (
                    word, normalized_word, search_folded,
                    origin, origin_period, is_pure_turkish, phonetics,
                    usage_frequency, confidence, source_note, exam_tags,
                    definition_status, has_audio
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                batch,
            )
            pending += len(batch)

    # Tam metin indeksini doldur (external content tablosu)
    conn.execute(
        "INSERT INTO definitions_fts(definitions_fts) VALUES('rebuild')"
    )

    counts = {
        "words": conn.execute("SELECT COUNT(*) FROM words").fetchone()[0],
        "meanings": conn.execute("SELECT COUNT(*) FROM meanings").fetchone()[0],
        "relations": conn.execute("SELECT COUNT(*) FROM relations").fetchone()[0],
        "morphology": conn.execute("SELECT COUNT(*) FROM morphology").fetchone()[0],
        "writing_rules": conn.execute("SELECT COUNT(*) FROM writing_rules").fetchone()[0],
    }

    conn.execute(
        "UPDATE dataset_meta SET value = ? WHERE key = 'word_count'", (str(counts["words"]),)
    )
    conn.execute(
        "UPDATE dataset_meta SET value = ? WHERE key = 'dataset_version'",
        (meta.get("dataset_version", "0.1.0"),),
    )
    conn.commit()

    # Bütünlük denetimi
    problems = verify(conn)

    conn.execute("VACUUM")
    conn.close()

    size_mb = out_path.stat().st_size / 1_048_576
    print(f"  dict.db yazildi: {out_path}")
    print(f"  boyut          : {size_mb:.2f} MB")
    for key, value in counts.items():
        print(f"  {key:<14}: {value}")
    print(f"  {'bekleyen':<14}: {pending}")

    written = counts["words"] - pending
    pct = 100.0 * written / counts["words"] if counts["words"] else 0.0
    print(f"  {'yazilmis':<14}: {written} / {counts['words']}  ({pct:.1f}%)")

    if problems:
        print("\n  UYARILAR")
        for p in problems:
            print(f"    - {p}")
    else:
        print("\n  Butunluk denetimi temiz.")

    return 0 if not problems else 1


def verify(conn: sqlite3.Connection) -> list[str]:
    """Veri hattının kendi kendini denetlemesi."""
    problems: list[str] = []

    # 1. Anlamı olmayan kelime var mı?
    #
    # Artık HATA DEĞİL: gövdenin 58.653 kelimesinin henüz tanımı yok ve
    # olması da beklenen durum. Hata olan şey TUTARSIZLIK:
    #   "yazildi" diyor ama anlamı yok  -> veri hattı bozuk
    #   anlamı var ama "bekliyor" diyor -> bayrak unutulmuş
    lies = conn.execute(
        "SELECT COUNT(*) FROM words w WHERE w.definition_status = 'yazildi' "
        "AND NOT EXISTS (SELECT 1 FROM meanings m WHERE m.word_id = w.id)"
    ).fetchone()[0]
    if lies:
        problems.append(
            f"{lies} kelime 'yazildi' diyor ama anlamı yok "
            f"(bayrak elle yazılmış tanımlar arasında unutulmuş)"
        )

    stale = conn.execute(
        "SELECT COUNT(*) FROM words w WHERE w.definition_status = 'bekliyor' "
        "AND EXISTS (SELECT 1 FROM meanings m WHERE m.word_id = w.id)"
    ).fetchone()[0]
    if stale:
        problems.append(
            f"{stale} kelimenin anlamı var ama 'bekliyor' diyor "
            f"(tanım yazıldı, bayrak güncellenmedi)"
        )

    # 2. normalize/fold doğru mu?  (Python tarafında, çünkü SQL'de yok)
    bad_normalized = []
    bad_folded = []
    for word, norm, fld in conn.execute(
        "SELECT word, normalized_word, search_folded FROM words"
    ):
        if norm != turkish_lower(word):
            bad_normalized.append(word)
        if fld != fold(word):
            bad_folded.append(word)

    if bad_normalized:
        problems.append(
            f"{len(bad_normalized)} kelimede Türkçe küçük harf kuralı bozuk: "
            f"{bad_normalized[:3]}"
        )
    if bad_folded:
        problems.append(
            f"{len(bad_folded)} kelimede katlama hatalı: {bad_folded[:3]}"
        )

    # 3. Aynı kelime iki kez var mı?
    dupes = conn.execute(
        "SELECT word, COUNT(*) c FROM words GROUP BY word HAVING c > 1"
    ).fetchall()
    if dupes:
        problems.append(f"tekrar eden kelimeler: {[d[0] for d in dupes]}")

    # 4. FTS indeksi dolu mu?
    fts_count = conn.execute("SELECT COUNT(*) FROM definitions_fts").fetchone()[0]
    meaning_count = conn.execute("SELECT COUNT(*) FROM meanings").fetchone()[0]
    if fts_count != meaning_count:
        problems.append(f"FTS indeksi boş: {fts_count}/{meaning_count}")

    # 5. Uydurma alıntı denetimi
    #    Yazar adı yazılı ama alıntı metni yoksa bu bir hatadır.
    ghost = conn.execute(
        "SELECT COUNT(*) FROM meanings "
        "WHERE example_author IS NOT NULL AND example_classic IS NULL "
        "AND example_note IS NULL"
    ).fetchone()[0]
    if ghost:
        problems.append(f"{ghost} kayıtta yazar var ama cümle yok")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Sözlük veritabanını üretir")
    parser.add_argument(
        "--seed-dir",
        type=Path,
        default=ROOT / "data" / "seed",
        help="words*.json dosyalarinin bulundugu klasor (hepsi birlestirilir)",
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        default=ROOT / "data" / "morphology.json",
        help="Tanim bekleyen madde havuzu (build_morphology.py ciktisi)",
    )
    parser.add_argument(
        "--no-corpus",
        action="store_true",
        help="Sadece elle yazilmis tanimlari yukle (govde ekleme)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "mobile" / "assets" / "dict.db",
    )
    args = parser.parse_args()

    if not args.seed_dir.exists():
        print(f"HATA: seed klasoru bulunamadi: {args.seed_dir}", file=sys.stderr)
        return 2

    print(f"  seed    : {args.seed_dir}")
    print(f"  govde   : "
          f"{'kapali (--no-corpus)' if args.no_corpus else args.corpus}")

    return build(
        args.seed_dir,
        args.out,
        None if args.no_corpus else args.corpus,
    )


if __name__ == "__main__":
    raise SystemExit(main())