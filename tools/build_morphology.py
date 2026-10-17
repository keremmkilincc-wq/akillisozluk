#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TÜRKÇE SÖZLÜK HAVUZU VE EK ENVANTERİ
=====================================

ÖNCEKİ YAKLAŞIM YANLIŞTI — DÜZELTİLDİ
--------------------------------------
İlk denemede liste üzerinde "her girişi kök+ek olarak ayrıştır" denecek ve
beklenen çıktı 76.190 giriş → ~45.000 lemma olacaktı.

Ölçüm bunu göstermedi:
  * "kitaplar", "gözlerini", "evler", "çocuklar" listede YOK.
  * TDK imla kılavuzu listesi çekimli biçimleri değil, TEMEL biçimleri
    ve yazımı karıştırılan özel sözcükleri taşıyor.

Yani "%41 çekimli biçim" çıkarımı yanlıştı. O oran, gerçek çekim değil,
"abide" → "ab"+"de" gibi YANLIŞ soyma denemelerinin oranıydı. 518 hatalı
ayrıştırma ölçüldü; hepsi bu yüzden.

DOĞRU ANLAŞILAN
---------------
Bu liste zaten bir SÖZLÜK maddeleri listesidir:
    61.190 tek kelime girişi → ~46.000 farklı MADDE
Bu, planın tahmin ettiği ~45.000 lemma sayısına düşüyor. Yani kırk
adet birleştirme yapmaya gerek yok — liste zaten lemma.

PEKİ MORFOLOJİ NE İŞE YARAR?
---------------------------
Girdi olarak değil, SORGUNUN PARÇASI olarak:
    kullanıcı "kitaplarımızdan" yazar → kök bulunur → "kitap" gösterilir
Yani analiz cihazda, kullanıcının girdisine çalışır. Bu betik iki malzeme
üretir:
    1. lemmas      — doğrulanmış madde listesi (arama vektörü)
    2. suffixes   — ek envanteri (ağırlıklarla birlikte)

Telif: yalnızca SÖZCÜK LİSTESİ kullanılır. Bu bilgi ürünü değildir; tanım
metni telif konusudur ve bu projede tanımlar sıfırdan yazılır.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LIST = Path.home() / ".config" / "openchamber" / "tdk_words.txt"
DEFAULT_OUT = ROOT / "data" / "morphology.json"

VOWELS = set("aeıioöuü")

FOLD_MAP = str.maketrans({
    "ç": "c", "ğ": "g", "ö": "o", "ş": "s", "ü": "u",
    "â": "a", "î": "i", "û": "u",
})


def turkish_lower(text: str) -> str:
    return text.translate(str.maketrans({"I": "ı", "İ": "i"})).lower()


def fold(text: str) -> str:
    """Arama için katlanmış hâl."""
    low = turkish_lower(text)
    decomposed = unicodedata.normalize("NFD", low)
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    return unicodedata.normalize("NFC", stripped).translate(FOLD_MAP)


# ---------------------------------------------------------------------------
#  TÜRKÇE EK ENVANTERİ
#
#  Ünlü uyumunu hesaplamak yerine varyantları AÇIKÇA yazıyoruz. Hesap yapmak
#  hataya açıktır (derinlik, istisnalar, "dere" gibi kısa gövdeler).
#
#  ağırlık: ne kadar tanıdık ve sık bir ek, o kadar yüksek.
#  Bunlar kullanıcı girdisinin kökü bulunurken kullanılır.
# ---------------------------------------------------------------------------

