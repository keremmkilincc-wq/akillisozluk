// ============================================================================
//  TÜRKÇE EŞANLAMLI KÖPRÜ — elle yazılmış
//
//  NEDEN VAR: tersi sözlük 26 soruluk ölçümde ilk sıra doğruluğunu
//  %31'de durduruyordu. Kalan hataların çoğu gövde kırpma ya da sıralama
//  hatası DEĞİL — kavramsal boşluk:
//
//      sorgu : "Karşıdakine zarar vermek için yapılan davranış"
//      suç   : "Kanunun cezalandırdığı davranış."
//      sorun : "Çözülmesi veya cevaplanması gereken güçlük, mesele."
//
//  "Davranış" ortak ama tek başına ayırt edici değil; "suç"u "sorun"dan
//  ayıran şey "kanun" ve "cezalandırma" — ki kullanıcı onu yazmamış.
//  Hiçbir ağırlıklandırma bunu kurtaramaz. Kelime eşleştirmenin taşıma
//  sınırı burada: kullanıcı tanıma YAKIN kelimeyi seçiyor, tanımlar da
//  genellikle farklı kelimelerle yazılmış oluyor.
//
//  İKİ YOL VAR:
//    1. Gömme vektörleri (Faz 2, planın yol haritasında) — genel çözüm,
//       ama model dosyası ve hesaplama gerektiriyor.
//    2. Buradaki gibi elle yazılmış eşanlamlı katmanı — dar çözüm, hemen
//       çalışır, ama YAZILMAK zorundadır ve kapsamı sınırlıdır.
//
//  1) seçilmedi: çevrimdışı/offline-first ilkesi bozulur ve 58 bin
//  kelimenin vektörü APK'ya sığmaz. 2) seçildi: bu projede zaten tanımlar
//  elle yazılıyor; eşanlamlılar da öyle yazılır.
//
//  KAPSAM: liste sınırlıdır. Kapsanmayan eşanlamlı çifti hâlâ kaçar.
//  Puanı gerçekten yükselttiği ölçülürse tutulur, "sözlük hazır" gibi
//  sunulmaz. Tanım yazarken büyütülür (bkz. docs/VERI-PLANI.md).
//
//  KURAL: anahtar sözcük = kullanıcının yazabileceği biçim; kalanlar
//  kavramın Türkçe yüzeyleri. Karşılıklı zıt olan çiftler buraya GİRMEZ —
//  zıtlık ayrı bir iş, burada sadece anlam köprüsü kuruluyor.
// ============================================================================

library;

