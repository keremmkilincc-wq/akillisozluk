// ============================================================================
//  TERSİ SÖZLÜK ÖLÇÜMÜ — ORTAK VAKA LİSTESİ
//
//  Bu liste iki yerde kullanılıyor:
//
//    reverse_rank_test.dart  — puanı ölçer (ilk sıra / ilk-3)
//    collision_test.dart     — çakışma denetimi yapar
//
//  Ayrı tutulmasının sebebi: çakışma denetimi vakaları değiştirmek zorunda
//  kalmasın. Biri değiştiğinde diğeri de değişmiş sayılır ve iki ölçüm
//  sessizce birbirine karışır. Tek liste, iki tüketicı.
//
//  NEDEN VAR: tersi sözlük 26 soruluk ölçümde ilk sıra doğruluğunu
//  %31'de durduruyordu. Kalan hataların çoğu gövde kırpma ya da sıralama
//  hatası DEĞİL — kavramsal boşluk.
//
//  İKİ DAL: zorlukları farklı iki ölçüm. Ortalanmıyorlar; toplamları
//  anlamsız. Tek sayı, kolay vakaların zor olanları gizliyordu.
// ============================================================================

library;

/// ZOR DAL — tanımın anahtar sözcüğü doğrudan geçmiyor, ya da eşleşme
/// jenerik sözcükler üzerinden oluyor.
///
/// 24 vaka. Parti 003–007 arası tanımlar eklendikçe ölçüldü:
///   parti 002 verisi + düzeltmeler   ilk 12/26  ilk3 15/26
///   parti 003 verisi                ilk 11/26  ilk3 15/26
///   parti 004 verisi                ilk 11/26  ilk3 14/26
///   iki dala bölündükten sonra       ilk 12/24  ilk3 13/24
///   parti 005 verisi                ilk 12/24  ilk3 13/24
///   parti 006 verisi                ilk 12/24  ilk3 13/24
///   parti 007 verisi                ilk 12/24  ilk3 13/24
const reverseCasesZor = <(String, String)>[
  // Tanım eş anlamlıyla yazılmış, doğrudan kelime geçmiyor
  ('Uzaktan duyulan aracın kornası', 'ses'),
  ('Çatışma bittikten sonra tarafların anlaşması', 'barış'),
  ('Kendini başkasının fikrine benimsetme çabası', 'satmak'),
  ('Bir şeyin ne olduğunu öğrenmek, tanımak', 'tanımak'),
  ('Kimseye zarar vermeden yaşamak, başkasını gözetmek', 'hoşgörü'),
  ('Bütün gün dinlenmeden çalışmak, çok uykusuz kalmak', 'yorgun'),
  ('Karşı tarafın aleyhine olan şey', 'düşman'),
  ('Hayalindeki şeyi gerçekleşmiş saymak', 'umut'),

  // Zor: eşleşme çoğunlukla jenerik sözcükler üzerinden
  ('Bir ülkenin başka ülkeye ordusuyla saldırması', 'savaş'),
  ('Kapalı kalan tartışma, açıklığa kavuşmamış konu', 'sorun'),
  ('Yaz aylarında havanın bunaltıcı derecede sıcak olması', 'sıcak'),
  ('Doğum tarihine göre hesaplanan gökyüzü bölgeleri', 'burç'),
  ('Günün yarıdan sonra güneşin batmasıyla oluşan alacakaranlık', 'akşam'),
  ('Birbirinin sırrını saklayan yakın dostluk', 'dostluk'),
  ('Eldeki malın karşılığında yapılan alışveriş', 'pazar'),

  // Parti 004'te tanımlanan kelimelerden, yine zor yazılmış olanlar
  ('Kanunla belirlenmiş, uyulması zorunlu ölçü', 'kural'),
  ('Hakkı gözetme, doğru davranma', 'adalet'),
  ('Yerine getirmesi gereken iş, yükümlülük', 'görev'),
  ('El becerisiyle, küçük atölyede yapılan iş', 'zanaat'),
  ('Giderler karşılandıktan sonra kalan para', 'kazanç'),
  ('El işi, üretim için kullanılan taşıt', 'araba'),
  ('Dağın iki yakasını bağlayan geçmeye yarayan yapı', 'köprü'),
  ('Alınıp satılan malların değiş tokuş edilmesi', 'ticaret'),
  ('Taşıtta ya da eğlencede seyretme hakkı karşılığı kart', 'bilet'),
];

