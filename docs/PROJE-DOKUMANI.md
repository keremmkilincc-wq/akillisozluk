# Akıllı Türkçe Sözlük ve Dil Asistanı — Proje Dokümanı

## 1. Proje Vizyonu ve Genel Bakış

Bu proje; geleneksel sözlük anlayışını modern mobil ve web teknolojileri, yapay zeka altyapısı ve oyunlaştırılmış öğrenme teknikleriyle birleştiren kapsamlı bir **"Türkçe Dil Ekosistemi"** platformudur.

Temel amaç, kullanıcıların sadece kelime anlamlarına baktığı statik bir veri tabanı sunmak değil; kelimelerin etimolojik kökenlerini, dil bilgisi kurallarını, edebi alntıları, günlük kullanım tonlarını ve telaffuz detaylarını interaktif bir deneyimle keşfetmelerini sağlamaktır.

---

## 2. Temel ve İleri Seviye Uygulama Modülleri

### [MODÜL 1: Akıllı Arama ve Bilgi Seçim Mimarisi]

- **Esnek Arama (Fuzzy Search & Levenshtein Distance):**
  Kullanıcı kelimeyi yanlış yazsa dahi (örneğin "şöför" yerine "şoför", "yalnış" yerine "yanlış", "kirbit" yerine "kibrit") algoritma kullanıcının ne demek istediğini yüksek doğrulukla tahmin eder ve öneri sunar.
- **Kök ve Ek Ayırıcı Analizör:**
  Çekim veya yapım eki almış kelimeler (örneğin "kitaplarımızdan", "gözlemciler") aratıldığında, uygulama kelimenin kökünü otomatik tespit eder ve hem eklerin işlevini açıklar hem de ana kök sayfasına yönlendirir.
- **Sesli Arama ve Doğal Dil İşleme:**
  Kullanıcı mikrofona bir cümle söylediğinde, cümle içerisindeki kilit kelimeler ayrıştırılarak doğrudan sözlük arama dizinine aktarılır.

### [MODÜL 2: Zenginleştirilmiş Kelime Detay Ekranı]

- **Kelime Kimliği:** Kelimenin türü (isim, fiil, sıfat, zarf), kökeni (Arapça, Farsça, Fransızca, Öz Türkçe vb.), Türkçeye girdiği dönem ve fonetik okunuş simgeleri.
- **Sesli Telaffuz ve Tonalite:** Kelimenin stüdyo kalitesinde doğru Türkçe telaffuz kaydı. Ses hızını ayarlama (0.5x, 1.0x, 1.5x) seçeneği.
- **Anlam Katmanları ve Örnek Cümleler:** TDK onaylı resmi tanımlar, mecaz anlamlar, terim anlamları ve argodaki karşılıkları. Her anlam için hem klasik edebiyattan (Reşat Nuri, Sabahattin Ali, Peyami Safa vb.) hem de modern günlük dilden örnek cümleler.
- **İlişkisel Ağ Şeması (Word Mind-Map):** Eş anlamlılar (Eşsesli), Zıt Anlamlılar, Akraba Kelimeler, İlgili Deyimler ve Atasözleri interaktif bir grafik ağ üzerinde görselleştirilir.

### [MODÜL 3: Yapay Zeka ve Dil Asistanı (AI Core)]

- **"Tersi Sözlük" (Reverse Dictionary):** Kullanıcı bir kelimenin adını hatırlayamadığında tanımı veya durumu yazar (Örn: *"Bir şeyin tam gerçekleşeceği sırada vazgeçme durumu"*). AI engine bu tanıma en uygun kelimeleri (Örn: *"Tereddüt"*, *"Direkten dönmek"*) dereceye göre listeler.
- **Akıllı Metin Düzeltici (Grammar & Style Checker):** Kullanıcı uzun bir paragraf girdiğinde yapay zeka yazım hatalarını, noktalama yanlışlarını ve anlatım bozukluklarını tespit eder. Metni "Daha Resmi", "Daha Edebi", "Daha Yalın" gibi farklı üslup alternatiflerine dönüştürür.
- **Duygu ve Ton Analizi:** Girilen kelime veya cümlenin taşıdığı psikolojik ve sosyolojik ton analiz edilir (Olumlu, Olumsuz, Nötr, Resmi, Şakacı, Saldırgan, Eleştirel).
- **Edebi Karakter Chatbot'ları:** Kullanıcılar Türk edebiyatının usta isimlerinin tarzında eğitilmiş AI botları ile sohbet edebilir, onlara kelimelerin edebi derinliğini sorabilir.

