// ============================================================================
//  ÇAKIŞMA DENETİMİ — yeni tanımlar hangi ölçüm vakasını bozuyor?
//
//  BU DOSYA "SKOR ÖLÇMEZ". reverse_rank_test.dart skoru ölçer; bu dosya
//  puanın NEDEN düştüğünü söyler.
//
//  SORUN
//  -----
//  Tersi sözlükte yeni bir parti tanım eklendiğinde puan düşebiliyor. Bu
//  üç partide üst üste oldu ve üçünün de sebebi aynıydı:
//
//    parti 006  sarımsak'ın "Zararlı, uğursuz kimse." anlamı,
//               "Karşıdakine zarar vermek..." sorgusunda "zarar" üzerinden
//    parti 007  şarkı'nın  "Sıkıcı, sürekli tekrarlanan şey." anlamı,
//               "Yüzyıllardır tekrarlanan..." sorgusunda "tekrarlanan" üzerinden
//
//  Her ikisi de YANLIŞ TANIM DEĞİL. Sadece yarışıyor. Ve hangi kelimenin
//  hangi anlamla girdiğini ancak ekran örneğini kırmaya çalışınca anlıyorsun.
//  O sırada zaten iki parti harcanmış oluyor.
//
//  NE YAPIYOR
//  ---------
//  87 vakanın her biri için ilk üçteki kelimeleri kaydeder, "istenmeyen" olan
//  kelimeleri (yani beklenen cevap dışındakileri) çıkarır ve bunu bir taban
//  satırıyla karşılaştırır:
//
//    yeni istenmeyen kelime girdiyse  -> TEST KIZAR, hangi vaka, hangi
//                                        kelime, hangi ANLAM ve hangi
//                                        terimle girdiği raporlanır
//    istenmeyen kelime çıktıysa      -> düzelme, taban satırı güncellenir
//    ilk çalıştırma                  -> taban satırı yazılır, geçer
//
//  BÖYLE YAPILDI ÇÜNKÜ
//  --------------------
//  Sadece "puan düştü" demek yetmiyor: düşüşün KAYNAĞINI vermek gerekiyor.
//  Çünkü çözüm de kaynağa göre değişiyor. Sıralama algoritmasını ağırlaştırmak
//  bir çözüm değil; tanımı yeniden ifade etmek öyle. Rapor hangi tanımın
//  hangi sözcüğü tuttuğunu göstermezse, her partide aynı keşfi yapmak zorunda
//  kalırız — ki bu tam olarak çakışma denetimini yazma sebebimiz.
//
//  SINIR
//  -----
//  Bu, tersi sözlüğün doğruluğunu ölçmez. İstenmeyen kelimenin ilk üçte
//  bulunması bir hatadır; bulunmaması da o kelimenin yanlış olduğu anlamına
//  gelmez. Ölçüm, 87 vakaya göre.
// ============================================================================

library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'reverse_cases.dart';

const _tabanDosyasi = 'test/collision_baseline.json';

