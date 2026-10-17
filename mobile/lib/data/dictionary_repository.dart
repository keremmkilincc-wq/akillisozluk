// ============================================================================
//  SÖZLÜK DEPOSU
//
//  Tek kaynak: assets/dict.db  (üreten: tools/build_dict.py)
//
//  Geçmiş: depo bir süre JSON varlığından okuyordu, veri hattı ise SQLite'a
//  yazıyordu. İki kaynak ayrışabiliyordu ve ayrıştığında kimse fark etmiyordu.
//  Artık JSON yalnızca üretim girdisidir; uygulama onu görmez.
// ============================================================================

library;

import 'dart:math';

import 'package:flutter/material.dart' show ChangeNotifier;
import 'package:sqflite/sqflite.dart' show DatabaseFactory;

import '../core/reverse_dictionary.dart';
import '../core/search.dart';
import '../core/turkish.dart';
import 'models.dart';
import 'sqlite_dictionary_source.dart';

class DictionaryRepository extends ChangeNotifier {
  final List<Word> _words = [];
  final Map<String, Word> _byWord = {};
  final List<WritingRule> _rules = [];

  /// Morfolojik yüzey biçim → bağlı olduğu sözlük kelimesi.
  /// "kitaplarımızdan" → "kitap"
  final Map<String, String> _surfaceToWord = {};

  late final DatasetInfo _info;
  late final FuzzySearch _search;
  late final ReverseDictionary _reverse;
  late final List<String> _roots;

  SqliteDictionarySource? _source;

  List<Word> get all => List.unmodifiable(_words);
  DatasetInfo get info => _info;
  int get size => _words.length;

