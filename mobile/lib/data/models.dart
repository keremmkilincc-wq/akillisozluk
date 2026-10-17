// ============================================================================
//  VERİ MODELLERİ
//
//  data/seed/words_sample.json ile birebir eşleşir.
//  Faz 0 sonrasında SQLite'a taşınacak; model sınıfları değişmeyecek,
//  yalnızca veri kaynağı değişecek (repository katmanı).
// ============================================================================

library;

class MorphEntry {
  final String surface;
  final String root;
  final List<String> suffixes;
  final String explanation;
  final String? note;

  const MorphEntry({
    required this.surface,
    required this.root,
    required this.suffixes,
    required this.explanation,
    this.note,
  });

  factory MorphEntry.fromJson(Map<String, dynamic> j) => MorphEntry(
        surface: j['surface'] as String,
        root: j['root'] as String,
        suffixes: (j['suffixes'] as List<dynamic>? ?? const []).cast<String>(),
        explanation: j['explanation'] as String? ?? '',
        note: j['note'] as String?,
      );
}

class Relation {
  final String word;
  final String type; // synonym | antonym | derivative | related | idiom | proverb
  final String? note;

  const Relation({required this.word, required this.type, this.note});

  factory Relation.fromJson(Map<String, dynamic> j) => Relation(
        word: j['word'] as String,
        type: j['type'] as String,
        note: j['note'] as String?,
      );

  String get typeLabel {
    switch (type) {
      case 'synonym':
        return 'Eş anlamlı';
      case 'antonym':
        return 'Zıt anlamlı';
      case 'derivative':
        return 'Akraba kelime';
      case 'idiom':
        return 'Deyim';
      case 'proverb':
        return 'Atasözü';
      default:
        return 'İlgili';
    }
  }
}

class Meaning {
  final int order;
  final String wordType; // isim | fiil | sıfat | zarf | ünlem
  final String sense; // gercek | mecaz | terim | argo
  final String definition;
  final String? exampleClassic;
  final String? exampleAuthor;
  final String? exampleModern;
  final String? exampleNote;
  final double confidence;

  const Meaning({
    required this.order,
    required this.wordType,
    required this.sense,
    required this.definition,
    this.exampleClassic,
    this.exampleAuthor,
    this.exampleModern,
    this.exampleNote,
    required this.confidence,
  });

  factory Meaning.fromJson(Map<String, dynamic> j) => Meaning(
        order: (j['order'] as num).toInt(),
        wordType: j['type'] as String,
        sense: j['sense'] as String? ?? 'gercek',
        definition: j['definition'] as String,
        exampleClassic: j['example_classic'] as String?,
        exampleAuthor: j['example_author'] as String?,
        exampleModern: j['example_modern'] as String?,
        exampleNote: j['example_note'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
      );

  /// Güven eşiğinin altındaysa kullanıcıya "doğrulanmamış" olarak gösterilir.
  bool get isUnverified => confidence < 0.9;
}

/// Bir maddenin tanım durumu.
///
/// Gövde 58.809 madde; 139 tanım yazıldı, gerisi bekliyor. Bu ayrım
/// uygulamada görünür çünkü "henüz yazılmadı" ile "veri hatası" aynı
/// görünmemeli.
enum DefinitionStatus {
  /// Tanım yazıldı ve denetimden geçti.
  written,

  /// Madde var, tanımı henüz yazılmadı.
  pending,
}

class Word {
  final String word;
  final String origin;
  final String originPeriod;
  final bool isPureTurkish;
  final double usageFrequency;
  final double confidence;
  final String? phonetics;
  final String examTags;
  final DefinitionStatus definitionStatus;

  final List<Meaning> meanings;
  final List<Relation> relations;
  final List<MorphEntry> morphology;

