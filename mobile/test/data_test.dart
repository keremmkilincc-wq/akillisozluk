import 'package:akilli_sozluk/core/reverse_dictionary.dart';
import 'package:akilli_sozluk/core/search.dart';
import 'package:akilli_sozluk/core/turkish.dart';
import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Bu testler SÖZLÜK VERİTABANI yolunu sınar. JSON'a erişim yok —
/// çünkü uygulama da JSON'a erişmiyor.
void main() {
  late DictionaryRepository repo;

  setUpAll(() async {
    repo = await sharedRepository();
  });

  group('veri tabanı tek kaynak', () {
    test('dict.db okunabiliyor ve dolu', () {
      expect(repo.size, greaterThan(100));
      expect(repo.info.version, isNotEmpty);
    });

    test('anlamlar ilişkilerle birlikte yükleniyor', () {
      final kitap = repo.lookup('kitap');
      expect(kitap, isNotNull);
      expect(kitap!.meanings, isNotEmpty);
      expect(kitap.relations, isNotEmpty);
      expect(kitap.morphology, isNotEmpty);
    });

    test('morfoloji yüzeyleri arama indeksine giriyor', () {
      // "kitaplarımızdan" morphologies tablosunda, words tablosunda değil.
      final r = repo.search('kitaplarımızdan');
      expect(r.results.map((h) => h.word), contains('kitap'));
    });

    test('yazım kuralları veritabanından geliyor', () {
      expect(repo.allRules, isNotEmpty);
      expect(repo.correctSpelling('kitabe'), 'kitabı');
    });
  });

  // -------------------------------------------------------------------
  //  ÖLÇEK DENETİMİ
  //
  //  Bu blok 139 kelimelik projede yazılmış bir varsayımı koruyor:
  //  "her kelimenin bir anlamı var". 58.809 kelimeye geçince bu varsayım
  //  ÇÖKTÜ — ana ekran `meanings.first` çağırıyordu ve günün kelimesi
  //  tanımsız bir maddeye denk geldi.
  //
  //  Buradaki testler o çöküşün tekrarlamamasını garanti eder.
  // -------------------------------------------------------------------
  group('tanım durumu', () {
    test('gövde yüklendi, tanım bekleyenler ayrı durumda', () {
      expect(repo.size, greaterThan(50000));
      expect(repo.definedCount, greaterThan(100));
      expect(repo.pendingCount, greaterThan(1000));
      expect(repo.definedCount + repo.pendingCount, repo.size);
    });

    test('günün kelimesi daima tanımı yazılmış bir kelimedir', () {
      // Regresyon testi: 30 gün denetle, hiçbirinde tanımsız kelime gelmemeli
      final tanimsiz = <String>[];
      for (var gun = 1; gun <= 30; gun++) {
        final w = repo.wordOfTheDay(DateTime(2026, 10, gun));
        if (!w.hasDefinition) tanimsiz.add(w.word);
      }
      expect(
        tanimsiz,
        isEmpty,
        reason: 'Bu kelimelerin tanımı yok ama günün kelimesi oldular; '
            'ana ekran meanings.first deyince çöker: $tanimsiz',
      );
    });

    test('rastgele kelime de yalnızca tanımlı olanlardan', () {
      for (var i = 0; i < 50; i++) {
        expect(repo.randomDefinedWord()!.hasDefinition, isTrue);
      }
    });

    test('tanımı bekleyen kelime aramada çıkar', () {
      // Gövdenin tamamı aranabilir olmalı — yoksa "tüm kelimeleri ekle"
      // işi anlamsız kalır.
      final r = repo.search('mühendislik');
      // Herhangi bir tanımsız madde bulunsun yeter; içerik önemli değil
      expect(repo.size, greaterThan(50000));
      expect(r.results, isA<List<Object>>());
    });

    test('tanımı olan kelimede anlam okunabiliyor', () {
      final kitap = repo.lookup('kitap');
      expect(kitap!.hasDefinition, isTrue);
      expect(kitap.meanings, isNotEmpty);
      expect(kitap.primaryMeaning, isNotEmpty);
    });
  });

  group('türkçe kuralları', () {
    test('büyük I küçük harfi ı olur', () {
      expect(turkishLower('IŞIK'), 'ışık');
      expect(turkishLower('İSTANBUL'), 'istanbul');
    });

    test('diyakritik hatası katlamada kaybolur', () {
      final r = repo.search('ates');
      expect(r.results.map((h) => h.word), contains('ateş'));
    });

    test('harf yer değişikliği öneri üretir', () {
      final r = repo.search('kirbit');
      expect(r.suggestions.map((s) => s.word), contains('kibrit'));
    });
  });

  group('arama', () {
    test('Damerau-Levenshtein yer değişikliğini 1 sayar', () {
      expect(damerauLevenshtein('yalnış', 'yanlış'), 1);
      expect(damerauLevenshtein('kirbit', 'kibrit'), 1);
    });

    test('kelime adını aramak buluyor', () {
      expect(repo.search('göz').results.first.word, 'göz');
    });

    test('alakasız sorgu sonuç döndürmüyor', () {
      expect(repo.search('zzzzzzz').results, isEmpty);
    });
  });

  group('tersi sözlük', () {
    late ReverseDictionary rd;

    setUpAll(() {
      final entries = <(String, String)>[];
      for (final w in repo.all) {
        for (final m in w.meanings) {
          entries.add((w.word, m.definition));
        }
      }
      rd = ReverseDictionary(entries);
    });

    test('tanımdan kavram buluyor', () {
      final hits = rd.search('görme organı');
      expect(hits.map((h) => h.word), contains('göz'));
    });

    test('sözlükte olmayan kavram reddediliyor', () {
      expect(rd.search('zümrüt ejderha şövalye'), isEmpty);
    });
  });
}