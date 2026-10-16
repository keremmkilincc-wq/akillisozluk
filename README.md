# Akıllı Türkçe Sözlük ve Dil Asistanı

Kelime anlamlarına bakan statik bir sözlük değil; kelimelerin etimolojik kökenini,
dil bilgisi kurallarını, edebi alntılarını ve telaffuz detaylarını keşfettiğimiz
bir Türkçe dil ekosistemi platformu.

**Durum:** Plan aşaması. Kod henüz yazılmadı — önce veri üretim hattı kuruluyor.

## Temel ilkeler

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

Karar aşamasında. Veri kaynakları (Zemberek, Wiktionary vb.) için ayrı
değerlendirme notu eklenecek.