# Akıllı Türkçe Sözlük ve Dil Asistanı — Uygulama Planı

## Steps

- [ ] Faz 0 — Veri üretim hattı ve veri modeli (her şeyin temeli)
- [ ] Faz 1 — Çekirdek sözlük: Modül 1 + Modül 2
- [ ] Faz 2 — AI katmanı: Modül 3 (offline-first)
- [ ] Faz 3 — Kamera/OCR ve telaffuz: Modül 4
- [ ] Faz 4 — Oyunlar: Modül 5
- [ ] Faz 5 — Sınav modu ve aralıklı tekrar: Modül 6
- [ ] Faz 6 — Kişiselleştirme, widget, topluluk: Modül 7
- [ ] Faz 7 — Backend, senkronizasyon, yayın

---

## Alınan Kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Platform | **Flutter** (iOS + Android, tek kod tabanı) | Kamera OCR, TTS, widget desteği en olgun. React Native da olurdu; kararı geri çevirmek kolay, ileride anlatırım neden. |
| Veri | **Sıfırdan üretim**, TDK yazım/tanım kurallarına uygun | Telif riski sıfır. Ne TDK metni kopyalanır ne de "TDK'ya benzer yaz" denen. |
| AI dağıtımı | **Offline-first** | Uygulamanın ~%80'i LLM'siz çalışır. API key uygulamaya gömülmez. |
| Backend | **FastAPI** | AI proxy, senkronizasyon, moderasyon, online oyun altyapısı. |
| Kapsam | Dokümandaki 7 modülün tamamı | Sırayla, fazlar halinde. |

**Temel ilke:** Kod sonra gelir, veri önce. Sözlük uygulamasının kalitesi verisinin kalitesidir; veri hattı oturmadan yapılan her ekran sonradan yeniden yazılır.

---

## Faz 0 — Veri Üretim Hattı

Kod yazmadan önce sözlüğü üretmek zorundayız. Çünkü arama, ekranlar, oyunlar, sınav modları — hepsi bu verinin şekline göre kurulur.

### Veri kaynağı stratejisi

1. **Kelime listesi** — Türkçe derlemelerden sık kullanım + edebî + argo katmanları. Ayrıntı: bir sözlükteki **kelime listesi** genelde telife tabi değildir; **tanım metinleri** tabidir. Yani kelimeleri toplamak sorun değil, açıklamaları asla kopyalamıyoruz.
2. **Tanım üretimi** — AI ile TDK üslubunda yazılır: tek cümle, madde başı, günlük dilde anlam. Her anlam için: `tanım` + `klasik edebî örnek cümle` + `modern günlük örnek cümle`.
   - ⚠️ TDK metinlerini modele girdi verip "buna benzer yaz" demek çıktının telifi yaklaştırır. Tanımlar **yalnızca dilbilgisel kural** referansıyla, kelime kelime sıfırdan yazılacak.
3. **Köken / etimoloji** — doğrulanabilir kaynaklardan (İslâm Ansiklopedisi, DTL, etimoloji sözlükleri — her birinin lisansı tek tek kontrol edilir).
4. **İlişkiler** — eş anlam, zıt anlam, akraba kelime, deyim, atasözü.
5. **Morfoloji** — **Zemberek** ile her kelimenin tam analizi: kök + ekler + çekim zinciri (`kitaplarımızdan` → `kitap + lar + imız + dan`). Bu masaüstünde **bir kez** hesaplanıp tabloya yazılır; uygulama çevrimdışı kullanır. Bu, Modül 1'in "Kök ve Ek Ayırıcı"nın motorudur.
6. **Güven skoru** — her alana 0–1 arası puan + kaynak etiketi. AI uydurursa puan düşer ve uygulama "doğrulanmadı" rozeti gösterir. Hallüsinasyon böylece bastırılabilir hale gelir.

### Faz 0'da şimdiden etiketlenmesi gerekenler

