#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
76.190 giris gercekten o kadar kelime mi?

Bu analiz planin en onemli sorusunu yanitliyor: TDK listesi icindeki girislerin
kacesi BAĞIMSIZ SÖZCÜK (lemma), kacesi ÇEKIMLI BİÇİM?

Cunku "kitaplar", "kitabim", "kitapta" ayri sozcukler DEGILDIR; ayni kelimenin
bicimleridir. Morfolojik cozumleme (Zemberek) bunlari tek kokte toplar.

Farki bilmek, 76.190 kelime planini gercekci mi yoksa hayal mi yaptigimizi
gosterir.
"""

import io
import re
from collections import Counter

PATH = r"C:\Users\Kilinc\AppData\Local\Temp\opencode\tdk_words.txt"

words = [w.strip() for w in io.open(PATH, encoding="utf-8", errors="replace").read().splitlines() if w.strip()]
single = [w for w in words if " " not in w]

print(f"Tek kelime girisi: {len(single)}")
print()

# Turkce ekler — cokimler yerine cogu bicim buraya dusuyor
# Suffix'ler uzunluklarina gore islenir: en cok ekli olan en cok sayilir
SUFFIXES = [
    "lardan", "lerden", "larda", "lerde", "ların", "lerin",
    "ları", "leri", "ları", "ler",
    "ımız", "imiz", "unuz", "ünüz",
    "sının", "sinin", "sunuz", "sünüz",
    "makta", "mekte", "makta",
    "acaktı", "ecekti", "dı", "di", "du", "dü",
    "dan", "den", "tan", "ten",
    "da", "de", "ta", "te",
    "yı", "yi", "yu", "yü",
    "ın", "in", "un", "ün",
    "nın", "nin", "nun", "nün",
    "a", "e", "ı", "i", "u", "ü",
    "lı", "li", "lu", "lü",
    "sız", "siz", "suz", "süz",
    "çi", "ci", "cu", "cü",
]

# Sonda bir ek bulunanları say
ends_with_suffix = 0
suffix_counter = Counter()

for w in single:
    lw = w.lower()
    for s in SUFFIXES:
        if len(lw) - len(s) >= 4 and lw.endswith(s):
            ends_with_suffix += 1
            suffix_counter[s] += 1
            break

print(f"Sonda cokum eki bulunan giris : {ends_with_suffix}  (%{round(100*ends_with_suffix/len(single))})")
print()

# Kaba lemma tahmini: ayni koke dusen gruplari say
# Yontem: her kelimenin "govdesi"ni kestirip kumez al
def naive_stem(w):
    lw = w.lower()
    for s in sorted(SUFFIXES, key=len, reverse=True):
        if len(lw) - len(s) >= 4 and lw.endswith(s):
            return lw[:-len(s)]
    return lw

stems = Counter(naive_stem(w) for w in single)
print(f"Kaba govde sayisi (tahmini lemma) : {len(stems)}")
print()

print("En cok coguran ekler:")
for s, c in suffix_counter.most_common(15):
    print(f"  -{s:<8} {c:>6}")

print()
print("En cok tekrar eden govde gruplari (ornek):")
for st, c in stems.most_common(12):
    if c > 8:
        ornekler = [w for w in single if naive_stem(w) == st][:5]
        print(f"  {st:<12} x{c:<4} {', '.join(ornekler)}")

# Kac kelime icin baska bir kelime onek olarak mevcut?
print()
print()
kelime_set = set(single)
oneset = set(w.lower() for w in single)
bicim_hayali = sum(1 for w in single if naive_stem(w) in kelime_set and w.lower() not in kelime_set)
print(f"Govdesi listede AYRI bir kelime olan bicimler : {bicim_hayali}")
print(f"  yani bunlar ayri sozluk girdisi olmamali, kok sayfasina baglanmali")
print()
print(f"GERCEKCE ISLENECEK SOZLUK BOYUTU TAHMINI : {len(stems)} civari lemma")