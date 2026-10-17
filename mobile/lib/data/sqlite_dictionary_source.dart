// ============================================================================
//  SÖZLÜK VERİTABANI — TEK DOĞRU KAYNAK
//
//  Bu dosya sözlüğü JSON'dan değil, `assets/dict.db`'den okur.
//
//  Neden önemli:
//  Projede iki kaynak vardı — uygulama words_sample.json'u okuyordu,
//  veri hattı ise dict.db üretiyordu. İkisi ayrışırsa kimse fark etmez,
//  çünkü ne biri ne ötegi "doğrusu" diye işaretlenmişti. Artık dict.db tek
//  kaynak; JSON yalnızca üretim girdisi olarak duruyor.
//
//  Sıralı okuma şeması: kelimeleri oku → her kelime için anlamlarını,
//  ilişkilerini ve morfolojisini ayrı sorguyla çek (N+1 sorgu).
//  76.000 kelimeye gelindiğinde bu desenin yerini alan sorgu seti
//  (hazır JOIN'ler) yazılmalı; şimdilik 139 kelime için fazlasıyla yeterli.
// ============================================================================

library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' as svc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'; // Database, DatabaseFactory
import 'package:sqflite/sqflite.dart' as sqflite; // sqflite.databaseFactory

import 'models.dart';

/// Veritabanı sürümü — şema değiştiğinde artırılır.
const _dbAssetName = 'assets/dict.db';

class SqliteDictionarySource {
  final Database _db;
  final DatasetInfo info;

  SqliteDictionarySource._(this._db, this.info);

  /// Sözlüğü açar ve tüm içeriği belleğe alır.
  ///
  /// [factory] ve [databasePath] yalnızca testler içindir; üretimde
  /// varsayılan mobil fabrika ve varlıktan kopyalanan dosya kullanılır.
  /// Testlerin de AYNI sorgu kodundan geçmesi gerekiyor — yalnızca "asset'i
  /// nereye kopyalayayım" adımı atlanır.
  static Future<SqliteDictionarySource> open({
    DatabaseFactory? factory,
    String? databasePath,
  }) async {
    final dbFactory = factory ?? sqflite.databaseFactory;

    final target = databasePath ?? await _stageAsset();

    final db = await dbFactory.openDatabase(
      target,
      options: sqflite.OpenDatabaseOptions(readOnly: true),
    );

    final rows = await db.rawQuery('SELECT key, value FROM dataset_meta');
    final meta = <String, String>{
      for (final r in rows) r['key'] as String: r['value'] as String,
    };

    final info = DatasetInfo(
      version: meta['dataset_version'] ?? '?',
      wordCount: int.tryParse(meta['word_count'] ?? '0') ?? 0,
      meaningCount: 0,
      relationCount: 0,
      morphologyCount: 0,
      description: meta['description'] ?? '',
    );

    return SqliteDictionarySource._(db, info);
  }