Sonradan eklenmesi pahalı olan alanlar **ilk günden** şemada durmalı:
- Sınav etiketleri (YKS / KPSS / ALES / YDS) — Modül 6
- `is_pure_turkish` + dil ailesi — Modül 5 oyunu
- Sıklık skoru — sıralama, "günün kelimesi" seçimi
- Yazım uyarısı tipi (`-e` / `-i` ekleri, "kitap/kitabe") — Modül 6'nın en değerli içeriği

### Ölçek

| Aşama | Kelime | Not |
|---|---|---|
| Tad testi | 100 | İç kaliteyi ölçmek için önce bu |
| MVP | 20.000 | Faz 1 için yeterli |
| Hedef | 100.000 | Tam kapsam |

Kelime başına ~5 anlam, ~10 örnek cümle, ~8 ilişki.

---

## Faz 1 — Çekirdek Sözlük (Modül 1 + Modül 2)

Uygulamanın omurgası. Bunlar bitmeden gerisi üstüne yazılabilir ama o zaman boşa gider.

### Veritabanı mimarisi

İki ayrı şema — bu ayrım önemli:

- **`dict.db`** — salt okunur, uygulamayla birlikte gelir. `Words`, `Meanings`, `Relations`, `Morphology`, `Idioms`, `Etymology`, tanım gömme vektörleri.
- **`user.db`** — yazılabilir. Listeler, notlar, aralıklı tekrar ilerlemesi, oyun skoru, favoriler.

Sözlük güncellemesi: açılışta sürüm kontrolü → gerekiyorsa indirilen `.db` dosyasını değiştir. 100k kelime vektörlerle ~100 MB'a çıkacağından **delta güncelleme** planlanmalı.

### Arama motoru (Modül 1)

- **Normalizasyon** — Türkçe'ye özel: Unicode NFD + diyakritik katlama (`ı/i`, `İ/i`, `ş/s`, `ğ/g`, `ç/c`, `ö/o`, `ü/u`). TDK'ya göre `i` ile `ı` ayrı harflerdir ama arama için katlanır, sonuçta doğru yazımla gösterilir.
- **Tam metin** — SQLite **FTS5**, kelime + tanım üzerinde, prefix sorguları.
- **Bulanık arama** — **Damerau-Levenshtein** (transpozisyon destekli). "yalnış → yanlış" ve "kirbit → kibrit" gibi hatalar düz transpozisyon/bir harf yer değişimi; standart Levenshtein bunları kaçırır. Sıralamada ek olarak Jaro-Winkler.
- **Aday üretimi** — 100k kelimeyi doğrudan taramak yerine trigram benzerliği ile aday toplanır, sonra Damerau ile sıralanır. "Bunu mu demek istediniz?" uyarısı buradan gelir.
- **Kök/ek ayırıcı** — `Morphology` tablosundan tam kelime → kök eşleşmesi; eki açıkla, kökün sayfasına yönlendir.

### Kelime detay ekranı (Modül 2)

Doküman 4.3'teki akış: header (kelime, köken etiketi, ses) → anlamlar + örnek cümleler → etimoloji ve zaman çizelgesi → ilişki grafiği → telaffuz koçu butonu → not ve listeye ekleme.

### İlişki grafiği

Force-directed düzen, pan/zoom, düğüm tıklayınca kelimeye git. Çizim `CustomPainter` + `vector_math` ile sıfırdan — hazır kütüphaneler bu ölçekte yeterince esnek değil.

### Ses

`flutter_tts` ile yerel Türkçe TTS (tr-TR), 0.5x / 1.0x / 1.5x. Dokümandaki "stüdyo kalitesinde kayıt" iddiası şimdilik gerçekçi değil — MVP'de TTS, ileride insan kaydı.

---

## Faz 2 — AI Katmanı (Modül 3) — Offline-First

Bu fazın mimarisi, uygulamayı LLM'e bağımlılıktan kurtarıyor. Üç katman:

