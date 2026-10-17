// ============================================================================
//  WORDLE MOTORU — puanlama
//
//  Türkçe eklerinden dolayı tekrar harf çok yaygın: "kitap", "kapak",
//  "kavak" gibi. Wordle'ın en sık hata yapılan yeri burasıdır — tekrar
//  harf sayımı yapılmazsa bir harf fazladan yeşil görünür.
//
//  Örnek (cevap "kitap", tahmin "kapak"):
//    k: tahminin 1. konumunda var ama cevapta 2. konumda -> SARI
//    a: iki kez var, ikisi de karşılıksız                -> SARI, SARI
//    p: yok                                               -> GRI
//    a (4.): kalan sayaç bitti                            -> GRI
//
//  Sonuç: [sari, sari, gri, gri, sari]
// ============================================================================

library;

/// Bir harfin durumu.
enum LetterState {
  /// Doğru yerde.
  correct,

  /// Sözcükte var ama yanlış yerde.
  present,

  /// Sözcükte yok.
  absent,
}

/// Bir tahminin sonucu: harf başına durum + skorda kullanılan gerçek harfler.
class GuessResult {
  final String guess;
  final List<LetterState> states;
  final String revealed;

  const GuessResult(this.guess, this.states, this.revealed);

  bool get isWin =>
      states.every((s) => s == LetterState.correct) && guess.length == 5;
}

class WordleEngine {
  /// Cevap olabilecek kelimeler.
  final List<String> answers;

  /// Tahmin olarak kabul edilen kelimeler (cevaplar her zaman burada).
  final List<String> allowed;

  /// Günün cevabı.
  final String answer;

  final List<GuessResult> _history = [];

  WordleEngine({
    required this.answers,
    required this.allowed,
    required this.answer,
  });

  /// Soru sayısı.
  static const maxGuesses = 6;

  List<GuessResult> get history => List.unmodifiable(_history);
  int get guessesUsed => _history.length;
  bool get isOver => _history.isNotEmpty && _history.last.isWin
      ? true
      : _history.length >= maxGuesses;
  bool get isWon => _history.isNotEmpty && _history.last.isWin;

  /// Bugünün cevabı — gün numarasına tohumlanır.
  ///
  /// Böylece herkes aynı gün aynı kelimeyi çözer ve cihaz çevrimdışıyken de
  /// tutarlı kalır. Rastgele seçim her açılışta değişirdi.
  factory WordleEngine.forToday({
    required List<String> answers,
    required List<String> allowed,
    DateTime? now,
  }) {
    final d = now ?? DateTime.now();
    final seed = d.year * 10000 + d.month * 100 + d.day;
    return WordleEngine(
      answers: answers,
      allowed: allowed,
      answer: answers[seed % answers.length],
    );
  }

  /// Tahmin kabul edilebilir mi?
  ///
  /// Uzunluk ve harf kontrolü YETERLİ DEĞİL: kelime havuzda olmalı. Yoksa
  /// kullanıcı harflerin yeşil/sarı/gri dağılımına göre cevabı daraltır ama
  /// kelime aslında yoktur; oyunun sonu anlamsızlaşır.
  bool isAllowed(String guess) =>
      guess.length == 5 && allowed.contains(guess.toLowerCase());

  /// Tahmini puanla.
  GuessResult guess(String raw) {
    final g = raw.toLowerCase();

    // Savunma: cevap 5 harf DEĞİLSE motor indeks hatasıyla çöker.
    // Bu "olamaz" durum gerçekten oldu: deneme sırasında "sofa" 4 harfli
    // bir cevap olarak geçti ve RangeError patladı.
    //
    // Denetim (build_wordle.py) 5 harfi zaten zorunlu kılıyor, ama denetim
    // bir dosyayı doğrular; çalışma zamanı başka bir dosyadan beslenebilir.
    // Motor kendi varsayımını da korumalı.
    if (answer.length != 5 || g.length != 5) {
      throw ArgumentError(
        'Wordle 5 harfle oynanır. Cevap: "$answer" (${answer.length}), '
        'tahmin: "$g" (${g.length})',
      );
    }

    final states = List<LetterState>.filled(5, LetterState.absent);

    // 1) Önce yerinde olanlar — bu geçişte sayaç HARCANMAZ.
    //    Tersi sırada olsaydı "kitap"/"kapak" yanlış puanlanırdı.
    var remaining = <String, int>{};
    for (var i = 0; i < 5; i++) {
      if (g[i] == answer[i]) {
        states[i] = LetterState.correct;
      } else {
        remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
      }
    }

    // 2) Kalanlar: sıralı harf için sayaç kaldıysa SARI, yoksa GRI.
    for (var i = 0; i < 5; i++) {
      if (states[i] == LetterState.correct) continue;
      final ch = g[i];
      final left = remaining[ch] ?? 0;
      if (left > 0) {
        states[i] = LetterState.present;
        remaining[ch] = left - 1;
      }
    }

    final revealed = String.fromCharCodes(answer.runes);
    final result = GuessResult(g, states, revealed);
    _history.add(result);
    return result;
  }
}