### [MODÜL 4: Multimedya ve Kamera İşlevleri]

- **Kamera ile Anında Kelime Tarama (OCR Tarayıcı):** Kitap, gazete veya dergi okurken bilinmeyen bir kelimenin üzerine telefon kamerası tutulduğunda, uygulama ekranda canlı olarak kelimenin tanımını ve okunuşunu açılır pencerede gösterir.
- **Diksiyon ve Telaffuz Koçu:** Kullanıcı kelimeyi mikrofona okur. Yapay zeka ses frekansını ve vurguları analiz ederek: *"Telaffuz doğruluk puanı %88. 'â' şapkalı a sesini biraz daha uzatmalısınız"* şeklinde sesli ve görsel geri bildirim verir.

### [MODÜL 5: Oyunlaştırma ve Bilgi Yarışmaları]

- **Günlük Kelime Bulmaca (Wordle Uyarlaması):** Her gün yenilenen 5 harfli Türkçe kelime bulmaca.
- **Dinamik Çapraz Bulmaca:** Kullanıcının kaydettiği veya zorlandığı kelimelerden otomatik üretilen bulmacalar.
- **Zamana Karşı Eş Anlamlı Düellosu:** 60 saniye içinde ekrana gelen kelimelerin en doğru eş anlamlılarını seçme ve genel sıralama panosunda (Leaderboard) yükselme.
- **"Hangi Kelime Öz Türkçe?" Oyunu:** Verilen iki seçenek arasından hangisinin Türkçe kökenli olduğunu tahmin etme.
- **İki Kişilik Online Sözlük Yarışması:** Rastgele bir rakiple veya arkadaşla eşleşerek kelime bilgisi, yazım kuralları ve etimoloji sorularını yanıtlama.

### [MODÜL 6: Akademik ve Sınav Hazırlık Modu]

- **YKS, KPSS, ALES, YDS Özel Modları:** Sınavlarda en çok çıkan edebi terimler, paragraf sorularında sıkça geçen soyut kelimeler, yazımı karıştırılan sözcükler ve noktalama kuralları için özelleştirilmiş çalışma setleri.
- **Aralıklı Tekrar Sistemi (Spaced Repetition / Leitner Flashcards):** Kullanıcının öğrenmekte zorlandığı kelimeleri algoritma tespit eder ve belirli gün aralıklarıyla (1. gün, 3. gün, 7. gün, 30. gün) tekrar hatırlatarak kalıcı hafızaya aktarılmasını sağlar.

### [MODÜL 7: Kişiselleştirme ve Sosyal Özellikler]

- **Özel Liste Oluşturucu:** "Şiirlerimde Kullanacağım Kelimeler", "İş Dili Terimleri", "Eski Türkçe Favorilerim" gibi özel kategorili listeler oluşturma ve bunları PDF/Excel olarak dışa aktarma.
- **Arka Plan Sesli Öğrenme (Podcast / Uyku Modu):** Seçilen kelime listelerini ve tanımlarını, arkada rahatlatıcı bir ortam müziği eşliğinde sesli olarak okuyan arka plan oynatıcısı.
- **Widget ve Kilit Ekranı Desteği:** Masaüstü ve kilit ekranı için her saat başı değişen "Günün Kelimesi", "Yazımı Karıştırılan Kelime" ve "Günün Deyimi" widget'ları.
- **Topluluk Katkısı ve Argo Sözlüğü:** Kullanıcıların kelimeler için günlük hayattan sokak ağzı, yeni nesil internet argosu ve bölgesel kullanım örnekleri ekleyebilmesi (İçerikler AI moderasyon ve editör onayından geçtikten sonra yayınlanır).