SUFFIXES: list[tuple[str, float]] = [
    # çok sulu zincirler (en uzun, önce denenir)
    ("lardan", 1.0), ("lerden", 1.0), ("larından", 1.0), ("lerinden", 1.0),
    ("larına", 1.0), ("lerine", 1.0), ("larımızdan", 1.0), ("lerimizden", 1.0),
    ("ımızın", 1.0), ("imizin", 1.0), ("umuzun", 1.0), ("ümüzün", 1.0),
    ("sının", 1.0), ("sinin", 1.0), ("sunuzun", 1.0), ("sünüzün", 1.0),
    ("lığını", 1.0), ("liğini", 1.0), ("luğunu", 1.0), ("lüğünü", 1.0),
    ("lığıyla", 1.0), ("liğiyle", 1.0), ("luğuyla", 1.0), ("lüğüyle", 1.0),
    ("daki", 1.0), ("deki", 1.0), ("taki", 1.0), ("teki", 1.0),

    # hâl ekleri
    ("dan", 1.0), ("den", 1.0),
    ("ın", 1.0), ("in", 1.0), ("un", 1.0), ("ün", 1.0),
    ("nın", 1.0), ("nin", 1.0), ("nun", 1.0), ("nün", 1.0),
    ("ya", 1.0), ("ye", 1.0), ("da", 1.0), ("de", 1.0),
    ("ta", 1.0), ("te", 1.0),

    # iyelik ekleri
    ("ınız", 1.0), ("iniz", 1.0), ("unuz", 1.0), ("ünüz", 1.0),
    ("sınız", 1.0), ("siniz", 1.0), ("sunuz", 1.0), ("sünüz", 1.0),
    ("ım", 1.0), ("im", 1.0), ("um", 1.0), ("üm", 1.0),
    ("sı", 1.0), ("si", 1.0), ("su", 1.0), ("sü", 1.0),
    ("ını", 1.0), ("ini", 1.0), ("unu", 1.0), ("ünü", 1.0),
    ("sı", 1.0), ("si", 1.0), ("su", 1.0), ("sü", 1.0),
    ("mız", 0.95), ("miz", 0.95), ("muz", 0.95), ("müz", 0.95),

    # çekimli fiil ekleri
    ("acaktan", 1.0), ("ecekten", 1.0), ("maktan", 1.0), ("mekten", 1.0),
    ("acak", 1.0), ("ecek", 1.0), ("makta", 1.0), ("mekte", 1.0),
    ("ıyor", 1.0), ("iyor", 1.0), ("uyor", 1.0), ("üyor", 1.0),
    ("yor", 1.0), ("dır", 1.0), ("dir", 1.0), ("dur", 1.0), ("dür", 1.0),
    ("dı", 0.9), ("di", 0.9), ("du", 0.9), ("dü", 0.9),
    ("tı", 0.9), ("ti", 0.9), ("tu", 0.9), ("tü", 0.9),

    # yapım ekleri
    ("lığı", 1.0), ("liği", 1.0), ("luğu", 1.0), ("lüğü", 1.0),
    ("lığını", 1.0), ("liğini", 1.0),
    ("lık", 1.0), ("lik", 1.0), ("luk", 1.0), ("lük", 1.0),
    ("sızlık", 1.0), ("sizlik", 1.0), ("suzluk", 1.0), ("süzlük", 1.0),
    ("lı", 0.9), ("li", 0.9), ("lu", 0.9), ("lü", 0.9),
    ("cı", 0.9), ("ci", 0.9), ("cu", 0.9), ("cü", 0.9),
    ("sız", 0.9), ("siz", 0.9), ("suz", 0.9), ("süz", 0.9),
    ("çı", 0.9), ("ci", 0.9), ("cu", 0.9), ("cü", 0.9),

    # kip ekleri
    ("ması", 0.95), ("mesi", 0.95), ("muş", 0.95), ("müş", 0.95),
    ("ası", 0.9), ("esi", 0.9), ("mış", 0.9), ("miş", 0.9),
    ("ar", 0.9), ("er", 0.9), ("an", 0.85), ("en", 0.85),
    ("sa", 0.9), ("se", 0.9), ("mak", 0.9), ("mek", 0.9),

    # çok sulu
    ("ler", 1.0), ("lar", 1.0),

    # tek harfli — en riskli, en sona
    ("ki", 0.85), ("a", 0.5), ("e", 0.5),
    ("ı", 0.55), ("i", 0.55), ("u", 0.5), ("ü", 0.5),
]

SUFFIXES.sort(key=lambda t: -len(t[0]))


# ---------------------------------------------------------------------------
#  KÖK BULUCU — kullanıcı girdisi için
# ---------------------------------------------------------------------------