### Katman A — LLM gerektirmez, %100 çevrimdışı

| Özellik | Yöntem |
|---|---|
| **Tersi Sözlük** | Her tanımın gömme vektörü veritabanında önceden hesaplanır. Kullanıcı cümlesi gömülür → en yakın tanımlar. 100k × 384 boyut (float16) ≈ 75 MB. Önce BM25 ile 100 aday, sonra kosinüs benzerliği ile sıralama — hızlı ve isabetli. |
| **Ton / duygu analizi** | Sözlük tabanlı (NSM, NÖS, PEF) + Türkçe duygu verisiyle eğitilmiş küçük sınıflandırıcı (ONNX, ~10 MB). |
| **Köken / etimoloji** | Doğrudan veritabanından. |

### Katman B — Hibrit: RAG + LLM

**Edebi karakter chatbot'ları** ve "bu kelime hakkında sor": önce kendi sözlük verimizden bağlam çekilir, sonra modele verilir. Model kendi bilgisinden konuşmaz — **bizim verimizle** konuşur. Bu, hem daha doğru hem daha inandırıcı ve halüsinasyonu yapısal olarak azaltır.

### Katman C — Tam LLM

**Metin düzeltici ve üslup dönüştürme** ("daha resmi / daha edebi / daha yalın"). Bu gerçekten LLM istiyor.

### Backend proxy (FastAPI) — zorunlu

- **API key sunucuda, uygulamada asla.** Mobil uygulama binary'si dağıtılabilir, içinden key çıkarılabilir. Bu kural tartışmasız.
- Kullanıcı başına kota, günlük limit, önbellekleme (aynı düzeltme iki kez hesaplanmasın), çıktı denetimi.
- Çevrimdışıyken LLM özellikleri "bağlantı yok" der; **uygulamanın geri kalanı çalışmaya devam eder**.

### Gizlilik

Kullanıcının yazdığı paragraf ve cümleler LLM'e gider. Bu açıkça belirtilmeli ve onaylanmalı; gizlilik politikası ve KVKK aydınlatması gerekir.

---

## Faz 3 — Kamera/OCR ve Telaffuz (Modül 4)

- **OCR** — `google_mlkit_text_recognition`, cihaz üzerinde, çevrimdışı, Türkçe destekli. Canlı kamera önizlemesi → metin satırları → kelime kutulama → sözlükle eşleştirme → tanım balonu.
- Asıl zorluk OCR değil, **sayfa satırlarını kelimelere ayırmak** ve bunları sözlükte bulmak.
- **Telaffuz koçu** — mikrofon kaydı → enerji/cepstral çıkarım → beklenen kayıtla karşılaştırma (DTW). Dürüst olalım: MVP'de "dinle ve tekrarla" + temel puanlama; %88 tarzı detaylı geri bildirim ileride geliştirilir.

---

## Faz 4 — Oyunlar (Modül 5)

- **Günlük kelime bulmaca** — gün başına tohumlanmış kelime seçimi, böylece herkes aynı kelimeyi alır ve cihaz çevrimdışıyken de tutarlı çalışır. Günlük seri takibi.
- **Eş anlamlı düellosu** — süreli mod tamamen offline.
- **"Hangi Kelime Öz Türkçe?"** — `is_pure_turkish` alanı Faz 0'dan hazır geliyor.
- **İki kişilik online** — ilk sürüm **local pass-and-play** (aynı cihazda sırayla). Gerçek eşleşme sunucu altyapısıyla Faz 7'de. Bunu baştan vaat edip sonra "yaklaşık çalışıyor" demektense net bir sınır koyuyorum.

---

## Faz 5 — Sınav Modu ve Aralıklı Tekrar (Modül 6)