  /// [factory] ve [databasePath] yalnızca testler içindir. Üretimde
  /// mobil fabrika ve varlıktan kopyalanan dosya kullanılır.
  ///
  /// Testlerin de AYNI SQLite yolundan geçmesi gerekiyor; JSON'dan okumak
  /// gerçek davranışı test etmezdi — üretim hattı dict.db'ye yazıyor.
  Future<void> load({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    if (_words.isNotEmpty) return;

    final source = await SqliteDictionarySource.open(
      factory: factory,
      databasePath: databasePath,
    );
    _source = source;

    _info = source.info;
    _rules.addAll(await source.loadWritingRules());

    final loaded = await source.loadAll();
    _words.addAll(loaded);
    for (final w in loaded) {
      _byWord[w.word.toLowerCase()] = w;
    }

    // Arama için bütün morfolojik yüzeyler de dahil edilir: kullanıcı
    // "kitaplarımızdan" yazdığında arama "kitap"a ulaşabilsin.
    //
    // Yüzey → sözlük kelimesi eşlemesi şart: "kitaplarımızdan" bir sözlük
    // maddesi değildir. Bu eşleme olmadan arama biçimi döndürür ama detay
    // sayfası açılamaz.
    final surfaces = <String>{};
    final surfaceToWord = <String, String>{};

    for (final w in loaded) {
      surfaces.add(w.word);
      for (final m in w.morphology) {
        surfaces.add(m.surface);
        surfaceToWord[m.surface] = w.word;
      }
    }

    for (final (surface, word) in await source.loadMorphologySurfaces()) {
      surfaces.add(surface);
      surfaceToWord.putIfAbsent(surface, () => word);
    }

    _surfaceToWord.addAll(surfaceToWord);
    _search = FuzzySearch(surfaces.toList());

    // Tersi sözlük: bir kelimenin birden çok anlamı olduğu için her anlam
    // ayrı kayıttır.
    final reverseEntries = <(String, String)>[];
    for (final w in _words) {
      for (final m in w.meanings) {
        reverseEntries.add((w.word, m.definition));
      }
    }
    _reverse = ReverseDictionary(reverseEntries);

    _roots = _words.map((w) => w.root).whereType<String>().toList()..sort();
  }

  @override
  void dispose() {
    _source?.close();
    super.dispose();
  }

  Word? lookup(String word) => _byWord[word.toLowerCase()];

  /// Tanımı YAZILMIŞ kelimeler.
  ///
  /// Gövde 58.809 madde ama tanımlı olan 139. İkisini ayırmak zorunluydu:
  /// "tüm kelimeleri ekle" ile "her kelimenin tanımı var" aynı şey değil.
  List<Word> get _defined =>
      _words.where((w) => w.hasDefinition).toList(growable: false);

  /// Günün kelimesi: gün sayısına göre tohumlanır, böylece herkes aynı
  /// kelimeyi görür ve cihaz çevrimdışıyken de tutarlıdır.
  ///
  /// YALNIZCA tanımı yazılmış kelimeler arasından seçer.
  ///
  /// Bu kural bir hatanın sonucu eklendi: 139 kelimeyle çalışırken her
  /// kelimenin anlamı vardı ve liste.index yeterdi. Gövde 58.809'a çıkınca
  /// günün kelimesi tanımsız bir maddeye denk geldi ve ana ekran
  /// `meanings.first` deyince çöktü.
  ///
  /// Ders: "her zaman bir anlamı vardı" sessiz bir varsayımdı; 139'da
  /// doğruydu, 58.000'de değil. Varsayım ölçekle birlikte kırılır.
  Word wordOfTheDay(DateTime date) {
    final pool = _defined;
    if (pool.isEmpty) return _words.first;
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return pool[seed % pool.length];
  }

  /// Rastgele kelime — yalnızca tanımı yazılmış olanlardan.
  Word? randomDefinedWord() {
    final pool = _defined;
    if (pool.isEmpty) return null;
    return pool[Random().nextInt(pool.length)];
  }

  int get definedCount => _words.where((w) => w.hasDefinition).length;
  int get pendingCount => _words.length - definedCount;

  List<Word> byExam(String tag) =>
      _words.where((w) => w.examList.contains(tag)).toList();

  List<Word> pureTurkish() => _words.where((w) => w.isPureTurkish).toList();

  List<String> get allRoots => List.unmodifiable(_roots);

  ({List<SearchHit> results, List<SearchHit> suggestions}) search(String query) {
    final raw = _search.search(query, _roots);

    // Morfolojik biçimleri köklerine indir. Kullanıcı "kitaplarımızdan"
    // yazdığında sonuç "kitap" olmalı — biçimin kendisi bir sözlük maddesi
    // değildir ve detay sayfası açılamaz.
    SearchHit resolve(SearchHit hit) {
      final target = _surfaceToWord[hit.word];
      if (target == null || target == hit.word) return hit;
      return SearchHit(
        word: target,
        kind: hit.kind,
        score: hit.score,
        matchedOn: hit.word,
      );
    }

    return (
      results: raw.results.map(resolve).toList(),
      suggestions: raw.suggestions.map(resolve).toList(),
    );
  }

  /// Yazım uyarıları: kullanıcının yazdığı hataya göre uygun kural.
  List<WritingRule> rulesForTypedWord(String typed) {
    final folded = foldTurkish(typed);
    return _rules
        .where((r) =>
            foldTurkish(r.wrongForm).contains(folded) ||
            foldTurkish(r.correctForm).contains(folded) ||
            foldTurkish(r.baseWord) == folded)
        .toList();
  }

  List<WritingRule> rulesForWord(String word) {
    final folded = foldTurkish(word);
    return _rules.where((r) => foldTurkish(r.baseWord) == folded).toList();
  }

  List<WritingRule> get allRules => List.unmodifiable(_rules);

  /// Yazım hatası düzeltme denemesi. "kitabe" → "kitabı".
  String? correctSpelling(String typed) {
    final folded = foldTurkish(typed);
    for (final r in _rules) {
      if (foldTurkish(r.wrongForm) == folded) return r.correctForm;
    }
    return null;
  }

  /// Tersi sözlük: tanımdan kelime bulma (Modül 3, Katman A — çevrimdışı).
  List<ReverseHit> reverseSearch(String phrase) => _reverse.search(phrase);

  List<Word> searchByDefinition(String phrase) {
    final needle = phrase.toLowerCase();
    return _words
        .where((w) =>
            w.meanings.any((m) => m.definition.toLowerCase().contains(needle)))
        .toList();
  }
}