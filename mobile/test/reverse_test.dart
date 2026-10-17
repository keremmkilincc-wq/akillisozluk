// ============================================================================
//  TERSİ SÖZLÜK TESTLERİ
//
//  Bu algoritmanın en büyük riski "yalan söylemesi": kullanıcı tanım yazar,
//  uygulama alakasız bir kelimeyi yüksek puanla döndürürse güven biter.
//  Bu yüzden hem isabet hem de alakasızlık reddi test ediliyor.
// ============================================================================

import 'package:akilli_sozluk/core/reverse_dictionary.dart';
import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // rootBundle, binding kurulmadan kullanılamaz.
  TestWidgetsFlutterBinding.ensureInitialized();

  late DictionaryRepository repo;
  late ReverseDictionary rd;

  setUpAll(() async {
    repo = DictionaryRepository();
    await repo.load();

    final entries = <(String, String)>[];
    for (final w in repo.all) {
      for (final m in w.meanings) {
        entries.add((w.word, m.definition));
      }
    }
    rd = ReverseDictionary(entries);
  });

  group('isabet', () {
    test('tanımdaki çekirdek kavramları içeren sorgu doğru kelimeyi bulur', () {
      // "sınır" tanımında geçen kavramlar
      final hits = rd.search('bir yapının iki yanı arasında kalan dikey bölüm');
      expect(hits, isNotEmpty);
      expect(hits.map((h) => h.word), contains('duvar'));
    });

    test('zıt anlam tanımına yakın sorgu', () {
      final hits = rd.search('gerçekleşmek üzereyken vazgeçmek');
      expect(hits, isNotEmpty);
    });

    test('kelime adını yazmak da bulur', () {
      final hits = rd.search('görme organı');
      expect(hits.map((h) => h.word), contains('göz'));
    });
  });

  group('alakasızlık reddi', () {
    test('sözlükte hiç olmayan kavramlar sonuc döndürmez', () {
      // Sözlükte bu kavramlar yok; döndürüyorsa algoritma gürültü üretiyor.
      final hits = rd.search('zümrüt ejderha şövalye kılıç kalkan');
      expect(hits, isEmpty);
    });

    test('çok kısa sorgu reddedilir', () {
      expect(rd.search('ab'), isEmpty);
      expect(rd.search('   '), isEmpty);
    });

    test('yalnızca stopword içeren sorgu reddedilir', () {
      expect(rd.search('bir şey olan için gibi'), isEmpty);
    });
  });

  group('sıralama ve biçim', () {
    test('sonuçlar skor sırasına göre azalan', () {
      final hits = rd.search('gerçeğe uymayan hatalı olan');
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i - 1].score, greaterThanOrEqualTo(hits[i].score));
      }
    });

    test('aynı kelime iki kez dönmez', () {
      final hits = rd.search('gerçeğe uymayan hatalı olan');
      final words = hits.map((h) => h.word).toList();
      expect(words.length, words.toSet().length);
    });

    test('eşleşen terimler açıkça raporlanır', () {
      final hits = rd.search('görme organı');
      if (hits.isNotEmpty) {
        expect(hits.first.matchedTerms, isNotEmpty);
        for (final t in hits.first.matchedTerms) {
          expect(t, isA<String>());
        }
      }
    });

    test('skor 0 ile 1 arasında', () {
      for (final h in rd.search('görme organı')) {
        expect(h.score, inInclusiveRange(0, 1));
      }
    });
  });
}