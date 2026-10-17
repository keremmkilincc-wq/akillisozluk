import io
import json
import sys
from pathlib import Path

"""Seed dosyalarini uretimden ONCE denetler.

NEDEN BU VAR: Bu projede veri JSON olarak ELLE yaziliyor. Iki kez tirnak
hatasi yapildi (tek tirnakla kapanis) ve ikisinde de build_dict.py hatayi
reddetti — dogru davranis, ama hatayi URETIM aninda, yazim aninda
degil yakaladik.

Kirpma denetimi:
  1. JSON ayristirilabiliyor mu
  2. phonetics METIN mi (liste degil) — liste olursa SQLite reddeder
  3. usage_frequency 0..1 araliginda mi
  4. confidence 0..1 araliginda mi
  5. meanings bos mu (yazilmamis madde icin bos olabilir ama seed'te olmamali)
  6. tekrarli kelime var mi (ayni dosyada)
  7. tekrarli morfoloji yuzeyi, tekrarli iliski
  8. Kiril/Yunanca harf var mi

  8) EKLENDI: iki kez yapildi. Birinde 'emeк' icindeki Kirilca 'к'
  Turkce k ile ayni gorunuyor ama foldTurkish onu Turkce harf saymiyor,
  esanlamli sessizce HIC karsi lastirmiyordu. Ikincisinde parti 005'in
  aday listesine yazdigim 'tepе' icinde Kirilca 'е' vardi.
  Gozle bulunamayan bir hata — tarama ile bulunur.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path('data/seed')

# Kiril ve Yunanca alfabeleri. Turkce bunlari icermez.
YABANCI_HARF = re.compile(r'[\u0400-\u04FF\u0370-\u03FF]')

# Birlestirilen aksan isaretleri (U+0300..U+036F).
#
# DIKKAT: bu isaretler her yerde HATA degildir. "phonetics" alaninda IPA
# yazimi icin ZORUNLUDUR: "[d͡ynja]" dogru yazimdir, isaret olmadan
# "[dynja]" sesi bozar. Ilk denemede tum satirlari taradim ve dort dogru
# yazimi hata olarak gosterdi — kural cok genis yazilmisti.
#
# KURAL DARALTILDI: yalnizca word / root / surface alanlari duz Turkce
# yazim olmalidir; bunlar IPA icermez ve birlestirilmis isaret tasimaz.
#
# Bu parti 007'de nasil bulundu: bir morphology girdisine Dart'a ozgu
# bir ifade tasimistim ("shi̇ir".replace(...)) ve dosya JSON olarak
# ayristirilamaz oldu. Kiril taramasi YAKALAMAMISTI, cunku isaret Latin.
BIRLESTIRILEN_ISARET = re.compile(r'[\u0300-\u036F]')
DUZ_TURKCE_ALANLAR = ('word', 'root', 'surface')

HATA = 0

# Denetlenmeyen dosya denetimi.
#
# Bu denetim `words*.json` uzerinde gezinir — build_dict.py ile AYNI kalip.
# Kaliba uymayan bir dosya seed/ icinde durabilir: denetim onu GORMEZ, yani
# temiz sayilir, ama build de onu YUKLEMEZ.
#
# Bu turde boyle oldu: deney dosyasini `_deney_yilan.json` adiyla koydum.
# check_seed.py "tum seed dosyalari temiz" dedi — ve bu DOGRUYDU, cunku
# dosyayi hic okumamisti. build_dict.py 580 kelimeyle dondu, deney kelimesi
# hic girmedi. Denetim yesil, teslimat degismemis.
#
# Asagidaki blok, yemek klasorunde yalnizca yemek OLMAYAN dosya varsa
# uretime girmeyi engeller.
# Kalip build_dict.py ile ayni tutulmali; ayrilirsa ayni sessiz hat geri gelir.
# build_dict.py'in YUKLEMEDIGI ama seed/ icinde yasamasi gereken dosyalar.
#
# wordle_words.json: Wordle havuzunun kaynagi. Parti degil; tools/build_wordle.py
# tarafindan okunur. build_dict.py'in yuklememesi DOGRU, bir hata degil.
YEMEK_OLMAYAN_IZINLI = {'wordle_words.json'}

YENIYE_GIRMEYEN = [
    _f.name
    for _f in sorted(ROOT.glob('*.json'))
    if not _f.name.startswith('words') and _f.name not in YEMEK_OLMAYAN_IZINLI
]

if YENIYE_GIRMEYEN:
    print("UYARI: seed/ icinde taninmayan dosyalar var.")
    print("       Bunlar denetlenmez ve uretime girmez — ama yanlislikla")
    print("       parti sandiginiz bir dosya olabilir:")
    for _ad in YENIYE_GIRMEYEN:
        print(f"         - {_ad}")
    print("       Adi 'words' ile baslat ya da dosyayi sil.")
    HATA += 1

for f in sorted(ROOT.glob('words*.json')):
    print(f"\n=== {f.name} ===")
    try:
        d = json.loads(f.read_text(encoding='utf-8'))
    except json.JSONDecodeError as e:
        print(f"  HATA JSON ayristirilamadi: {e}")
        HATA += 1
        continue

    kelimeler = d.get('words', [])
    print(f"  kelime : {len(kelimeler)}")

    gorsulen = set()

    # Dosya genelinde Kiril/Yunanca taramasi (meta alani dahil).
    # Birlestirilmis isaret taramasi ASAGIDA alan bazinda yapilir; IPA
    # geregi burada yanlis pozitif uretirdi.
    for i, line in enumerate(f.read_text(encoding='utf-8').split('\n'), 1):
        if YABANCI_HARF.search(line):
            print(f"  HATA satir {i}: Kiril/Yunanca harf -> {line.strip()[:70]}")
            HATA += 1

    for w in kelimeler:
        ad = w.get('word', '<isimsiz>')

        if ad in gorsulen:
            print(f"  HATA tekrarli kelime: {ad}")
            HATA += 1
        gorsulen.add(ad)

        def duz_turkce_mi(deger, yer):
            """word / root / surface düz Türkçe yazım olmalı; IPA içermez."""
            if not isinstance(deger, str):
                return
            if BIRLESTIRILEN_ISARET.search(deger):
                print(f"  HATA {yer}: birlestirilmis isaret -> {deger!r}")
                globals()['HATA'] = globals()['HATA'] + 1

        duz_turkce_mi(ad, f"{ad}: word")

        ph = w.get('phonetics')
        if isinstance(ph, list):
            print(f"  HATA {ad}: phonetics LISTE olmamali, metin olmali -> {ph}")
            HATA += 1
        elif ph is not None and not isinstance(ph, str):
            print(f"  HATA {ad}: phonetics tipi {type(ph).__name__}")
            HATA += 1

        for alan, (lo, hi) in (
            ('usage_frequency', (0.0, 1.0)),
            ('confidence', (0.0, 1.0)),
        ):
            v = w.get(alan)
            if v is not None and not (lo <= v <= hi):
                print(f"  HATA {ad}: {alan} = {v}, {lo}..{hi} disinda")
                HATA += 1

        anlamlar = w.get('meanings', [])
        if not anlamlar:
            print(f"  UYARI {ad}: anlami yok (seed'te normaldegil)")
        for m in anlamlar:
            if not m.get('definition', '').strip():
                print(f"  HATA {ad}: bos tanim (anlam {m.get('order')})")
                HATA += 1
            c = m.get('confidence')
            if c is not None and not (0.0 <= c <= 1.0):
                print(f"  HATA {ad}: anlam guveni {c} aralik disinda")
                HATA += 1

        # Parti 003'te gozle bulunan iki bosluk: ayni morfoloji yuzeyi
        # ve ayni iliski iki kez yazilmisti. Kelime tekrari denetleniyordu,
        # bunlar denetlenmiyordu. Artik denetleniyor.
        yuzeyler = set()
        for m in w.get('morphology', []):
            y = m.get('surface', '<isimsiz>')
            duz_turkce_mi(y, f"{ad}: morphology.surface")
            duz_turkce_mi(m.get('root'), f"{ad}: morphology.root")
            if y in yuzeyler:
                print(f"  HATA {ad}: tekrarli morfoloji yuzeyi: {y}")
                HATA += 1
            yuzeyler.add(y)
            if not m.get('explanation', '').strip():
                print(f"  HATA {ad}: morfoloji aciklamasi yok: {y}")
                HATA += 1

        iliskiler = set()
        for r in w.get('relations', []):
            a = (r.get('word'), r.get('type'))
            if a in iliskiler:
                print(f"  HATA {ad}: tekrarli iliski: {a[0]} ({a[1]})")
                HATA += 1
            iliskiler.add(a)

print()
print("=" * 58)
if HATA:
    print(f"SONUC: {HATA} sorun. Uretime girilmemeli.")
    sys.exit(1)
print("SONUC: tum seed dosyalari temiz.")
sys.exit(0)