- **SM-2 algoritması** (SuperMemo-2), günlük tekrar kuyruğu, zorluk katsayısı.
- YKS / KPSS / ALES / YDS havuzları — Faz 0'daki etiketler üzerinden filtrelenir.
- **Yazım kuralları motoru** — TDK'nın en değerli ve tamamen özgün içeriği. `kitap → kitabe`, `bilgi → bilgiye` gibi ek düşürme kuralları. Karıştırılan kelimeler listesi, bu modülün kalbi.
- **Bu fazın en yüksek getirili parçası** burası: hem özgün, hem gelire bağlanabilir, hem de AI gerektirmez.

---

## Faz 6 — Kişiselleştirme, Widget, Topluluk (Modül 7)

- Özel listeler → **PDF/Excel dışa aktarma**.
- **Widget'lar** — `home_widget`, saatlik rotasyon (Günün Kelimesi / Yazımı Karıştırılan / Günün Deyimi).
- **Arka plan sesli öğrenme** — listeleri sesli okuma, arka planda rahatlatıcı ortam sesi ile karıştırma.
- **Topluluk katkısı / argo sözlüğü** — en riskli modül, üç katmanlı koruma:
  1. AI ön eleme
  2. Editör onayı
  3. Kullanıcı içerik lisansı (katkılar **CC BY** olarak ilan edilir — sözleşmeye yazılmalı, aksi halde platform ilk yükleyenin malı olur)
  - Ek olarak: hakaret/kişisel veri filtreleri, şikâyet ve kaldırma akışı.

---

## Faz 7 — Backend, Senkronizasyon, Yayın

- FastAPI + PostgreSQL.
- Kullanıcı verisi senkronizasyonu: listeler, SRS ilerlemesi, favoriler, oyun skoru.
- Çevrimiçi düello + **leaderboard**.
- Kimlik doğrulama, KVKK uyumu, yedekleme.
- Uygulama mağazaları (Google Play / App Store), sözlük veri sürümleme stratejisi.

---

## Riskler

| Risk | Etki | Önlem |
|---|---|---|
| AI kaynaklı uydurma (uydurma etimoloji, yanlış köken) | Yüksek — itibar ve doğruluk | Güven skoru + doğrulanmamış rozeti + insan elemesi |
| Veri üretimi maliyeti ve süresi | Yüksek — en uzun faz | 100 kelimelik tad testiyle önce kaliteyi ölç, sonra toplu üret |
| TDK kurallarına uygunluk kayması | Orta | Yazım kuralları otomatik doğrulayan bir kontrol katmanı (Faz 0) |
| API maliyeti (özellikle stil dönüştürme) | Orta | Katman A/B ile LLM ihtiyacını minimuma indir, önbellek + kota |
| OCR'da Türkçe karakter hataları | Orta | Sözlükle eşleştirme + kullanıcıya düzeltme imkânı |
| Topluluk içeriğinde hukuki risk | Yüksek | Katkı lisansı + moderasyon + kaldırma akışı |
| Telefonda OCR/TTS performansı | Düşük | Cihaz üstü çalışmayı hedefle, sunucuya bağımlı olma |
| Kapsam kayması (7 modül) | Yüksek | Faz sınırlarına sadık kal, her fazı bitir |

---

## İlk Adım

Onayınızdan sonra başlayacak iş, kod değil şu:

**Faz 0'ın ilk parçası — veri tad testi.** 100 kelimelik bir örnek set üretip (tanım, örnek cümle, köken, ilişkiler, güven skoru, Zemberek analizi) kaliteyi ölçüyoruz. Bu örnek verinin kalitesi beğenilmezse, 100.000 kelime üretmenin anlamı yok. Yani önce küçük ve ölçülebilir olanı yapıyoruz.

Bu arada iki karar size bağlı:

1. **Flutter** önerimde kaldım — React Native tercih edersen mimari aynı, sadece katman değişir.
2. **MVP kelime sayısı** 20.000 mi olsun, yoksa daha küçük başlayıp (5.000) çekirdeği mi hızlandıralım?