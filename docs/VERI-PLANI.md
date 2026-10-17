# Veri Planı — 76.190 Giriş (tam ölçek)

## Araştırmanın en önemli bulgusu — VE İLK ÖLÇÜMÜNÜN YANLIŞLIĞI

Bu bölüm daha önce şunu yazıyordu:

> "76.190 giriş, 76.190 kelime demek değil… Sonda çekim eki bulunan 24.988
> (%41)… gerçek madde sayısı ~45.000 lemma."

**Bu ölçüm yanlıştı ve kendi üretimimizle çürütüldü.** Kayan not:

Yanlış ölçüm, ek benzeyen SONUÇLARA bakıyordu ve "çekimli biçim" diye
sayıyordu. Doğrulama (`tools/build_morphology.py`) şunu gösterdi:

```
"kitaplar"      -> listede YOK
"gözlerini"     -> listede YOK
"evler"         -> listede YOK
"çocuklar"      -> listede YOK
"insanların"    -> listede YOK
```

TDK imla kılavuzu listesi çekimli biçimleri **içermiyor.** İçerdiği şey
temel biçimler ve yazımı karıştırılan özel sözcükler.

Gerçekten çekimli olan ayrıştırma denemesi ise şu çıktıyı üretti:

```
"abide"  -> "ab"  + "de"      <- sahte soyma
"abiye"  -> "ab"  + "iye"     <- sahte soyma
"abosa"  -> "ab"  + "sa"      <- sahte soyma
```

Yani "%41 çekimli biçim" oranı, aslında **kaba ek kırpmanın yanlış
pozitif oranıydı.** 518 hatalı ayrıştırma ölçüldü; hepsi bu yüzden. Bu
sayıdan "45.000 lemma" sonucu çıkarılmıştı; o sonuç da düşüyor.

### Ölçülen gerçekler

| Ölçüm | Değer |
|---|---|
| Ham giriş | 61.190 |
| Tek kelime girişi | 61.190 |
| Birleşik sözcük (boşluklu) | 15.000 |
| **Sözlük maddesi (kök + özel ad ayrımından sonra)** | **59.592** |
| Büyük harfle gelen özel ad (otomatik elendi) | 875 |
| Ek envanteri (ağırlıklı) | 152 |

**Sonuç değişti ve aslında İYİLEŞTİ:** Bu zaten bir sözlük maddeleri
listesi. Kırk adet birleştirme yapmaya gerek yok; liste lemma'nın kendisi.
Mimari değişmedi (katmanlı derinlik, paketleme, SQLite) ama gerekçesi artık
"birleştirme" değil, **"her maddeye tanım yazmanın"** bedeli.

---

## Morfoloji: Zemberek yerine kendi kök bulucumuz

Plan Zemberek'i ön koşul sayıyordu. Ölçüp denedik, **kullanılamıyor**:

| Yol | Sonuç |
|---|---|
| `ahmetaa/zemberek-nlp` | GitHub release'i yok, Maven'de yok, derlenemiyor |
| Google `turkish-morphology` (pip) | Kuruldu ama `pywrapfst` (OpenFST) Windows'ta derlenmiş çarkı yok; Python 3.14'te çalışmıyor |

Bunun yerine **bağımlılıksız** bir kök bulucu yazıldı
(`tools/build_morphology.py`, Apache/GPL yok, kendi kodu):

* 152 ek, ünlü uyum varyantları açıkça yazılmış (hesaplanmıyor — hesap
  hataya açık)
* Ardışık ek zinciri: `evlerindekilerin` = `ev` + `ler` + `deki` + `ler` + `in`
* Ses onarımı yalnızca **yüzey → gövde** yönünde: `kitab`→`kitap`, `ağac`→`ağaç`
* Çözüm bulunmuyorsa sözcük yine de madde olarak alınır, güven puanı düşer

**Doğrulama: 20 elle hazırlanmış vakanın 20'si doğru, 17 kelimede sıfır yanlış
pozitif, en kötü girişte 0,2 ms.** Bu vakalar betiğin içinde kalıcı bir test
olarak durur.

### Sıralama kuralı (üçü de şart)

1. **En yüksek ek güveni.** Yanlış ayrıştırma genelde bir ekin *içinden*
   kesilir: `masalar` → `masa`+`lar` (1.0) | `masal`+`ar` (0.9).
2. **Eşitse en az ek.** `kitaplarımızdan` = `kitap`+`larımızdan` (1 ek),
   değil `kitapları`+`mız`+`dan` (2 ek).
