#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TDRK kelime listesinin analizi — 2500 kelimelik plan için gerçek veri.

Bu liste TDK imla kilavuzundan cekilmis DÜZ KELIME LISTESIDIR.
Telif konusu: kelime listeleri bilgi urunu degildir, tanim metinleri
telif konusudur. Biz tanimlari kendimiz yaziyoruz.

Buradan cikan sayilar planin gerceklik kontrolu icin.
"""

import io
import unicodedata
from collections import Counter

PATH = r"C:\Users\Kilinc\AppData\Local\Temp\opencode\tdk_words.txt"

lines = io.open(PATH, encoding="utf-8", errors="replace").read().splitlines()
words = [w.strip() for w in lines if w.strip()]

print(f"Toplam satir          : {len(words)}")

# Tek kelime mi, birlesik mi?
single = [w for w in words if " " not in w]
compound = [w for w in words if " " in w]
print(f"Tek kelime            : {len(single)}")
print(f"Birlesik (bosluklu)   : {len(compound)}")

# Uzunluk dagilimi (yalnizca tek kelimeler)
by_len = Counter(len(w) for w in single)
print()
print("Harf sayisina gore dagilim (tek kelimeler):")
for n in range(2, 13):
    c = by_len.get(n, 0)
    if c:
        print(f"  {n:>2} harf : {c:>6}")

# 5 harfli havuz -> Wordle uygunlugu
five = [w for w in single if len(w) == 5]
print()
print(f"5 HARFLI KELIME SAYISI: {len(five)}")
print(f"  Wordle cevabı olabilecek havuz: {len(five)}")
print(f"  6 denemede tek kelime tahmini dogru tahmin yuzdesi: {round(100/len(five), 1) if five else 0}%")

# Turkce harf disi olanlar (yabanci sozcukler havuzu)
def has_foreign(ch):
    return ch in "qwxyzQWXYZ"

latin_only = [w for w in single if all(has_foreign(c) for c in w)]
print()
print(f"Tamamen latin harfli (yabanci) : {len(latin_only)}")
print(f"Turkce harf iceren            : {len(single) - len(latin_only)}")

# Kisa ve orta: oyun/morfoloji icin ideal
print()
print("Oyun havuzu analizi:")
for n in (4, 5, 6):
    pool = [w for w in single if len(w) == n]
    print(f"  {n} harf : {len(pool):>6} kelime")

# Kumez degisikligi: cok tekrar eden harfler
harf_sayilari = Counter()
for w in single:
    harf_sayilari.update(w)
print()
print("En sik kullanilan harfler:")
for ch, c in harf_sayilari.most_common(12):
    print(f"  {ch} : {c}")

# Cift harfli (heceleme testleri icin)
cift = [w for w in single if any(a == b for a, b in zip(w, w[1:]))]
print()
print(f"Iki harfi ardisik ayni olan kelimeler : {len(cift)}")

# Ornekler
print()
print("5 harfli ornekler:", ", ".join(sorted(five)[:25]))
print()
print("Birlesik ornekler:", "; ".join(compound[:12]))