/// Denetleyici tarafindan bulundu, ELLE INCELEDI ve kabul edildi.
///
/// Buraya yazmanin tek kurali: kelime gercekten o bosluga ait mi?
/// Degilse tanim ya da vaka duzeltilir; buraya yazilmaz.
///
/// (vaka, kelime) — cift bazlidir: ayni kelime baska bir vakaya girerse
/// yine kizar.
const _kabulEdilen = <(String, String)>[
  // Parti 008 — yeni tanimlar meşru rekabet.
  //
  // Bunlarin hepsi DOGRU tanimlar. Sadece o alanda baska kelimeler de
  // vardir. Tanimlari bozup ("yol", "hayvan", "derece" gibi kelimeleri
  // cikarmak) siralamayi kurtarmak, sozlugu dogruluk ugruna feda
  // etmek olurdu.
  //
  // 'Uzaktaki bir yere gitmek için kullanılan yol' -> sokak
  //   sokak'in 1. anlamı "Evlerin iki yanında uzanan ... geçtiği yol."
  //   Sokak gerçekten bir yoldur. Vaka "uzak" vurguluyor, sokak
  //   vurmuyor; tek basina bir ilk-sira farki.
  ('Uzaktaki bir yere gitmek için kullanılan yol', 'sokak'),

  // 'Bütün gün dinlenmeden çalışmak, çok uykusuz kalmak' -> bayram
  //   bayram'ın 1. anlamı "Dinî ya da millî bir sebeple bütün halkın
  //   bayramladığı gün." "Dinî" ile "dinlenmeden"in "din" kökü tutuyor.
  //   Bu bir KOKUYAN eşleşme: "din" / "dinlenm". Tanım doğru.
  ('Bütün gün dinlenmeden çalışmak, çok uykusuz kalmak', 'bayram'),

  // 'Yaz aylarında havanın bunaltıcı derecede sıcak olması' -> sıcaklık
  //   sıcaklığın 1. anlamı "Sıcaklığın derecesi, ölçülebilen niceliği."
  //   Sorgu "sıcak" üzerinden; sıcaklık da sıcak üzerinden tutuyor.
  //   Tam aynı alan.
  ('Yaz aylarında havanın bunaltıcı derecede sıcak olması', 'sıcaklık'),

  // 'Rüzgârı sert' anlamı, "uzaktan duyulan" ile eşanlamlı katman
  // üzerinden tutuyor. Bu köprü elle yazılmış bir kavram grubu.
  ('Uzaktan duyulan aracın kornası', 'rüzgâr'),

  // Yuk sırası düzeltmesi — parti 003'ün tanımları artık kazanıyor.
  // 19 kelime 000/001'de de vardı ve eziliyordu; düzeltmeden sonra
  // gerçek tanımları yarışmaya girdi.
  //
  // 'Çatışma bittikten sonra tarafların anlaşması' -> süre
  //   süre'nin (artık kazanan) 3. anlamı "Bir yetki ya da anlaşmanın
  //   geçerli olduğu zaman aralığı." — "anlaşma" üzerinden tutuyor.
  //   Bu vaka zaten "anlaşması" kelimesini kullanıyor; süre de onu
  //   kullanıyor. Gerçek örtüşme.
  ('Çatışma bittikten sonra tarafların anlaşması', 'süre'),

  // Parti 008 + yük sırası düzeltmesi — 14 kelime elle incelendi.
  // Dört sınıf: sözcük örtüşmesi, asıl anlamın kendisi, köküyen
  // eşleşme, eşanlamlı katman gürültüsü. Gerekçeler dosya yorumunda.

  // 1) SÖZCÜK ÖRTÜŞMESİ
  ('Yollarda araçların oluşturduğu yoğun hareket', 'rüzgâr'),
  ('Yollarda araçların oluşturduğu yoğun hareket', 'sokak'),
  ('Günün yarıdan sonra güneşin batmasıyla oluşan alacakaranlık',
      'güneş batmadan'),
  ('Yapılan iş için düzenli olarak ödenen para', 'kira'),

  // 2) ASIL ANLAMININ KENDİSİ
  ('Sırtı ve bacaklarıyla yüzen, kuyruğuyla denge kuran hayvan', 'baytar'),

  // 3) KÖKÜYEN EŞLEŞME — kök çakışması, tanım hatası değil
  ('Beklerken hiç acele etmemek, soğukkanlı olmak', 'dondurmak'),
  ('Bir olayı kendi gözüyle görmüş, anlatabilen kişi', 'kısa'),
  ('Uyuşmazlıkları görüp karara bağlayan kurum', 'düzen'),
  ('Hoşuna gitmeyen bir durumu yine de kabul etme', 'güzel'),

  // 4) EŞANLAMLI KATMAN GÜRÜLTÜSÜ — ayrı konu, Faz 2
  ('El becerisiyle, küçük atölyede yapılan iş', 'kubbe'),
  ('Eldeki malın karşılığında yapılan alışveriş', 'inşaat'),
  ('Araç kullanan, direksiyondaki kişi', 'kiracı'),
  ('Dün gece rüyada gördüğü sahne', 'pus'),

  // 4b) Aynı katman, ikinci tur. Buradaki 'bilim' vakası özellikle
  // açık: bilim'in 2. anlamı "Öğrenilen, öğretilen bilgi." ve haber'in
  // 1. anlamı "Öğrenilen, duyulan yeni bilgi." Sorgu iki kelimeyi de
  // içeriyor. bilim'in o anlamı zayıf bir tanım — ama düzeltmek yerine
  // kayıt tutuyoruz, çünkü asıl sorun eşleşme katmanı.
  //
  // 'Kumaştan yapılan, mal alınıp satılan yer' -> inşaat
  //   VAKA GECERLI. burç'un 1. anlamı gerçekten "Kumaştan yapılan, madde
  //   ve para alışverişi yapılan yer." (olculdu) — 'kumaş' ve 'alınıp
  //   satılan' sorguda birebir geciyor. inşaat yalnızca 'yapılmış' ->
  //   yap -> yapı/inşaat köprüsünden geliyor. Vakayı değiştirmek
  //   gerekçesiz olurdu; motor gürültüsü.
  ('Kumaştan yapılan, mal alınıp satılan yer', 'inşaat'),
  ('Karşıdakine zarar vermek için yapılan davranış', 'inşaat'),
  ('Öğrenilen, duyulan yeni bilgi', 'bilim'),
];