/// Her grup: [0] anahtar, [1..] kavramın diğer yüzeyleri.
///
/// NEDEN HAM LİSTE, NEDEN HARİTA DEĞİL: anahtarlar burada GÖVDESİZ
/// yazılıdır ("inanmak"), ama tersi sözlük terimleri gövdeye kırpar
/// ("inan"). Eşleme gövde üzerinden yapıldığı için haritalama
/// ReverseDictionary içinde, kendi gövde kırpıcısıyla kurulmalıdır.
///
/// Bu sessiz hatayı ilk denemede yaptım: harita burada kurulmuştu ve
/// hiçbir zaman eşleşmiyordu. Ölçüm bunu ele verdi — ağırlık 0,15'ten
/// 0,80'e değiştirildiği hâlde sonuç BİREBİR AYNI kaldı (8/26, 13/26).
/// Gerçek bir eşanlamlı katmanı ağırlığa duyarlı olmak zorundadır;
/// duyarsızsa uygulanmıyordur.
const List<List<String>> turkishSynonymGroups = [
  // ---- soyut kavramlar ---------------------------------------------------
  ['umut', 'beklenti', 'hayal', 'inanç'],
  ['korku', 'ürperti', 'dehşet', 'tedirginlik'],
  ['şaşkınlık', 'şaşma', 'hayret', 'şaşırma'],
  ['merak', 'ilgi', 'istek', 'heves'],
  ['umutsuzluk', 'çaresizlik', 'bezginlik'],
  ['sevgi', 'aşk', 'hoşlanma'],
  ['dostluk', 'arkadaşlık', 'samimiyet', 'yakınlık'],
  ['saygı', 'hürmet', 'değer', 'takdir'],
  ['güven', 'itimat', 'eminlik'],
  ['gurur', 'onur', 'namus', 'kibarlık'],
  ['suç', 'suçluluk', 'kabahat', 'suçlamak'],
  ['ceza', 'yaptırım', 'cezalandırma', 'karşılık'],
  ['savaş', 'çatışma', 'dövüş', 'saldırı', 'mücadele'],
  ['barış', 'uzlaşma', 'anlaşma', 'sulh'],
  ['düşman', 'hasım', 'rakip', 'karşıt'],
  ['dost', 'arkadaş', 'yoldaş'],
  ['sorun', 'mesele', 'güçlük', 'aksaklık', 'rahatsızlık'],
  ['çözüm', 'çare', 'tedbir'],
  ['sonuç', 'netice', 'kapanış'],
  ['neden', 'sebep', 'gerekçe', 'amaç'],
  ['tesadüf', 'rastlantı', 'kaza', 'şans'],
  ['alışkanlık', 'töre', 'gelenek'],
  ['bilgi', 'bilme', 'marifet', 'anlayış'],
  ['bilim', 'ilm', 'araştırma'],
  ['fikir', 'düşünce', 'görüş', 'kanaat'],
  ['akıl', 'zihin', 'us', 'muakeme'],
  ['zeka', 'akıllılık', 'deha'],
  ['sabır', 'dayanma', 'soğukkanlılık', 'katlanma'],
  ['acele', 'aciliyet', 'hız', 'diktatörlük'],
  ['tembellik', 'atalet', 'ağırkanlık'],
  ['çalışkanlık', 'gayret', 'emek', 'çaba', 'özveri'],
  ['yorulmak', 'bıkmışlık', 'bitkinlik', 'uykusuzluk', 'yoruldu'],
  ['dinlenmek', 'mola', 'rahatlama', 'soluklanmak'],
  ['stres', 'gerginlik', 'baskı', 'sıkıntı'],
  ['alışveriş', 'satış', 'pazarlık', 'ticaret'],
  ['zarar', 'kötülük', 'hasar'],

  // ---- insanlar ve ilişkiler --------------------------------------------
  ['komşu', 'mahalle', 'komşuluk'],
  ['aile', 'hane', 'yakın'],
  ['anne', 'ana', 'validane'],
  ['baba', 'ata', 'peder'],
  ['çocuk', 'yavru', 'evlat', 'oğlan', 'kız'],
  ['kardeş', 'erkek kardeş', 'kız kardeş'],
  ['kadın', 'hanım', 'bayan'],
  ['erkek', 'adam', 'er'],
  ['misafir', 'konuk', 'ziyaretçi'],
  ['yabancı', 'tanımadık', 'garip'],
  ['öğretmen', 'hoca', 'muallim', 'öğretim'],
  ['doktor', 'hekim', 'tabip', 'tıp'],
  ['hasta', 'tedavi', 'hastalık', 'ilaç', 'ameliyat'],
  ['mühendis', 'teknisyen', 'uzman'],
  ['çiftçi', 'çiftlik', 'ekin', 'tarım'],
  ['şoför', 'sürücü', 'direksiyon'],
  ['asker', 'ordu', 'nefer', 'komutan'],

  // ---- nesneler ----------------------------------------------------------
  ['kitap', 'kitabe', 'cilt', 'baskı', 'sayfa', 'yazı'],
  ['para', 'nakit', 'ödeme', 'para birimi'],
  ['ev', 'konut', 'mesken', 'hane', 'apartman', 'yurt'],
  ['köprü', 'geçit'],
  ['duvar', 'perde', 'bariyer'],
  ['kapı', 'giriş'],
  ['pencere', 'cam'],
  ['masa', 'tezgâh'],
  ['sandalye', 'koltuk', 'oturak', 'iskemle'],
  ['tencere', 'kap', 'tava', 'kapak'],
  ['kibrit', 'çakmak', 'ateş'],
  ['pijamalı', 'takım', 'giysi'],
  ['şehir', 'belediye', 'kent'],
  ['köy', 'köycük', 'kasaba'],
  ['orman', 'ağaçlık', 'gölge'],
  ['dağ', 'tepe', 'zirve', 'yükselti'],
  ['deniz', 'akarsu'],
  ['göl', 'birikinti', 'suy birikintisi'],
  ['nehir', 'akarsu', 'dere', 'çay'],
  ['güneş', 'güneşlenmek', 'şenlik'],
  ['yağmur', 'yağış', 'sağanak'],
  ['rüzgar', 'yeli', 'hava', 'esinti'],
  ['kar', 'beyazlık', 'don', 'buz'],
  ['ateş', 'alev', 'ocak', 'kor'],
  ['balık', 'palamut'],
  ['süt', 'yoğurt', 'peynir', 'ayran'],
  ['ekmek', 'kırmızı', 'nan'],
  ['çay', 'demlemek'],
  ['kaynak', 'pınar', 'kuyu', 'akıntı'],
  ['gökyüzü', 'gök', 'uzay'],
  ['demir', 'metal', 'çelik', 'demirbaş'],
  ['kâğıt', 'kagit', 'sayfa'],
  ['yıldırım', 'şimşek', 'gök gürültüsü'],
  ['rüya', 'düş', 'vizyon'],
  ['hedef', 'niyet', 'gayet'],
  ['emek', 'çalışma', 'iş', 'üretim', 'zahm'],
  ['görev', 'gorev', 'yükümlülük'],
  ['hak', 'adalet', 'hukuk'],

  // ---- eylemler ----------------------------------------------------------
  ['koşmak', 'koşu', 'koşan'],
  ['yürümek', 'yürüyüş', 'yürüyen'],
  ['oturmak', 'oturma', 'oturak'],
  ['kalkmak', 'kalkış'],
  ['uyumak', 'uyku', 'uyandırmak'],
  ['yemek', 'sofra'],
  ['içmek', 'içecek', 'içki'],
  ['giymek', 'giysi', 'giyinmek', 'giyim'],
  ['gülmek', 'gülümseme', 'komik'],
  ['ağlamak', 'ağlama', 'gözyaşı'],
  ['bakmak', 'bakış', 'gözetmek'],
  ['duymak', 'işitmek'],
  ['görmek', 'göz', 'görüş', 'izlemek'],
  ['bilmek', 'anlamak', 'tanımak', 'kavramak', 'öğrenmek'],
  ['anlamak', 'kavramak', 'anlayış', 'anlaşmak', 'aktarmak'],
  ['tanımak', 'tanımlamak'],
  ['düşünmek', 'düşünce', 'fikir'],
  ['anlatmak', 'anlatı', 'aktarmak', 'bildirmek', 'söylemek'],
  ['göstermek', 'gösteri', 'gösterge'],
  ['göndermek', 'gönderi', 'yollamak', 'iletmek'],
  ['gitmek', 'gidiş'],
  ['gelmek', 'geliş', 'varmak'],
  ['bulmak', 'keşfetmek'],
  ['vermek', 'ver'],
  ['satmak', 'satış', 'satıcı', 'satın'],
  ['ödemek', 'ödeme', 'ödünç'],
  ['seçmek', 'seçim'],
  ['beklemek', 'bekle'],
  ['istemek', 'istek', 'ist'],
  ['korkmak', 'korku', 'ürper'],
  ['yapmak', 'yapım', 'yapan', 'üretmek', 'kurmak'],
  ['çalışmak', 'çalışma', 'çalışkan', 'çalışıp'],
  ['dinlenmek', 'dinlenme', 'soluklanmak'],
  ['kaybolmak', 'kaybol', 'yitmek', 'şaşmak'],
  ['unutmak', 'unutma', 'unut'],
  ['hatırlamak', 'hatırlama', 'hatır'],
  ['seven', 'sevmek', 'hoşlanmak'],
  ['istenmek', 'istek'],
  ['bilmek', 'bilgi', 'öğretmek'],
  ['düşmek', 'düşüş', 'vuruş'],
  ['tutmak', 'tutma', 'sıkıca'],
  ['taşımak', 'taşıma', 'taşıyıcı'],
  ['ulaşmak', 'ulaşım', 'erişmek'],
  ['yıkamak', 'yıkama'],

  // ---- sıfatlar ----------------------------------------------------------
  ['güzel', 'güzellik', 'hoş', 'yakışıklı'],
  ['çirkin', 'çirkinlik', 'kötü'],
  ['iyi', 'güzel', 'hoş', 'uygun'],
  ['kötü', 'çirkin', 'bozuk', 'fena'],
  ['büyük', 'devasa', 'geniş', 'kocaman'],
  ['küçük', 'minik', 'ufacık'],
  ['uzun', 'boy', 'Uzunluk'],
  ['kısa', 'kısaca', 'az'],
  ['yeni', 'yenilik', 'taze', 'çağdaş'],
  ['eski', 'eskilik', 'yaşlı', 'kadim'],
  ['genç', 'gençlik', 'bebek'],
  ['yaşlı', 'yaşlılık', 'ihtiyar'],
  ['güçlü', 'güç', 'kuvvetli', 'sağlam'],
  ['zayıf', 'zayıflık', 'cılız'],
  ['hızlı', 'hız', 'çabuk', 'seri'],
  ['yavaş', 'yavaşlık', 'ağır'],
  ['ağır', 'ağırlık'],
  ['hafif', 'hafiflik', 'ağırlıksız'],
  ['geniş', 'genişlik', 'bol'],
  ['dar', 'darlık', 'sıkışık'],
  ['temiz', 'temizlik', 'arı', 'lekesiz'],
  ['kirli', 'kirlilik', 'pis', 'bulaşık'],
  ['zengin', 'zenginlik', 'varlıklı', 'bol'],
  ['fakir', 'fakirlik', 'yoksul', 'mahkûm'],
  ['soğuk', 'soğukluk', 'don', 'buz'],
  ['sıcak', 'sıcaklık', 'ilık'],
  ['sımsık', 'ıslak'],
  ['karanlık', 'loş'],
  ['tatlı', 'tatlılık', 'lezzet', 'şekerli'],
  ['acı', 'ağrı', 'buruk'],
  ['son', 'bitiş', 'final', 'sonuç'],
  ['ilk', 'başlangıç', 'baş'],
  ['gece', 'geceleyin', 'vakit'],
];