# Yön KURALI: bu haritalar YUZEY -> GOVDE yönündedir.
# Çünkü kullanıcı "kitabımı" yazar; biz geriye gideriz.
#   kitab  -> kitap   (b -> p, kaynaştırmanın geri alınması)
#   ağac   -> ağaç    (c -> ç, sertleşmenin geri alınması)
# İleri yön (kitap -> kitab) burada KULLANILMAZ; tersini uygularsak
# "kitap"ın kendisini "kitab"a çevirip sözlükten bulamayız.
REVERSE_SOFTEN = {"b": "p", "c": "ç", "d": "t", "ğ": "k"}
REVERSE_HARDEN = {"c": "ç", "s": "ş"}


class StemFinder:
    """Verilen sözcüğün kökünü madde listesine karşı arar."""

    def __init__(self, lemmas: set[str]):
        self.lemmas = lemmas

    def _repairs(self, stem: str) -> list[tuple[str, bool]]:
        """Bir gövde parçasından geriye dönük olası kaynak gövdeler.

        Dönüş: (gövde, ses_onarımı_gerekli_mi)

        Ses onarımları:
          kitab → kitap   (k→b kaynaştırma)
          ağac  → ağaç    (c→ç sertleşme)
        """
        out: list[tuple[str, bool]] = [(stem, False)]

        if len(stem) >= 3 and stem[-1] in REVERSE_SOFTEN:
            out.append((stem[:-1] + REVERSE_SOFTEN[stem[-1]], True))
        if len(stem) >= 3 and stem[-1] in REVERSE_HARDEN:
            out.append((stem[:-1] + REVERSE_HARDEN[stem[-1]], True))

        return out

    def find(self, word: str) -> dict | None:
        """Kök bulunamazsa None döner.

        Ekler ARDIŞIK soyulur: "gözlerini" = göz + ler + ini.
        Tek ek soyunca yetmez, çünkü "gözler" de bir madde değildir.
        """
        w = turkish_lower(word)

        if fold(w) in self.lemmas:
            return {"root": word, "suffixes": [], "confidence": 1.0}

        candidates = self._collect(w, [], 1.0, repaired=False)
        if not candidates:
            return None

        # SIRALAMA KURALI — üç aşamalı, üçü de şart:
        #
        #  1. En YÜKSEK ek güveni kazanır (rank_score).
        #     Çünkü yanlış ayrıştırma genellikle bir EKNİN İÇİNDEN kesilir:
        #        masalar  → masa + [lar]  (1.0)  |  masal + [ar]  (0.9)
        #        ateşini  → ateş + [ini]  (1.0)  |  ateşin + [i]  (0.55)
        #     Doğrusu her zaman yüksek güvenli olan.
        #
        #  2. Güven eşitse en AZ ek sayısı kazanır.
        #     "kitaplarımızdan" iki biçimde çözülür:
        #        kitap + [larımızdan]    -> 1 ek
        #        kitapları + [mız, dan]  -> 2 ek
        #     Baş kelime "kitap"tır.
        #
        #  3. O da eşitse en UZUN gövde kazanır.
        #     "gözlüğünü" iki biçimde de tek ekli ve ikisi de 1.0:
        #        göz + [lüğünü]   -> gövde 3 harf  (YANLIŞ)
        #        gözlük + [ünü]   -> gövde 6 harf  (DOĞRU)
        #     Turetilen bir madde ("gözlük"), çekimlenmiş olandan ("göz")
        #     önce gelir.
        #
        # NEDEN rank_score, confidence DEĞİL:
        # confidence iki şeyi birleştiriyordu — ek güveni VE ses onarımı
        # cezası. "gözlük"e giderken "ğ"->"k" onarımı uygulanıyor ve puanı
        # 0.85'e düşüyor; ama bu onarım bir tahmin değil, Türkçenin
        # öngörülebilir bir ünsüz olayı. Doğru gövde, yanlış sebeple
        # elendiği için göz'ün gerisinde kalıyordu.
        #
        # Sıralama = ek güveni (tahmin kalitesi)
        # Raporlanan puan = ek güveni × onarım cezası (belirsizlik bildirimi)
        # İkisi farklı sorulara cevap verir; karıştırılmamalı.
        candidates.sort(
            key=lambda c: (
                -c["rank_score"],
                len(c["suffixes"]),
                -len(c["root"]),
            )
        )
        return candidates[0]

    def _collect(
        self,
        w: str,
        acc: list[str],
        conf: float,
        repaired: bool,
        depth: int = 0,
    ) -> list[dict]:
        """TÜM olası ayrıştırmaları toplar; sıralamayı çağıran yapar.

        Neden hepsini topluyoruz: "ilk bulunan kazanır" kuralı denendi ve
        yanlış sonuç verdi — en uzun ek denendiği için türetilmiş bir madde
        ("gözlük"), çekimli gövdesi ("göz") kadar derin olmayan bir ayrıştırmayla
        gölgeleniyordu. Doğru çözüm bazen daha kısa ekle, daha derin bir
        adımda bulunuyor.
        """
        # "evlerindekilerin" = ev + ler + deki + ler + in -> 5 ek gerekir.
        # Sınır 3'tü ve bu kelimeyi kaçırıyordu.
        if depth > 5:
            return []

        found: list[dict] = []

        for suffix, weight in SUFFIXES:
            # Gövde en az 2 harf olmalı — "ev", "su", "at", "el" gibi
            # Türkçenin en sık kelimeleri 2 harflidir.
            #
            # Daha katı bir uzunluk kuralı YANLIŞTIR ve denendi:
            # "abide" -> "ab" + "de" diye ayrıştırmayı engellemek için 3
            # konuldu, ama "göz", "yol", "ok", "ev" gibi kelimeleri de
            # eledi. Asıl koruma zaten sözlük üyeliği: "ab" listede yok,
            # reddedilir. Uzunluk kuralına gerek yok.
            if len(w) - len(suffix) < 2 or not w.endswith(suffix):
                continue

            stem = w[: -len(suffix)]
            step_conf = conf * weight

            for cand, fix in self._repairs(stem):
                if len(cand) < 2:
                    continue
                if fold(cand) in self.lemmas:
                    found.append({
                        "root": cand,
                        # Ekler sondan başa doğru soyuldu; anlam sırasına döndür
                        "suffixes": [suffix] + acc,
                        # Sıralama bunu kullanır: yalnızca ek güveni.
                        "rank_score": round(min(step_conf, 1.0), 4),
                        # Raporlanan puan bunu kullanır: onarım cezası dahil.
                        "confidence": round(
                            min(step_conf * (0.85 if fix else 1.0), 1.0), 2
                        ),
                    })
                    # Bu gövde BİR MADDE. Daha fazla ek soyulmeye çalışmak
                    # yanlış olur ("göz" -> "go" gibi). Ama DİĞER ekler
                    # denenmeye devam eder — "gözlük" de bir adaydır.
                    continue

                # Bu gövde madde değil — daha kısa olanı dene (ek zinciri)
                found.extend(
                    self._collect(
                        stem,
                        [suffix] + acc,
                        step_conf,
                        repaired or fix,
                        depth + 1,
                    )
                )

        return found