  /// Varlıktaki veritabanını uygulama dizinine kopyalar.
  ///
  /// sqflite varlık içindeki dosyayı doğrudan açamaz; bir kez diske
  /// kopyalamak gerekir. 76.000 kelimeye gelindiğinde bu boyutta bir kopyalama
  /// tek seferlik bir maliyettir.
  static Future<String> _stageAsset() async {
    final dir = await getApplicationSupportDirectory();
    final target = p.join(dir.path, p.basename(_dbAssetName));

    final exists = await File(target).exists();
    if (!exists) {
      final bytes = await svc.rootBundle.load(_dbAssetName);
      await File(target).writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );
    }
    return target;
  }

  Future<void> close() => _db.close();

  /// Tüm sözlük maddelerini okur.
  Future<List<Word>> loadAll() async {
    final wordRows = await _db.query('words', orderBy: 'usage_frequency DESC');
    final words = <Word>[];
    final byId = <int, Word>{};

    // 1. Sözcükler
    for (final r in wordRows) {
      final w = Word(
        word: r['word'] as String,
        origin: r['origin'] as String? ?? 'Bilinmiyor',
        originPeriod: r['origin_period'] as String? ?? '',
        isPureTurkish: ((r['is_pure_turkish'] as int?) ?? 0) == 1,
        usageFrequency: ((r['usage_frequency'] as num?)?.toDouble()) ?? 0.5,
        confidence: ((r['confidence'] as num?)?.toDouble()) ?? 1.0,
        phonetics: r['phonetics'] as String?,
        examTags: r['exam_tags'] as String? ?? '',
        meanings: const [],
        relations: const [],
        morphology: const [],
      );
      words.add(w);
      byId[r['id'] as int] = w;
    }

    // 2. Anlamlar — tek sorguda hepsi, bellekte eşleştir
    final meaningRows = await _db.rawQuery(
      'SELECT word_id, meaning_order, word_type, sense_label, definition, '
      'example_classic, example_author, example_modern, example_note, confidence '
      'FROM meanings ORDER BY word_id, meaning_order',
    );

    final meaningsByWord = <int, List<Meaning>>{};
    for (final r in meaningRows) {
      final wid = r['word_id'] as int;
      (meaningsByWord[wid] ??= []).add(
        Meaning(
          order: r['meaning_order'] as int,
          wordType: r['word_type'] as String,
          sense: r['sense_label'] as String? ?? 'gercek',
          definition: r['definition'] as String,
          exampleClassic: r['example_classic'] as String?,
          exampleAuthor: r['example_author'] as String?,
          exampleModern: r['example_modern'] as String?,
          exampleNote: r['example_note'] as String?,
          confidence: ((r['confidence'] as num?)?.toDouble()) ?? 1.0,
        ),
      );
    }

    // 3. İlişkiler
    final relationRows = await _db.query('relations');
    final relationsByWord = <int, List<Relation>>{};
    for (final r in relationRows) {
      final wid = r['word_id'] as int;
      (relationsByWord[wid] ??= []).add(
        Relation(
          word: r['related_word'] as String,
          type: r['relation_type'] as String,
          note: r['note'] as String?,
        ),
      );
    }

    // 4. Morfoloji
    final morphRows = await _db.query('morphology');
    final morphByWord = <int, List<MorphEntry>>{};
    for (final r in morphRows) {
      final wid = r['word_id'] as int;
      (morphByWord[wid] ??= []).add(
        MorphEntry(
          surface: r['surface'] as String,
          root: r['root'] as String,
          suffixes: _decodeSuffixes(r['suffixes'] as String?),
          explanation: r['explanation'] as String? ?? '',
          note: r['note'] as String?,
        ),
      );
    }

    // 5. Birleştir
    return wordRows.map((r) {
      final id = r['id'] as int;
      return Word(
        word: byId[id]!.word,
        origin: byId[id]!.origin,
        originPeriod: byId[id]!.originPeriod,
        isPureTurkish: byId[id]!.isPureTurkish,
        usageFrequency: byId[id]!.usageFrequency,
        confidence: byId[id]!.confidence,
        phonetics: byId[id]!.phonetics,
        examTags: byId[id]!.examTags,
        meanings: List.unmodifiable(meaningsByWord[id] ?? const []),
        relations: List.unmodifiable(relationsByWord[id] ?? const []),
        morphology: List.unmodifiable(morphByWord[id] ?? const []),
      );
    }).toList();
  }

  /// Yazım kuralları — Yazım Kuralları ekranının kaynağı.
  Future<List<WritingRule>> loadWritingRules() async {
    final rows = await _db.query('writing_rules');
    return rows
        .map(
          (r) => WritingRule(
            baseWord: r['base_word'] as String,
            wrongForm: r['wrong_form'] as String,
            correctForm: r['correct_form'] as String,
            ruleType: r['rule_type'] as String,
            explanation: r['rule_explanation'] as String? ?? '',
            examTags: r['exam_tags'] as String? ?? '',
            confidence: ((r['confidence'] as num?)?.toDouble()) ?? 1.0,
          ),
        )
        .toList();
  }

  /// Kök/ek tablosundaki TÜM yüzey biçimleri ve ait oldukları sözcükler.
  ///
  /// Bunlar `words` tablosunda değildir; "kitaplarımızdan" gibi biçimler
  /// yalnızca burada durur. Arama motoru bunları aday üretiminde kullanır,
  /// ama sonuçta GERİYE sözlük kelimesine bağlanmalıdır — aksi hâlde arama
  /// "kitaplarımızdan" döndürür ve kelime detayı açılamaz.
  ///
  /// Dönüş: (yüzey biçim, bağlı olduğu sözcük)
  Future<List<(String, String)>> loadMorphologySurfaces() async {
    final rows = await _db.rawQuery(
      'SELECT m.surface AS surface, w.word AS word '
      'FROM morphology m JOIN words w ON w.id = m.word_id',
    );
    return rows
        .map((r) => (r['surface'] as String, r['word'] as String))
        .toList();
  }

  static List<String> _decodeSuffixes(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {
      // Bozuk veri: boş liste döndür, uygulamayı durdurma.
    }
    return const [];
  }
}