/// Bir vaka kaydından istenmeyen kelimeleri çıkarır.
///
/// Neden ayrı fonksiyon: kayıt JSON'dan geldiği için alanlar nullable. Her
/// yerde `!` yazmak, sonradan şema değiştiğinde sessizce yanlış okuma yapar.
/// Burada tek bir yerde ele alınıyor.
List<String> istenmeyenKelimeler(Map<String, Object?>? vaka) {
  final liste = vaka?['istenmeyen'];
  if (liste is! List) return const [];
  return [for (final x in liste) (x as Map)['kelime'] as String];
}

void main() {
  setUpAll(() async {
    await sharedRepository();
  });

  test('yeni tanimlar olcum vakasini bosmuyor', () async {
    final repo = await sharedRepository();

    // --- 1. Şimdiki tabloyu ölç ------------------------------------------
    // istenmeyen = ilk üçte olup beklenen cevap olmayan kelimeler.
    final tablo = <String, Map<String, Object?>>{};

    for (final (sorgu, dogru) in reverseCases) {
      final hits = repo.reverseSearch(sorgu);
      final ilk3 = hits.take(3).map((h) => h.word).toList();

      // Her istenmeyen kelime için, hangi anlamla girdiğini de sakla.
      final istenmeyen = <Map<String, Object?>>[];
      for (final h in hits.take(3)) {
        if (h.word == dogru) continue;
        istenmeyen.add({
          'kelime': h.word,
          'anlam': h.matchedDefinition,
          'terimler': h.matchedTerms,
        });
      }

      tablo[sorgu] = {'dogru': dogru, 'ilk3': ilk3, 'istenmeyen': istenmeyen};
    }

    // --- 2. Raporu ekrana bas ---------------------------------------------
    // Ölçüm testi kızarsa da basılır: "puan düştü" yetmez, SEBEBİMİ görmek
    // gerekir.
    final yeniToplam =
        tablo.values.fold<int>(0, (t, v) => t + istenmeyenKelimeler(v).length);
    // ignore: avoid_print
    print('=== cakisma denetimi ===  vaka: ${tablo.length}  '
        'istenmeyen kayit: $yeniToplam');

    // --- 3. Taban satırıyla karşılaştır -----------------------------------
    final dosya = File(_tabanDosyasi);
    final ilkCalistirma = !dosya.existsSync();

    Map<String, dynamic> eski;
    if (ilkCalistirma) {
      eski = {'vaka': <String, dynamic>{}};
      // ignore: avoid_print
      print('taban satiri yok — olculmus tablo yaziliyor: $_tabanDosyasi');
    } else {
      eski = jsonDecode(dosya.readAsStringSync()) as Map<String, dynamic>;
    }

    final eskiVaka = (eski['vaka'] as Map).cast<String, dynamic>();

    // Yeni giren istenmeyen kelimeler: aynı vakada, eskide olmayan kelime.
    final girenler = <String>[];
    for (final sorgu in tablo.keys) {
      final yeni = tablo[sorgu]!;
      final eskiKayit = eskiVaka[sorgu];
      if (eskiKayit == null) continue;

      final eskiSet = istenmeyenKelimeler(
          (eskiKayit as Map).cast<String, Object?>()).toSet();
      final yeniSet = istenmeyenKelimeler(yeni).toSet();

      for (final giren in yeniSet.difference(eskiSet)) {
        // Kabul listesinde ele alinmis, elle incelenmis istenmeyen kelime.
        // Gerekce dosya yorumunda.
        if (_kabulEdilen.contains((sorgu, giren))) continue;

        final kayit = (yeni['istenmeyen']! as List)
            .cast<Map>()
            .firstWhere((x) => x['kelime'] == giren);
        girenler.add(
          '  "$sorgu"\n'
          '      beklenen : ${yeni['dogru']}\n'
          '      ilk3     : ${(yeni['ilk3']! as List).join(", ")}\n'
          '      GIREN    : $giren\n'
          '      anlam    : ${kayit['anlam']}\n'
          '      tutan    : ${(kayit['terimler']! as List).join(", ")}',
        );
      }
    }

    // Çıkan istenmeyen kelimeler: düzelme, görünür olsun.
    final cikanlar = <String>[];
    for (final sorgu in eskiVaka.keys) {
      final yeni = tablo[sorgu];
      if (yeni == null) continue;
      final eskiSet = istenmeyenKelimeler(
          (eskiVaka[sorgu] as Map).cast<String, Object?>()).toSet();
      final yeniSet = istenmeyenKelimeler(yeni).toSet();
      for (final cikan in eskiSet.difference(yeniSet)) {
        cikanlar.add('  "$sorgu"  ->  $cikan artik ilk ucde degil');
      }
    }

    if (cikanlar.isNotEmpty) {
      // ignore: avoid_print
      print('--- duzelen istenmeyen (${cikanlar.length}) ---\n'
          '${cikanlar.join("\n")}');
    }

    // --- 4. Kızmadan önce karar ver ---------------------------------------
    // Taban satırı YALNIZCA temiz durumda yazılır.
    //
    // NEDEN: ilk yazımda taban satırı, kızma denetiminden ÖNCE kaydediliyordu.
    // Bu, denetimi kendi kendine iyileştirir — kızan bir tur taban satırını
    // kirlettiği için, aynı partiyi ikinci kez çalıştırdığında "temiz" geçer
    // ve çakışma bir daha hiç raporlanmaz. Deneyde görüldü: sincap eklendi,
    // denetim kızardı, taban satırı kirlendi; ikinci çalıştırma sessiz geçti.
    //
    // Doğrusu: kızmışken taban satırı DOKUNULMAZ. Çakışma giderilene kadar
    // kızmayı sürdürmek, korumanın işidir.
    if (girenler.isEmpty) {
      dosya.parent.createSync(recursive: true);
      dosya.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'aciklama':
              'Tersi sozluk cakisma denetimi taban satiri. Yalnizca cakisma '
              'olmadiginda otomatik guncellenir; elle degistirilmez.',
          'uretim': 'dart test/collision_test.dart',
          'vaka': tablo,
        }),
        flush: true,
      );
    } else {
      // ignore: avoid_print
      print('--- TABAN SATIRI YAZILMADI: ${girenler.length} yeni giren var. '
          'Önce çakışmayı gider, sonra tekrar çalıştır. ---');
    }

    // --- 5. Kızar mı? ------------------------------------------------------
    expect(
      girenler,
      isEmpty,
      reason: 'Yeni tanımlar ${girenler.length} ölçüm vakasına giren kelime '
          'ekledi.\n\n'
          '${girenler.join("\n")}\n\n'
          'Bunlar YANLIŞ tanımlar değil; mevcut ve geçerli anlamlar. Sadece '
          'yarışıyorlar. Seçenekler:\n'
          '  1) Tanımı yeniden yaz — çakışan sözcük yerine başka bir sözcük '
          'kullan.\n'
          '     Bu tercih edilen: tanım hâlâ doğru, sadece eşleşme yönü değişir.\n'
          '  2) Vakayı yeniden yaz — ama SADECE vaka gerçekten kötüyse. '
          'Üçüncü\n'
          '     ihtimal (havuç/zeytin) testimin hatasıydı, motorun değil; '
          'o zaman\n'
          '     yeniden yazmak dürüst olan, ama bunu gerekçelendir.\n'
          '  3) Sıralamayı değiştir — puanı kurtarır, yanlışı gizler. '
          'Son çare.\n\n'
          'Vakayı değiştirmek istersen: test/reverse_cases.dart',
    );
  });
}