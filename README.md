# Akıllı Türkçe Sözlük ve Dil Asistanı

Kelime anlamlarına bakan statik bir sözlük değil; kelimelerin etimolojik kökenini,
dil bilgisi kurallarını, edebi alntılarını ve telaffuz detaylarını keşfettiğimiz
bir Türkçe dil ekosistemi platformu.

**Durum:** Faz 0 tamamlandı (veri hattı + arama motoru + arayüz iskeleti).
**Faz 1** (çekirdek sözlük ekranları) sırada.

## Kurulum

### Veritabanını üret

`mobile/assets/dict.db` bu komutla yeniden üretilir:

```bash
python tools/build_dict.py
```

Betik yalnızca Python 3.10+ ve standart kütüphane ister. Çıktıyı
konsola yazar ve bütünlük denetimi yapar: anlamsız kelime, hatalı Türkçe
küçük harf çevrimi, tekrarlı kelime, boş FTS indeksi ve **uydurma alıntı**
denetimi bu aşamada yakalanır.

### Uygulamayı çalıştır

```bash
cd mobile
flutter pub get
flutter run
```

### Testleri çalıştır

```bash
cd mobile
flutter test
```

`test/search_test.dart` süs değil; Türkçe arama motorunun sessizce
bozulmasını yakalar. `I → ı` ve `İ → i` dönüşümleri hem Dart'ta hem
Python'da varsayılan olarak yanlıştır — bu yüzden açıkça yazıldı ve test edildi.

## Mevcut kapsam

| Alan | Durum |
|---|---|
| Veri şeması | ✅ `data/schema.sql` |
| 136 kelimelik tad verisi | ✅ 270 anlam, 313 ilişki, 157 morfoloji |
| Veri üretim hattı | ✅ `tools/build_dict.py` |
| Türkçe normalizasyon | ✅ Dart + Python, testli |
| Damerau-Levenshtein arama | ✅ testli |
| Ana ekran | ✅ |
| Arama + "bunu mu demek istediniz" | ✅ |
| Kelime detay ekranı | ✅ |
| İlişki ağı görselleştirmesi | ✅ |
| Kelime detay ekranı → SQLite okuması | ⏳ Faz 1 sonu |
| TTS seslendirme | ⏳ cihazda doğrulanacak |
| YKS/KPSS/ALES/YDS modu | ⏳ Faz 5 |

**Veri önce, kod sonra.** Sözlük uygulamasının kalitesi verisinin kalitesidir.
Arama, ekranlar, oyunlar ve sınav modları hepsi verinin şekline göre kurulur;
veri hattı oturmadan yapılan her ekran sonradan yeniden yazılır.

**Telife sıfır yaklaşım.** TDK sözlük metinleri telif hakkına tabidir ve
kopyalanmaz. Tanımlar sıfırdan, yalnızca *yazım ve tanım kuralları* referans
alınarak üretilir. Kurallar kimseye ait değildir; özgün içeriktir.

**Offline-first.** Uygulamanın büyük kısmı LLM'e ihtiyaç duymadan çalışır.
API anahtarı mobil uygulamada bulunmaz; yalnızca FastAPI proxy üzerinden geçer.

## Teknoloji

| Katman | Seçim |
|---|---|
| Mobil ön yüz | Flutter (iOS + Android, tek kod tabanı) |
| Backend / AI proxy | FastAPI + PostgreSQL |
| Yerel veri | SQLite (`dict.db` salt okunur + `user.db` yazılabilir) |
| Arama | FTS5 + Damerau-Levenshtein + trigram |
| Morfoloji | Zemberek (çevrimdışı önceden hesaplanır) |
| OCR | ML Kit, cihaz üstü |

## Modüller

1. Akıllı arama (bulanık arama, kök/ek ayırıcı, sesli arama)
2. Kelime detay ekranı (anlam katmanları, telaffuz, ilişki grafiği)
3. AI asistan (tersi sözlük, stil düzeltici, ton analizi, edebi chatbot'lar)
4. Kamera OCR ve telaffuz koçu
5. Oyunlar (günlük bulmaca, eş anlamlı düellosu, öz Türkçe testi)
6. Sınav modu ve aralıklı tekrar (YKS/KPSS/ALES/YDS, SM-2)
7. Kişiselleştirme, widget'lar, topluluk katkısı

## Dokümantasyon

- [Proje dokümanı](docs/PROJE-DOKUMANI.md) — vizyon, modüller, şema
- [Uygulama planı](docs/UYGULAMA-PLANI.md) — fazlar, mimari, riskler

## Lisans

MIT — bkz. [LICENSE](LICENSE).

Sözlük verisinin telif durumu ayrıca ele alınacak: tanımlar bu repo tarafından
sıfırdan üretiliyor, TDK metinleri kopyalanmıyor. Kullanılacak dış veri
kaynaklarının (Zemberek, Wiktionary vb.) lisansları veri hattında kayıt altına
alınacak.