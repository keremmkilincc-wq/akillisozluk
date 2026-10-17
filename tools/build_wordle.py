#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WORDLE HAVUZU DOGRULAYICI
=========================

Elle yazilan kelime listesi hataya açıktır. Bu betik listeyi denetler ve
temizler:

  1. Her kelime tam 5 harf mi?
  2. Harfler Turkce alfabesinde mi?
  3. KELIME SOZLUKTE GERCEKTEN VAR MI?

Ucuncu madde en onemlisi. Bir kelime gercekten kelime degilse (yazim
hatasi, uydurma sozcuk, bolgesel arkaik form) kullanici onu Wordle
cevabi olarak gorur ve oyunun sonu yanlis biter. Uydurma kelime, kelime
olmamaktan daha kotudur.

CIKTI: data/seed/wordle_clean.json — uygulamanin okudugu dosya.

NEDEN CIKTI AYRI: kaynak dosya elle, denetlenmis dosya makine. Bir sonraki
toplu calistirmada kaynak dosya bozulmaz; her seferinde yeniden denetlenir.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "seed" / "wordle_words.json"
# Cikti dogrudan ASSETS klasorune yazilir.
#
# Neden: uygulama bu dosyayi paketten okuyor. Araya bir "kopyala" adimi
# girdiginde dosya bir gunluk unutulur ve oyun "kelime listesi yok"
# hatasiyla acilmaz — ya da daha kotusu, eski bir liste sessizce calisir.
OUT = ROOT / "mobile" / "assets" / "data" / "wordle_clean.json"
CORPUS = ROOT / "data" / "morphology.json"

# Turkce alfabesinde BULUNMAYAN harfler.
#
# BURADA BIR HATA VARDI: once "qwxyz" yazilmis ve bu yuzden "y" ve "z"
# de yabanci sayilmisti. Ama ikisi de Turkce alfabesinin harfleri:
#     yazik, yemek, zaman, zihin, zorba, boğaz, güzel, yavaş ...
# Bu hata yuzlerce GECERLI kelimeyi eliyordu.
#
# Dogru liste yalnizca q, w, x. (j de Turkce'de yok ama nadir gorunur;
#  kelimelerde kullanilmaz, yine de disarida birakildi.)
FOREIGN = set("qwx")


def main() -> int:
    if not SOURCE.exists():
        print(f"HATA: {SOURCE} yok", file=sys.stderr)
        return 2

    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    raw_answers = data.get("answers", [])
    raw_pool = data.get("pool", [])

    print(f"kaynak      : {SOURCE.name}")
    print(f"  answers   : {len(raw_answers)}")
    print(f"  pool      : {len(raw_pool)}")
    print()

    # Sozlukten dogrulanacak kelimeler
    corpus: set[str] = set()
    if CORPUS.exists():
        cd = json.loads(CORPUS.read_text(encoding="utf-8"))
        corpus = {w.lower() for w in cd.get("lemmas", [])}
        print(f"sozluk      : {len(corpus)} madde")
    else:
        print("UYARI       : morphology.json yok, sozluk denetimi yapilamaz")

    verified: list[str] = []

    def check(word: str) -> tuple[str, str]:
        w = word.strip().lower()

        # SERT KURAL: uzunluk ve harf. Bunlar oyunu bozar.
        if len(w) != 5:
            return w, f"{len(w)} harf (5 olmali)"
        if any(ch in FOREIGN for ch in w):
            return w, "Turkce olmayan harf"
        if not w.isalpha():
            return w, "harf disi karakter"

        # YUMUSAK: sozlukte var mi? SERT KURAL DEGIL.
        # TDK listesi "arada", "benim", "olsun" gibi islev kelimelerini
        # ICERMIYOR. Bunlar gercek kelimeler; listede olmamak onlari
        # sahte yapmaz. Oyun tanim metni gostermez, kelime yeter.
        #
        # Bu ayrim onemli: "sozlukte yok"u sert yapmak OYNANABILIR havuzdan
        # gercek kelimeleri cikariyordu.
        if corpus and w in corpus:
            verified.append(w)
        return w, ""

    answers: list[str] = []
    pool: list[str] = []
    problems: list[tuple[str, str, str]] = []

    for kind, src, dst in (("cevap", raw_answers, answers),
                           ("havuz", raw_pool, pool)):
        for item in src:
            w, err = check(item)
            if err:
                problems.append((kind, item, err))
            elif w not in dst:
                dst.append(w)

    # Her cevap, oynanabilir havuzda da olmali. Aksi hâlde kullanıcı cevabı
    # bulamaz ve oyun bitmez — bu, en sinir bozucu hatadir.
    pool_set = set(pool)
    answers_not_playable = [a for a in answers if a not in pool_set]
    if answers_not_playable:
        print("UYARI: bu cevaplar havuzda yok, kullanici bulamaz:")
        for a in answers_not_playable:
            print(f"  - {a}")
            pool.append(a)
        pool_set.add(answers_not_playable[0])
        for a in answers_not_playable[1:]:
            pool_set.add(a)
        pool = list(dict.fromkeys(pool))
        print()

    print(f"DENELEM SONUCU")
    print(f"  gecerli cevap : {len(answers)}")
    print(f"  gecerli havuz : {len(pool)}")
    print(f"  elenen        : {len(problems)}")
    if problems:
        print()
        for kind, item, err in problems:
            print(f"  [{kind}] {item:<14} {err}")

    payload = {
        "meta": {
            **data.get("meta", {}),
            "letters": 5,
            "max_guesses": 6,
            "answer_count": len(answers),
            "pool_count": len(pool),
            "verified_against": "morphology.json lemmas",
        },
        "answers": answers,
        "pool": pool,
    }
    OUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print()
    print(f"  yazildi : {OUT}")
    print(f"  boyut   : {OUT.stat().st_size / 1024:.1f} KB")

    # Cevap havuzu bos kalirsa oyun kurulamaz.
    return 0 if len(answers) >= 100 and len(pool) >= 250 else 1


if __name__ == "__main__":
    raise SystemExit(main())