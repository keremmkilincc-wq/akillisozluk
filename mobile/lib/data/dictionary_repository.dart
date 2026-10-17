// ============================================================================
//  SÖZLÜK DEPOSU
//
//  Faz 0'da veri JSON varlığı olarak gelir ve belleğe alınır.
//  Faz 1'de aynı arayüz SQLite (dict.db) üzerinden beslenecek —
//  ekranların değişmesi gerekmeyecek, yalnızca bu sınıf değişecek.
// ============================================================================

library;

import 'dart:convert';

import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:flutter/services.dart' show rootBundle;

import '../core/reverse_dictionary.dart';
import '../core/search.dart';
import '../core/turkish.dart';
import 'models.dart';

/// [ChangeNotifier] çünkü ileride favoriler, kişisel listeler ve aralıklı
/// tekrar ilerlemesi bu sınıfın içinde yaşayacak ve arayüz bunları
/// dinleyecek.
class DictionaryRepository extends ChangeNotifier {
  final List<Word> _words = [];
  final Map<String, Word> _byWord = {};
  final List<WritingRule> _rules = [];
  late final DatasetInfo _info;
  late final FuzzySearch _search;
  late final ReverseDictionary _reverse;
  late final List<String> _roots;

  List<Word> get all => List.unmodifiable(_words);
  DatasetInfo get info => _info;
  int get size => _words.length;

  Future<void> load() async {
    if (_words.isNotEmpty) return;

    final raw = await rootBundle.loadString('assets/data/words_sample.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;

    _info = DatasetInfo.fromJson(decoded['meta'] as Map<String, dynamic>);

    for (final r in (decoded['writing_rules'] as List<dynamic>? ?? const [])) {
      _rules.add(WritingRule.fromJson(r as Map<String, dynamic>));
    }

    for (final w in (decoded['words'] as List<dynamic>)) {
      final word = Word.fromJson(w as Map<String, dynamic>);
      _words.add(word);
      _byWord[word.word.toLowerCase()] = word;
    }

    // Arama için bütün morfolojik yüzeyleri de dahil et:
    // kullanıcı "kitaplarımızdan" yazdığında arama "kitap"a ulaşabilsin.
    final surfaces = <String>{};
    for (final w in _words) {
      surfaces.add(w.word);
      for (final m in w.morphology) {
        surfaces.add(m.surface);
      }
    }

    _search = FuzzySearch(surfaces.toList());

    // Tersi sözlük dizini: kelime + anlamları. Bir kelimenin birden çok
    // anlamı olduğu için her anlam ayrı kayıt olur.
    final reverseEntries = <(String, String)>[];
    for (final w in _words) {
      for (final m in w.meanings) {
        reverseEntries.add((w.word, m.definition));
      }
    }
    _reverse = ReverseDictionary(reverseEntries);

    _roots = _words.map((w) => w.root).whereType<String>().toList()..sort();

    // Kullanım sıklığına göre azalan sırala — "günün kelimesi" buradan seçilecek.
    _words.sort((a, b) => b.usageFrequency.compareTo(a.usageFrequency));
  }

  Word? lookup(String word) => _byWord[word.toLowerCase()];

  /// Günün kelimesi: gün sayısına göre tohumlanır, böylece herkes aynı
  /// kelimeyi görür ve cihaz çevrimdışıyken de tutarlıdır.
  Word wordOfTheDay(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return _words[seed % _words.length];
  }

  /// Sınav etiketine göre kelime listesi (Modül 6).
  List<Word> byExam(String tag) =>
      _words.where((w) => w.examList.contains(tag)).toList();

  /// Öz Türkçe kelimeler (Modül 5 oyunu için).
  List<Word> pureTurkish() => _words.where((w) => w.isPureTurkish).toList();

  /// Yazım uyarıları: kullanıcının yazdığı hataya göre uygun kural.
  ///
  /// [typed] sözcüğün KATLANMIŞ hâline bakılır; çünkü kullanıcı "kitabe"
  /// yazdığında "kitap" kelimesini aramaya çalışıyor olabilir.
  List<WritingRule> rulesForTypedWord(String typed) {
    final folded = foldTurkish(typed);
    return _rules
        .where((r) =>
            foldTurkish(r.wrongForm).contains(folded) ||
            foldTurkish(r.correctForm).contains(folded) ||
            foldTurkish(r.baseWord) == folded)
        .toList();
  }

  /// Bir kelimenin gösterdiği yazım kuralları.
  List<WritingRule> rulesForWord(String word) {
    final folded = foldTurkish(word);
    return _rules
        .where((r) => foldTurkish(r.baseWord) == folded)
        .toList();
  }

  List<WritingRule> get allRules => List.unmodifiable(_rules);

  /// Yazım hatası düzeltme denemesi.
  /// "kitabe" → "kitabı" gibi. Kural eşleşmezse null döner.
  String? correctSpelling(String typed) {
    final folded = foldTurkish(typed);
    for (final r in _rules) {
      if (foldTurkish(r.wrongForm) == folded) return r.correctForm;
    }
    return null;
  }

    /// Tersi sözlük: tanımdan kelime bulma (Modül 3, Katman A — çevrimdışı).
  List<ReverseHit> reverseSearch(String phrase) =>
      _reverse.search(phrase);

  List<String> get allRoots => List.unmodifiable(_roots);

  ({List<SearchHit> results, List<SearchHit> suggestions}) search(String query) =>
      _search.search(query, _roots);

  /// Tanım metnine göre arama (basit kelime eşleşmesi).
  /// Faz 2'de gömme vektörleriyle değiştirilecek.
  List<Word> searchByDefinition(String phrase) {
    final needle = phrase.toLowerCase();
    return _words
        .where((w) =>
            w.meanings.any((m) => m.definition.toLowerCase().contains(needle)))
        .toList();
  }
}