3. **O da eşitse en uzun gövde.** `gözlüğünü` = `gözlük`+`ünü`,
   değil `göz`+`lüğünü`.

> **Raporlanan puan ≠ sıralama ölçütü.** Puan, ses onarımı cezasını da
> içerir (×0.85) ve belirsizliği bildirir. Sıralama yalnızca ek güvenine
> bakar. `gözlük`e giderken `ğ`→`k` onarımı uygulanır; bu bir tahmin değil,
> Türkçenin öngörülebilir bir ünsüz olayı — doğru gövde, yanlış sebeple
> elendiği için geri kalıyordu.

Morfolojinin girdi olarak değil **sorgunun parçası** olarak çalıştığına
karar verildi: kullanıcı "kitaplarımızdan" yazar → kök bulunur → "kitap"
gösterilir. Cihazda analiz yapılır, çevrimdışıdır.

---

## Katmanlı derinlik: 76.190'a nasıl erişilir

Her girişe elle tam tanım yazmak yüz binlerce saat sürer ve gerçekçi değil.
Ama 76.190'a yaklaşmanın **dürüst** bir yolu var:

| Katman | Adet | İçerik | Kaynak |
|---|---|---|---|
| **1 — Elle yazılmış** | ~2.500 | 2–3 anlam, örnek cümle, morfoloji, ilişkiler, doğrulanmış köken | Bu proje, insan elemesi |
| **2 — Üretilmiş + doğrulanmış** | ~15.000 | 1–2 anlam, kısa örnek, köken dönemi | AI üretimi + örneklemeli insan kontrolü |
| **3 — Yüzey kaydı** | ~40.000 | kelime + köken dönemi + tek cümlelik tanım | Morfolojik çözümleme + kural tabanlı üretim |
| | **~57.500 lemma** | | |

### Bu katmanlı yapı neden dürüst

Uygulamada **zaten var olan güven puanı mekanizması** tam olarak bunun için
tasarlandı. Katman 3 kelimeler düşük güvenle işaretlenir ve detay ekranında
"DOĞRULANMADI" rozeti taşır.

**Uygulama hiçbir zaman tamamlanmamış bir içeriği tamamlanmış gibi göstermez.**
Yüz binlerce kelimenin %40'ının sığ tanımı olması, ama dürüstçe etiketlenmiş
olması — 10 bin kelimenin sahte dolgu olmasından iyidir.

---

## Mimari zorunlulukları (tam ölçek)

76.190'a çıkarken üç şey **şimdi** değişmeli. Sonra pahalıya mal olur:

### 1. SQLite zorunlu hâle geliyor

76.190 girişi JSON varlığı olarak ~200–300 MB. Flutter asset olarak
dağıtılamaz.

- Veri `.db` dosyası olarak indirilir (bugün 0,3 MB).
- Uygulama açılışta okunur, kullanıcı verisi ayrı dosyada kalır.
- **Sürüm + delta güncelleme** şart: her sürümde 200 MB indirme kullanıcıyı
  kaçırır, sadece değişen satırlar gönderilir.

### 2. Bellek içi arama yetmez

Şu an `FuzzySearch` Dart belleğinde çalışıyor. 76.190 yüzey + 45.000 lemma
üzerinde silme-komşuluğu indeksi ~700.000 girdi demek — mobil RAM'de sürdürülemez.

| Katman | Bugün | 76.190'da |
|---|---|---|
| Tam metin | Bellek içi | **SQLite FTS5** |
| Aday üretimi | Bellek içi silme indeksi | **SQLite'da trigram tablosu** |
| Sıralama | Damerau-Levenshtein | Aynı — ama aday sayısı ~20'ye düşer |

### 3. Sözlük paketleri — APK şişmesin diye

Uygulama tek pakette 76.190 kelime taşımaz. Kullanıcı ihtiyacına göre indirir:

| Paket | İçerik | Boyut (tahmini) |
|---|---|---|
| **Günlük** | ~5.000 en sık kelime, tam tanım | ~8 MB |
| **Akademik** | ~45.000 lemma, çekimli biçimler | ~60 MB |
| **Tam** | 76.190 giriş | ~90 MB |

Aynı zamanda Wordle cevap havuzu buradan gelir — oyun kelimeleri ayrı bir
veri seti olarak kalır (tanım taşımaz).

---

## Kök bulucu nasıl bağlanır

Mobil cihazda Java kütüphanesi çalıştırılmaz — ama artık gerek de yok.
Doğru yerleşim:

1. **Üretim tarafında** (`tools/build_morphology.py`) TDK listesinden
   `lemmas`, `proper_nouns`, `suffixes` üretilir -> `data/morphology.json`.
