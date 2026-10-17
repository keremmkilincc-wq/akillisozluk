// ============================================================================
//  WORDLE HAVUZ BÜTÜNLÜĞÜ
//
//  Bu testler oyun motorunu değil, oyunun VAR OLMA KOŞULUNU denetler.
//
//  Neden: kelime listesi elle yazıldı. Elle yazılan veri bozulur — yanlış
//  harf sayısı, listede olmayan kelime, cevabın tahmin havuzunda bulunmaması.
//  Bunların hepsi kullanıcıya oyunun SONUNU bozarak ulaşır:
//
//    * 4 harfli kelime havuzda  -> oyun hiç bitmez
//    * cevap havuzda yok        -> kullanıcı cevabı asla tahmin edemez
//    * havuz çökerse            -> oyun açılmaz
//
//  Bunlar sessizdir. Bu testler onları bağırir.
// ============================================================================

import 'package:akilli_sozluk/core/wordle.dart';
import 'package:akilli_sozluk/data/wordle_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WordleWords w;

  setUpAll(() async {
    w = await WordleWords.load();
  });

  group('havuz kullanılabilir', () {
    test('oyun açılabilir durumda', () {
      expect(
        w.isUsable,
        isTrue,
        reason: 'Havuz çok küçük. '
            'Cevap: ${w.answers.length}, tahmin: ${w.pool.length}. '
            'build_wordle.py çıktısını kontrol et.',
      );
    });

    test('her kelime tam 5 harf', () {
      final yanlis = {...w.answers, ...w.pool}
          .where((x) => x.length != 5)
          .toList();
      expect(
        yanlis,
        isEmpty,
        reason: '5 harfli olmayan kelimeler oyunda kullanılamaz: $yanlis',
      );
    });

    test('kelimeler küçük harfle yazılmış', () {
      final buyuk = {...w.answers, ...w.pool}
          .where((x) => x != x.toLowerCase())
          .toList();
      expect(buyuk, isEmpty, reason: 'Büyük harfli girişler: $buyuk');
    });

    test('Türkçe olmayan harf yok', () {
      const yabanci = {'q', 'w', 'x'};
      final kotu = {...w.answers, ...w.pool}
          .where((x) => x.split('').any(yabanci.contains))
          .toList();
      expect(kotu, isEmpty, reason: 'q/w/x Türkçe kelime oluşturmaz: $kotu');
    });

    test('listelerin kendi içinde tekrar yok', () {
      // NOT: answers + pool BIRLESTIRILIP sayilmamali. Cevaplar zaten
      // havuzun alt kumesidir (her cevap oynanabilir olmali), yani
      // birlestirilince "tekrar" dogal olarak cikar. Ilk yazimda boyle
      // yazmistik ve test havuzu hatali buluyordu.
      expect(w.pool.toSet().length, w.pool.length,
          reason: 'Tahmin havuzunda aynı kelime iki kez geçiyor');
      expect(w.answers.toSet().length, w.answers.length,
          reason: 'Cevap listesinde aynı kelime iki kez geçiyor');
    });

    test('her cevap tahmin havuzunda da var', () {
      final pool = w.pool.toSet();
      final eksik = w.answers.where((a) => !pool.contains(a)).toList();
      expect(
        eksik,
        isEmpty,
        reason: 'Bu cevaplar oynanabilir değil — kullanıcı tahmin bile '
            'edemez: $eksik',
      );
    });

    test('boş kelime yok', () {
      expect(w.answers.any((x) => x.trim().isEmpty), isFalse);
      expect(w.pool.any((x) => x.trim().isEmpty), isFalse);
    });
  });

  group('oyun kurulabiliyor', () {
    test('günün motoru her gün bir cevap seçiyor', () {
      for (var gun = 1; gun <= 28; gun++) {
        final e = WordleEngine.forToday(
          answers: w.answers,
          allowed: w.pool,
          now: DateTime(2026, 10, gun),
        );
        expect(w.answers, contains(e.answer));
        expect(e.answer.length, 5);
      }
    });

    test('motor cevabı kendi tahmininde kabul ediyor', () {
      final e = WordleEngine.forToday(
        answers: w.answers,
        allowed: w.pool,
        now: DateTime(2026, 10, 17),
      );
      // Oyun sonunda kullanici cevabi yazar; motor bunu kabul etmeli.
      expect(e.isAllowed(e.answer), isTrue);
    });

    test('bir yarışma tam oynanabiliyor', () {
      final e = WordleEngine.forToday(
        answers: w.answers,
        allowed: w.pool,
        now: DateTime(2026, 10, 17),
      );
      for (var i = 0; i < WordleEngine.maxGuesses; i++) {
        expect(e.isAllowed(e.answer), isTrue);
        e.guess(e.answer);
        if (e.isWon) break;
      }
      expect(e.isWon, isTrue, reason: 'Cevap 6 denemede bulunamıyor');
    });
  });
}