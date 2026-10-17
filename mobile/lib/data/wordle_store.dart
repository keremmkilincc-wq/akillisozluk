// ============================================================================
//  WORDLE VERİ KAYNAĞI
//
//  Sözcük listesi build_wordle.py ile üretilir ve DENETİLMİŞ halde gelir:
//    kaynak : data/seed/wordle_words.json  (elle yazılmış)
//    çıktı  : data/seed/wordle_clean.json  (makine denetlemiş)
//  Uygulama yalnızca denetlenmiş olanı okur.
//
//  Neden ayrı dosya: elle yazılan bir listede hata olur. Denetim kaynak
//  dosyada yapılır ama çıktı dosyası bozulmaz; her üretimde yeniden
//  denetlenir.
// ============================================================================

library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class WordleWords {
  /// Cevap olabilecekler (daha sık, daha tanınır).
  final List<String> answers;

  /// Tahmin olarak kabul edilenler.
  final List<String> pool;

  final int maxGuesses;

  const WordleWords({
    required this.answers,
    required this.pool,
    required this.maxGuesses,
  });

  bool get isUsable => answers.length >= 100 && pool.length >= 250;

  static Future<WordleWords> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/wordle_clean.json',
    );
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return WordleWords(
      answers: (j['answers'] as List<dynamic>).cast<String>(),
      pool: (j['pool'] as List<dynamic>).cast<String>(),
      maxGuesses: (j['meta'] as Map<String, dynamic>)['max_guesses'] as int? ?? 6,
    );
  }
}