# ---------------------------------------------------------------------------
#  ANA AKIŞ
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(
        description="Sozluk havuzu ve ek envanteri uretir")
    ap.add_argument("--list", type=Path, default=DEFAULT_LIST)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    if not args.list.exists():
        print(f"HATA: liste bulunamadi: {args.list}", file=sys.stderr)
        return 2

    raw = io.open(args.list, encoding="utf-8", errors="replace").read().splitlines()
    entries = [w.strip() for w in raw if w.strip() and " " not in w]

    # TDK listesi buyuk harfli OZEL ADLARI korur (Abana, Adana, Afgan).
    # Sogzluk maddesi degildirler; otomatik elenir.
    #
    # BURADA ONCEDEN BIR HATA VARDI; 800 maddeyi yanlislikla sozluk maddesi
    # sayiyordu:
    #
    #     if not w.isascii() and w[:1].isupper():
    #
    # "not w.isascii()" kosulu Turkce ozel adlarin BUYUK BOLUMUNU gizliyordu.
    # Cogu saf ASCII'dir: "Abbas", "Abhaz", "Ahlat", "Kavak", "Lapon", "Hakas",
    # "Hatay", "Kepez", "Japon". Bunlar filtreye hic girmiyor, madde saniliyordu.
    #
    # Wordle havuzu hazirlanirken fark edildi: 5 harfli "cevap" kelimeleri
    # Abbas, Lapon, Japon, Ahlat ile doluydu. Oynanamaz bir oyun.
    #
    # Dogru kural tek basina buyuk harf kontroludur.
    lemmas: set[str] = set()
    proper: set[str] = set()
    for w in entries:
        if w[:1].isupper():
            proper.add(w)
        else:
            lemmas.add(w)

    compounds = [w.strip() for w in raw if " " in w.strip()]

    finder = StemFinder({fold(x) for x in lemmas})

    # Kendi kendini sınama: bilinen kök/ek çiftleri
    probes = [
        ("kitaplarımızdan", "kitap"), ("gözlerini", "göz"),
        ("evlerindekilerin", "ev"), ("kitaplarından", "kitap"),
        ("çocuklar", "çocuk"), ("insanların", "insan"),
        ("okulları", "okul"), ("denizler", "deniz"),
        ("güneşleri", "güneş"), ("öğretmenler", "öğretmen"),
    ]
    print("KOK BULUCU DOGRULAMASI")
    passed = 0
    for word, expected in probes:
        r = finder.find(word)
        ok = r is not None and fold(r["root"]) == fold(expected)
        if ok:
            passed += 1
        got = r["root"] if r else "(bulunamadi)"
        mark = "OK " if ok else "HATA"
        print(f"  {mark} {word:<20} -> {got:<14} (beklenen: {expected})")
    print(f"  {passed}/{len(probes)} dogru")
    print()

    # OZEL AD DENETIMI
    # Bu regresyon bir kez yandi: 800 ozel ad madde sayiliyordu ve Wordle
    # havuzu yer/etnik adlarla doldu. Asagidaki adlar madde OLMAMALIDIR.
    proper_probes = ["Abana", "Adana", "Afgan", "Afrika", "Ahlat",
                     "Akdeniz", "Abbas", "Lapon", "Hakas", "Japon",
                     "Hatay", "Kepez", "Kavak", "İstanbul"]
    sizan_probes = ["kitap", "ev", "insan", "göz", "deniz", "ateş", "sevgi"]

    yanlis = [w for w in proper_probes if w in lemmas]
    eksik = [w for w in sizan_probes if w not in lemmas]
    print("OZEL AD / MADDE AYRIMI")
    print(f"  ozel ad olmamasi gerekenler ({len(proper_probes)}): "
          f"{'hepsi madde degil - TAMAM' if not yanlis else 'SIZINTI: ' + ', '.join(yanlis)}")
    print(f"  madde olmasi gerekenler  ({len(sizan_probes)}): "
          f"{'hepsi madde - TAMAM' if not eksik else 'EKSIK: ' + ', '.join(eksik)}")
    print()

    payload = {
        "meta": {
            "engine": "kendi (bagimsiz Turkce kok bulucu)",
            "lexicon_source": "TDK imla kilavuzu listesi (yalnizca SOZCUKLER)",
            "copyright_note": (
                "Bu dosya yalnizca SOZCUK LISTESI icerir. Tanim metni icermez. "
                "Tanimlar bu projede ayrica yazilir."
            ),
            "lemma_count": len(lemmas),
            "proper_noun_count": len(proper),
            "compound_count": len(compounds),
        },
        "lemmas": sorted(lemmas),
        "proper_nouns": sorted(proper),
        "suffixes": [{"suffix": s, "weight": w} for s, w in SUFFIXES],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    io.open(args.out, "w", encoding="utf-8").write(
        json.dumps(payload, ensure_ascii=False, indent=1)
    )

    print(f"  yazildi      : {args.out}")
    print(f"  MADDE        : {len(lemmas)}")
    print(f"  ozel ad      : {len(proper)} (eleniyor)")
    print(f"  birlesik     : {len(compounds)}")
    print(f"  ek envanteri : {len(SUFFIXES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())