---

## 3. Teknik Mimari ve Veritabanı Tasarımı

### [Veritabanı Veri Yapısı (Örnek Şema)]

Uygulama %100 Offline çalışabilmesi için SQLite veya Room/CoreData üzerinde şu ilişki yapısını barındırır:

**Table: Words**

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | INTEGER | Primary Key |
| `word` | VARCHAR(255) | Index |
| `normalized_word` | VARCHAR(255) | Arama kolaylığı için şapkasız/küçük harf |
| `origin` | VARCHAR(100) | Arapça, Farsça, Türkçe vb. |
| `pronunciation_url` | VARCHAR(500) | |
| `usage_frequency` | FLOAT | Kelimenin günlük dilde kullanım sıklığı |
| `is_pure_turkish` | BOOLEAN | |

**Table: Meanings**

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | INTEGER | Primary Key |
| `word_id` | INTEGER | Foreign Key → Words.id |
| `meaning_order` | INTEGER | |
| `word_type` | VARCHAR(50) | İsim, Sıfat, Fiil vb. |
| `definition` | TEXT | |
| `example_sentence` | TEXT | |
| `author` | VARCHAR(150) | |

**Table: Relations**

| Alan | Tip | Açıklama |
|---|---|---|
| `id` | INTEGER | Primary Key |
| `word_id` | INTEGER | Foreign Key |
| `related_word_id` | INTEGER | Foreign Key |
| `relation_type` | ENUM | `synonym`, `antonym`, `idiom`, `derivative` |

### [Teknoloji Önerileri]

- **Mobil Ön Yüz (Frontend):** Flutter veya React Native (Tek kod tabanıyla hem iOS hem Android desteği).
- **Arka Plan (Backend / AI API):** Python (FastAPI / Django) — Doğal dil işleme (NLP) ve yapay zeka entegrasyonları için en ideal yapı.
- **Veritabanı:** Yerel için SQLite / Room, Sunucu senkronizasyonu için PostgreSQL.
- **AI / OCR Entegrasyonu:** OpenAI GPT-4o API (metin analizi için), Google Cloud Vision / Apple VisionKit (kamera OCR için).

---

## 4. Ekran Akışı ve Kullanıcı Deneyimi (UX/UI)

1. **Ana Ekran (Dashboard):**
   - En üstte arama çubuğu (Mikrofon ve Kamera ikonları ile).
   - "Günün Kelimesi" kartı (görsel ve ses oynatma butonuyla).
   - Hızlı Erişim Butonları: `[Kelime Oyunları]`, `[Sınav Modu]`, `[Listelerim]`, `[AI Asistan]`.
   - "Tarihte Bugün Okunanlar" veya "Trend Kelimeler" akışı.
2. **Arama Sonuç Ekranı:**
   - Anında sonuç veren dikey liste.
   - Yazım hatası durumunda "Bunu mu demek istediniz?" uyarısı.
3. **Kelime Detay Sayfası:**
   1. Header: Kelime adı, köken etiketi, ses oynatıcı.
   2. Anlamlar ve Örnek Cümleler kartı.
   3. Etimoloji ve Zaman Çizelgesi.
   4. Görsel Ağ Şeması (tıklanabilir ilişkili kelimeler).
   5. Diksiyon Koçu Butonu ("Nasıl Okunur / Sen Oku").
   6. Kullanıcı Notları ve Listeye Ekleme Alanı.

---

## 5. Gelecek Geliştirme ve Genişleme Stratejisi

- **Osmanlıca ve Göktürkçe Alfabesi Dönüştürücü:** Kelimelerin tarihsel alfabelerdeki yazılışlarını ve matbaa kalıplarını gösterme.
- **Lehçe ve Şive Sözlüğü:** Azerbaycan Türkçesi, Kazakça, Özbekçe gibi akraba Türk dillerindeki karşılıkları gösterme.
- **İşitme Engelliler İçin Türk İşaret Dili (TİD) Entegrasyonu:** Kelimelerin işaret dilindeki hareketlerini gösteren kısa video/animasyon desteği.