/// TEMEL DAL — tanımın anahtar sözcükleri doğrudan sorguda geçiyor.
///
/// 63 vaka. Hepsi tanımlı kelimeleri hedef alır; aşağıdaki koruma testi
/// ("her vakanin cevabi sozlukte tanimli") bunu denetler.
const reverseCasesTemel = <(String, String)>[
  // Parti 000–002
  ('Konuşma yoluyla düşünceleri aktarmak için kullanılan işaretler', 'dil'),
  ('Kumaştan yapılan, mal alınıp satılan yer', 'burç'),
  ('Dün gece rüyada gördüğü sahne', 'rüya'),
  ('Yemek pişirmek için kullanılan geniş kap', 'tencere'),
  ('Bir işi sona erdirmek, bitirmek', 'bitirmek'),
  ('Uzaktaki bir yere gitmek için kullanılan yol', 'yol'),
  ('Yetersiz, güçsüz, dayanıksız', 'zayıf'),
  ('Karşıdakine zarar vermek için yapılan davranış', 'suç'),
  ('Beklerken hiç acele etmemek, soğukkanlı olmak', 'sabır'),
  ('Yapılması gereken, görev olarak verilen iş', 'görev'),
  ('Yazılmış, basılmış kitap sayfaları', 'sayfa'),

  // Parti 003 — kavramlar
  ('Zihni meşgul eden, sonucu belirsiz durumlara karşı endişe', 'kaygı'),
  ('İyi bir sonuç geleceğine dair beslenen beklenti', 'umut'),
  ('Sıkıntı içinde kendini dizginleme gücü', 'sabır'),
  ('Hoşuna gitmeyen bir durumu yine de kabul etme', 'hoşgörü'),
  ('Birinin dürüstlüğüne ya da bir şeyin doğruluğuna inanma', 'güven'),
  ('Onu önemli sayma ve değer verme duygusu', 'saygı'),
  ('Kurallara ve düzene uyma davranışı', 'disiplin'),
  ('Bir amaca ulaşmak için izlenen düzenli yol', 'yöntem'),
  ('Bir olaydan ortaya çıkan durum', 'sonuç'),
  ('Soruya verilen karşılık, yanıt', 'cevap'),
  ('Bir şeyin öğrenilmesi için sorulan cümle', 'soru'),
  ('Öğrenilen, duyulan yeni bilgi', 'haber'),
  ('Kimsenin anlamadığı, dışlanmış hissi', 'yalnızlık'),
  ('Çok sayıda kişinin bir araya geldiği yer', 'kalabalık'),
  ('Toplumu oluşturan, tek başına bir kişi', 'birey'),
  ('Kendisinden sonra gelecek zaman', 'gelecek'),
  ('Zaman içinde çok kısa süren, belirli aralık', 'an'),
  ('Bir işi yerine getirmek için harcanan zihinsel emek', 'çaba'),
  ('Zeytin ağacından toplanan, küçük ve acı meyve', 'zeytin'),
  ('Sırtı ve bacaklarıyla yüzen, kuyruğuyla denge kuran hayvan', 'balık'),

  // Parti 004 — eğitim
  ('Sınıfta öğretmenin anlattığı konu', 'ders'),
  ('Sınav sonucunda öğrencinin aldığı puan', 'not'),

  // Parti 004 — ulaşım
  ('Araç kullanan, direksiyondaki kişi', 'sürücü'),
  ('Ray üzerinde hareket eden, vagonlardan oluşan uzun araç', 'tren'),
  ('Uçakların kalkıp indiği alan', 'havalimanı'),
  ('Dağın içinden açılan, iki ucu olan geçit', 'tünel'),
  ('Yollarda araçların oluşturduğu yoğun hareket', 'trafik'),
  ('Beklenmedik, istemeden gerçekleşen olay', 'kaza'),

  // Parti 004 — iş dünyası
  ('Ücret karşılığında çalışan, amirin emri altındaki kişi', 'işçi'),
  ('Çalışanların amiri, işletmeyi yöneten kişi', 'patron'),
  ('Dükkândan mal alan kişi', 'müşteri'),
  ('Aracı çalıştıran, yakıt tüketen makine parçası', 'motor'),
  ('Mevduat alıp kredi veren kurum', 'banka'),
  ('Sayılar arasındaki ilişkileri yapma işi', 'hesap'),
  ('Başkasından alınıp geri ödenmesi gereken para', 'borç'),
  ('Devletin kamu hizmetleri için topladığı para', 'vergi'),
  ('Çalışma hayatını tamamlayıp işten ayrılmış kişi', 'emekli'),
  ('Üretilmiş mal ve hizmetlerin ihtiyaç için kullanılması', 'tüketim'),
  ('Yapılan iş için düzenli olarak ödenen para', 'maaş'),

  // Parti 004 — hukuk
  ('Uyulması zorunlu, meclisçe konulan kural', 'yasa'),
  ('Bir olayı kendi gözüyle görmüş, anlatabilen kişi', 'tanık'),
  ('Toplumda uyulması zorunlu kuralların bütünü', 'hukuk'),
  ('Uyuşmazlıkları görüp karara bağlayan kurum', 'mahkeme'),
  ('Mahkemede bir kişiyi temsil eden meslek erbabı', 'avukat'),
  ('Hakkın korunması için mahkemede açılan uyuşmazlık', 'dava'),
  ('Bir karara karşı çıkma', 'itiraz'),

  // Parti 004 — teknoloji
  ('Uzaktan sesli iletişim kurmaya yarayan araç', 'telefon'),
  ('Bilgi işleyen, hesap yapan elektronik araç', 'bilgisayar'),
  ('Aydınlatma ve çalıştırmada kullanılan enerji', 'elektrik'),
  ('Uzaktan görüntü ve ses ileten ekranlı cihaz', 'televizyon'),
  ('Işığa duyarlı bir yüzeyle kaydedilmiş görüntü', 'fotoğraf'),
  ('Sesli yayın yapan alıcı cihaz', 'radyo'),
];

/// Bütün vakalar.
const reverseCases = <(String, String)>[...reverseCasesZor, ...reverseCasesTemel];
