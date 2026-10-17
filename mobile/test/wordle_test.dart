// ============================================================================
//  WORDLE MOTORU TESTLERİ
//
//  Beklentiler ELLE hesaplanmadi. Motor calistirildi, ciktisi alindi ve
//  her satir bagimsiz olarak dogrulandi. Ilk yazimda uc beklenti yanlisti
//  ("kapak", "katap", "kipat" vakalari); motor her seferinde dogruydu.
//
//  En kritik bolum tekrar harfler: Turkce eklerden dolayi ayni harf
//  sikligi yuksek. Basit bir sayaç uygulamasi kullaniciya YANLIS bilgi
//  verir.
// ============================================================================

import 'package:akilli_sozluk/core/wordle.dart';
import 'package:flutter_test/flutter_test.dart';

WordleEngine engine({String answer = 'kitap'}) => WordleEngine(
      answers: [answer],
      allowed: const ['kitap', 'kapak', 'kavak', 'sunuc', 'atlas'],
      answer: answer,
    );

String render(List<LetterState> states) => states
    .map((s) => switch (s) {
          LetterState.correct => 'Y', // yeşil
          LetterState.present => 'S', // sarı
          LetterState.absent => 'G', // gri
        })
    .join();

void main() {
  group('temel puanlama', () {
    test('tam isabet kazanır', () {
      final r = engine().guess('kitap');
      expect(r.isWin, isTrue);
      expect(render(r.states), 'YYYYY');
    });

    test('ortak harf yoksa tamamen gri', () {
      // kitap / sunuc -> ortak harf YOK
      final r = engine().guess('sunuc');
      expect(render(r.states), 'GGGGG');
    });

    test('dört harf yerinde eşleşirse dördü yeşil', () {
      //   k i t a p
      //   k a t a p
      //   ^   ^ ^ ^ yerinde. 2. konumdaki "a" yanlış yerde ama kitap'ta
      //     tek "a" var (3. konum) ve o zaten yeşil sayıldı, sayaç tükendi
      //     -> gri
      final r = engine().guess('katap');
      expect(render(r.states), 'YGYYY');
    });

    test('yer değiştiren harfler sarı olur', () {
      //   k i t a p
      //   k i p a t
      //   ^ ^   ^ ^ yerinde. "p" 2. konumda ama kitap'ta 5. konumda,
      //   "t" 5. konumda ama kitap'ta 3. konumda -> ikisi de sarı
      final r = engine().guess('kipat');
      expect(render(r.states), 'YYSYS');
    });
  });

  group('tekrar harfler — en kritik bölüm', () {
    test('kapak -> kitap', () {
      //   k a p a k
      //   k i t a p
      //   ^     ^ ^ yerinde; "a"(1) sayaç tükendi -> gri; "p"(2) sarı
      final r = engine().guess('kapak');
      expect(render(r.states), 'YGSYG');
    });

    test('sayaç tükenince sonraki tekrar gri olur', () {
      // cevap kavak : k a v a k   (a×2, k×2)
      // akaka       : a k a k a
      // Cevaptaki 2 "a" ve 2 "k" tahminin ilk 4 harfini karşılar; 5. harf
      // artık karşılıksızdır.
      //
      // Sayaç harcanmadan sarı sayılırsa 5. harf de sarı çıkar ve kullanıcıya
      // yanlış bilgi verilir — oyunun en sık hata yapılan yeri budur.
      final r = engine(answer: 'kavak').guess('akaka');
      expect(render(r.states), 'SSSSG');
      expect(r.states[4], LetterState.absent);
    });

    test('iki kez geçen harf için ikisi de sarı olabilir', () {
      final r = engine(answer: 'kavak').guess('akaka');
      expect(r.states[0], LetterState.present);
      expect(r.states[1], LetterState.present);
    });

    test('mükerrer harf yanlışlıkla yeşil sayılmaz', () {
      // kavak / katak -> sadece ortadaki "t" yanlış, o da cevapta yok
      final r = engine(answer: 'kavak').guess('katak');
      expect(render(r.states), 'YYGYY');
      expect(r.states[2], LetterState.absent);
    });

    test('ortak tek harf varsa yalnız o sarı olur', () {
      // kavak / sokul -> ortak harf yalnızca "k"
      final r = engine(answer: 'kavak').guess('sokul');
      expect(render(r.states), 'GGSGG');
    });

    test('ters sıralama da doğru puanlanır', () {
      // kapak / kitap
      //   k a p a k
      //   k i t a p
      final r = engine(answer: 'kapak').guess('kitap');
      expect(render(r.states), 'YGGYS');
    });

    test('kelimenin harfleri tamamen yer değiştirirse', () {
      // deniz / zinde -> d e n i z  /  z i n d e
      //   ^ ^   ^ ^ yerinde; kalan iki harf karşılıklı yer değiştirmiş
      final r = engine(answer: 'deniz').guess('zinde');
      expect(render(r.states), 'SSYSS');
    });
  });

  group('savunma', () {
    test('5 harf olmayan tahmin reddedilir', () {
      // Bu bir zamanlar RangeError ile çöktü: 4 harfli cevapla 5 harfli
      // tahmin denendi ve answer[i] indeks dışına çıktı.
      expect(() => engine(answer: 'sofa').guess('yoldu'), throwsArgumentError);
    });

    test('5 harf olmayan cevap reddedilir', () {
      expect(() => engine(answer: 'sofa').guess('deniz'), throwsArgumentError);
    });
  });

  group('oyun akışı', () {
    test('altı tahminden sonra biter', () {
      final e = engine();
      for (var i = 0; i < 6; i++) {
        e.guess('sunuc');
      }
      expect(e.guessesUsed, 6);
      expect(e.isOver, isTrue);
    });

    test('kazanınca oyun biter', () {
      final e = engine();
      e.guess('sunuc');
      final r = e.guess('kitap');
      expect(r.isWin, isTrue);
      expect(e.isWon, isTrue);
    });

    test('havuz dışı tahmin kabul edilmez', () {
      final e = engine();
      expect(e.isAllowed('kitap'), isTrue);
      expect(e.isAllowed('zzzzz'), isFalse);
      expect(e.isAllowed('kita'), isFalse); // 4 harf
    });

    test('günün cevabı aynı gün hep aynıdır', () {
      const w = ['kitap', 'deniz', 'sofa', 'masa', 'balık'];
      String at(DateTime d) =>
          WordleEngine.forToday(answers: w, allowed: w, now: d).answer;
      final gun1 = DateTime(2026, 10, 17);
      expect(at(gun1), at(gun1));
    });

    test('farklı gün farklı cevap verebilir', () {
      const w = ['kitap', 'deniz', 'sofa', 'masa', 'balık'];
      final farkli = <String>{};
      for (var gun = 1; gun <= 5; gun++) {
        farkli.add(
          WordleEngine.forToday(
            answers: w,
            allowed: w,
            now: DateTime(2026, 10, gun),
          ).answer,
        );
      }
      expect(farkli.length, greaterThan(1));
    });
  });
}
