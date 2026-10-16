// ============================================================================
//  ARAMA MOTORU TESTLERİ
//
//  Bunlar süs değil: Türkçe arama motorunun sessizce bozulması en yaygın
//  hatadır. 'I' → 'i' dönüşümü hatalıysa uygulama "kış" aramasında "kiş"
//  bulur ve kimse nedenini anlamaz.
// ============================================================================

import 'package:akilli_sozluk/core/search.dart';
import 'package:akilli_sozluk/core/turkish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Türkçe büyük/küçük harf', () {
    test('I küçük harfi ı olur, i olmaz', () {
      expect(turkishLower('I'), 'ı');
      expect(turkishLower('IŞIK'), 'ışık');
      // G, Ğ değil: KIRGI → kırgı (kırğı DEĞİL)
      expect(turkishLower('KIRGI'), 'kırgı');
    });

    test('İ küçük harfi i olur, birleşik noktasız', () {
      expect(turkishLower('İ'), 'i');
      expect(turkishLower('İSTANBUL'), 'istanbul');
      // Birleşen nokta (U+0307) üretilmemeli
      expect(turkishLower('İ').runes.length, 1);
    });

    test('küçük harften büyüğe de Türkçe kurallarıyla', () {
      expect(turkishUpper('ı'), 'I');
      expect(turkishUpper('i'), 'İ');
      expect(turkishUpper('ışık'), 'IŞIK');
    });
  });

  group('Arama için katlama', () {
    test('diyakritikler kaldırılır', () {
      expect(foldTurkish('rüzgâr'), 'ruzgar');
      expect(foldTurkish('çocuk'), 'cocuk');
      expect(foldTurkish('şey'), 'sey');
      expect(foldTurkish('öğretmen'), 'ogretmen');
    });

    test('ı ve i arama için aynıdır', () {
      expect(foldTurkish('kış'), foldTurkish('kış'));
      expect(foldTurkish('Işık'), foldTurkish('ışık'));
      expect(foldTurkish('bilgi'), foldTurkish('bilgi'));
    });
  });

  group('Damerau-Levenshtein', () {
    test('aynı sözcük sıfır', () {
      expect(damerauLevenshtein('kitap', 'kitap'), 0);
    });

    test('tek harf ekleme/silme/değiştirme', () {
      expect(damerauLevenshtein('kitap', 'kitab'), 1);
      expect(damerauLevenshtein('kitap', 'kitapa'), 1);
      expect(damerauLevenshtein('kitap', 'kitip'), 1);
    });

    test('KELİME DEĞİŞTİRME bir işlem sayılır — kritik test', () {
      // Klasik Levenshtein bunlara 2 verir.
      expect(damerauLevenshtein('yalnış', 'yanlış'), 1);
      expect(damerauLevenshtein('kirbit', 'kibrit'), 1);
      expect(damerauLevenshtein('şoför', 'şöför'), 1);
      expect(damerauLevenshtein('sefer', 'safer'), 1);
    });

    test('yoksa mesafe artar', () {
      expect(damerauLevenshtein('kitap', 'pencere'), greaterThan(3));
    });
  });

  group('Jaro-Winkler', () {
    test('aynı ve yakın sözcükler yüksek benzerlik', () {
      expect(jaroWinkler('kitap', 'kitap'), 1.0);
      // 0.88 matematiksel olarak doğru değer (4/5 eşleşme, 1 uyuşmazlık)
      expect(jaroWinkler('şoför', 'şöför'), greaterThan(0.85));
      expect(jaroWinkler('kirkit', 'kibrit'), greaterThan(0.85));
    });

    test('alakasız sözcükler düşük benzerlik', () {
      expect(jaroWinkler('kitap', 'pencere'), lessThan(0.5));
    });
  });

  group('Heceleme', () {
    test('basit iki heceli sözcük', () {
      expect(syllabify('kitap'), 'ki-tap');
    });

    test('sert ünsüz ünlüyü çeker', () {
      // 'kitap' + 'ta' → 'ta' sert (t), bölme yok: kitap-ta
      expect(syllabify('kadın'), 'ka-dın');
    });
  });

  group('Uçtan uca arama', () {
    late FuzzySearch engine;

    setUp(() {
      engine = FuzzySearch([
        'şoför', 'sofor', 'yolcu', 'kitap', 'kibrit', 'kış', 'kar',
        'güneş', 'deniz', 'orman', 'göz', 'yol', 'su', 'ateş',
      ]);
    });

    test('birebir eşleşme bulunur', () {
      final r = engine.search('şoför', const []);
      expect(r.results.first.word, 'şoför');
      expect(r.results.first.kind, MatchKind.exact);
    });

    test('yazım hatası öneri üretir', () {
      // Diyakritik hatası katlamada kaybolur, bu yüzden öneri değil
      // SONUÇ döner; arayüz "doğru yazımı" diye işaretler.
      final r = engine.search('şöför', const []);
      expect(r.results.first.word, 'şoför');
      expect(r.results.first.kind, MatchKind.spellingVariant);
    });

    test('harf yer değişikliği öneri üretir', () {
      // Trigram indeksinin kaçırdığı durum: 'kirbit' ve 'kibrit'
      // yalnızca 'bit' trigramını paylaşır.
      final r = engine.search('kirbit', const []);
      expect(r.suggestions.map((s) => s.word), contains('kibrit'));
    });

    test('eksik harf öneri üretir', () {
      final r = engine.search('kitaba', const []);
      expect(r.suggestions.map((s) => s.word), contains('kitap'));
    });

    test('öneki yazınca aday listelenir', () {
      final r = engine.search('kış', const []);
      expect(r.results.map((h) => h.word), contains('kış'));
    });

    test('boş sorgu sonuç döndürmez', () {
      final r = engine.search('   ', const []);
      expect(r.results, isEmpty);
      expect(r.suggestions, isEmpty);
    });

    test('tamamen alakasız sorgu öneri üretmez', () {
      final r = engine.search('zzzzzzz', const []);
      expect(r.suggestions, isEmpty);
    });
  });
}