  const Word({
    required this.word,
    required this.origin,
    required this.originPeriod,
    required this.isPureTurkish,
    required this.usageFrequency,
    required this.confidence,
    required this.phonetics,
    required this.examTags,
    required this.definitionStatus,
    required this.meanings,
    required this.relations,
    required this.morphology,
  });

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        word: j['word'] as String,
        origin: j['origin'] as String? ?? 'Bilinmiyor',
        originPeriod: j['origin_period'] as String? ?? '',
        isPureTurkish: j['is_pure_turkish'] as bool? ?? false,
        usageFrequency: (j['usage_frequency'] as num?)?.toDouble() ?? 0.5,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
        phonetics: j['phonetics'] as String?,
        examTags: j['exam_tags'] as String? ?? '',
        definitionStatus: j['definition_status'] == 'yazildi'
            ? DefinitionStatus.written
            : DefinitionStatus.pending,
        meanings: (j['meanings'] as List<dynamic>? ?? const [])
            .map((m) => Meaning.fromJson(m as Map<String, dynamic>))
            .toList(),
        relations: (j['relations'] as List<dynamic>? ?? const [])
            .map((r) => Relation.fromJson(r as Map<String, dynamic>))
            .toList(),
        morphology: (j['morphology'] as List<dynamic>? ?? const [])
            .map((m) => MorphEntry.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  String get primaryMeaning => meanings.isEmpty ? '' : meanings.first.definition;

  /// Tanım yazıldı mı?
  bool get hasDefinition => definitionStatus == DefinitionStatus.written;

  List<String> get examList =>
      examTags.isEmpty ? const [] : examTags.split(',');

  /// Bu kelimenin kökü (morfoloji kaydından).
  String? get root {
    if (morphology.isNotEmpty) return morphology.first.root;
    return null;
  }
}

/// Yazım kuralı — Modül 6'nın kalbi.
///
/// Tamamen özgündür: kural dilbilgisinden türetilir, hiçbir sözlük metni
/// kopyalanmaz. Telif riski sıfır.
class WritingRule {
  final String baseWord;
  final String wrongForm;
  final String correctForm;
  final String ruleType;
  final String explanation;
  final String examTags;
  final double confidence;

  const WritingRule({
    required this.baseWord,
    required this.wrongForm,
    required this.correctForm,
    required this.ruleType,
    required this.explanation,
    required this.examTags,
    required this.confidence,
  });

  factory WritingRule.fromJson(Map<String, dynamic> j) => WritingRule(
        baseWord: j['base_word'] as String,
        wrongForm: j['wrong_form'] as String,
        correctForm: j['correct_form'] as String,
        ruleType: j['rule_type'] as String,
        explanation: j['rule_explanation'] as String? ?? '',
        examTags: j['exam_tags'] as String? ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 1.0,
      );

  String get typeLabel {
    switch (ruleType) {
      case 'suffix_sound':
        return 'Ünsüz yumuşaması';
      case 'hard_consonant':
        return 'Ünsüz sertleşmesi';
      case 'vowel_drop':
        return 'Ünlü düşmesi';
      case 'consonant_drop':
        return 'Ünsüz düşmesi';
      default:
        return 'Yazım';
    }
  }

  List<String> get exams =>
      examTags.isEmpty ? const [] : examTags.split(',');
}

/// Uygulamanın veri seti hakkında taşıdığı bilgi.
class DatasetInfo {
  final String version;
  final int wordCount;
  final int meaningCount;
  final int relationCount;
  final int morphologyCount;
  final String description;

  const DatasetInfo({
    required this.version,
    required this.wordCount,
    required this.meaningCount,
    required this.relationCount,
    required this.morphologyCount,
    required this.description,
  });

  factory DatasetInfo.fromJson(Map<String, dynamic> j) => DatasetInfo(
        version: j['dataset_version'] as String? ?? '?',
        wordCount: (j['word_count'] as num?)?.toInt() ?? 0,
        meaningCount: (j['meaning_count'] as num?)?.toInt() ?? 0,
        relationCount: (j['relation_count'] as num?)?.toInt() ?? 0,
        morphologyCount: (j['morphology_count'] as num?)?.toInt() ?? 0,
        description: j['description'] as String? ?? '',
      );
}