2. Bu dosya uygulamaya varlık olarak girer.
3. **Cihazda Dart kök bulucusu** kullanıcının yazdığı sözcüğü madde
   listesine karşı çözer: "kitaplarımızdan" -> kitap + larımızdan -> **kitap**.

Üçüncü adım henüz yazılmadı; ilk iki bitti. İkisi de cihazda **hiçbir ağ
çağrısı yapmadan** çalışır. Doğruluk ölçütü: 20 vakanın 20'si, 17 kelimede
sıfır yanlış pozitif.

Aynı ilke SQLite için de geçerli: veri hattı masaüstünde bir kez çalışır,
uygulama hazır veriyi açar. "Hesaplama masaüstünde bir kez yapılır,
uygulama çevrimdışı okur."

---

## Yol haritası

### Aşama 1 — Ölçeğin temeli (veri yazmadan ÖNCE)

Sıralama burada kasıtlıdır: önce havuz, sonra su.

- [x] **SQLite'a geçiş** — uygulama `dict.db` okuyor (JSON değil); testler de AYNI yoldan geçiyor (`sqflite_common_ffi`)
- [ ] Arama FTS5/SQL'e taşınır — bellekteki FuzzySearch 59.592 madde ölçeğinde yetersiz
- [ ] **Delta güncelleme altyapısı** — sürüm tabloları, patch uygulama
- [ ] **Paket sistemi** — sözlük paketlerinin indirilmesi/yönetimi
- [x] **Kök bulucu boru hattı** — `tools/build_morphology.py` -> `data/morphology.json` (lemmalar + ek envanteri)
- [ ] Cihazda kök bulucu (Dart) — kullanıcı girdisi için lemma'ya ulaşma

### Aşama 2 — Elle yazılan çekirdek (Katman 1, ~2.500)

Kullanıcının ilk gördüğü içerik. Tam derinlik, doğrulanmış köken.

- [ ] Çekirdek sıklık (~600)
- [ ] Sınav + yazım (~500)
- [ ] Öz Türkçe ↔ alıntı çiftleri (~900)
- [ ] Köken grupları (~500)

### Aşama 3 — Ölçekli üretim (Katman 2 ve 3)

Elle yazılan çekirdek model olduktan sonra:

- [ ] Katman 2 üretim hattı (~15.000) — AI + örneklemeli insan kontrolü
- [ ] Katman 3 çözümleme (~40.000) — morfolojik bağlantı + kısa tanım
- [ ] Güven puanlarına göre arayüzde görünür işaretleme

### Aşama 4 — Oyuna dönüş

- [ ] Wordle — cevap havuzu Katman 3'ten beslenir, artık yeterli
- [ ] Öz Türkçe oyunu — 450 çift, tekrarlanabilir

---

## Her partiyi nasıl doğrulayacağız

Değişmeyen kurallar:

1. **Güven puanı her kökende.** Emin olmadığımızda düşük puan.
2. **Alıntı yok.** `example_author` yalnızca doğrulanabilir kaynak için dolar.
3. **Her parti `build_dict.py` ile doğrulanır:** anlamsız kelime, tekrar,
   hatalı Türkçe küçük harf, boş FTS indeksi, uydurma alıntı.
4. **Her parti ekranda görülür.** Test geçmek yetmez.
5. **Özel adaylar elenir** — kaynak liste "Adana", "Afgan" gibi özel adlar
   içeriyor.

---

## Dürüst iş yükü tahmini

Bu plan 76.190'a giden yol haritasıdır. Bugünün gerçekçi hedefi:

| Aşama | Kapsam | Durum |
|---|---|---|
| Tamamlanan | 139 kelime, 2 yayın | ✓ |
| **El yazımı çekirdek** | ~2.500 | yazılacak, ~12 parti |
| Ölçekli üretim | ~15.000 | Katman 1 modeli olmadan başlanmaz |
| Tam kapsam | ~57.500 lemma | Katman 2–3 altyapısı gerektirir |

**Bugünün sıradaki tek iş: SQLite tamamlandı, kök bulucu tamamlandı — sırada veri partileri.** Çünkü 2.500 kelimeyi yazmak
kolay — ama 76.190'a giden yolun taşıyıcısı o. Şimdi kurmazsak, veri partileri
yazarken sonra taşınmak zorunda kalır ve her parti bir daha yazılır.

> Kullanıcının "part part koyarız" sezgisi bu yüzden doğru: önce iskelet,
> sonra su. Ama "iskelet" burada kelime değil, **taşıyıcı**.