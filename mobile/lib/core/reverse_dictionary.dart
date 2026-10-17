// ============================================================================
//  TERSİ SÖZLÜK — Faz 2, Katman A (çevrimdışı)
//
//  Kullanıcı kelimenin adını hatırlayamadığında tanımını yazar:
//    "bir şeyin tam gerçekleşeceği sırada vazgeçme"
//  → tereddüt
//
//  Bu sürüm LLM'siz çalışır. Yöntem: tanım metinleri üzerinden BM25'e
//  benzer ağırlıklı terim eşleştirmesi.
//
//  Planın Faz 2'sinde bunun üzerine gömme vektörleri (embedding) eklenecek.
//  Sözcüksel yöntem tek başına da iyi çalışır çünkü kullanıcı zaten tanıma
//  yakın kelime seçer; embedding yalnızca "isim geçmeyen" tanımlarda fark
//  yaratır. Yani bu katman çöpe gitmez, birleşir.
// ============================================================================

library;

import 'dart:math' as math;

import 'turkish.dart';

/// Türkçede eşleşmede bilgi taşımayan sözcükler.
///
/// KARŞILAŞTIRMA KATLANMIŞ METİN ÜZERİNDEN YAPILIR: bu yüzden set
/// çalışma anında foldTurkish ile dönüştürülür. Elle 'şey' yazıp
/// 'sey' ile eşleştirmeye çalışırsak filtre sessizce çalışmaz — bu
/// hatayı test yakaladı.
const _stopWordsRaw = <String>{
  'bir', 'bu', 'şu', 'o', 'şey', 'olan', 'olur', 'için', 'gibi',
  've', 'veya', 'ile', 'olarak', 'ama', 'fakat', 'ancak', 'de', 'da', 'ki',
  'mi', 'mı', 'en', 'çok', 'daha', 'birçok', 'her', 'tüm', 'kendi', 'onun',
  'onların', 'bunun', 'şunun', 'olduğu', 'kadar', 'sonra',
  'önce', 'zaman', 'an', 'hâl', 'hal', 'var', 'yok', 'eder', 'etme',
  'yapma', 'yapan', 'veren', 'alan', 'görülen', 'bilinen',
};

final _stopWords = _stopWordsRaw.map(foldTurkish).toSet();

/// Tek bir tersi sözlük sonucu.
class ReverseHit {
  final String word;
  final String matchedDefinition;
  final double score;
  final List<String> matchedTerms;

  const ReverseHit({
    required this.word,
    required this.matchedDefinition,
    required this.score,
    required this.matchedTerms,
  });
}

/// Bir anlam kaydının indekslenmiş hâli.
class _IndexedMeaning {
  _IndexedMeaning(this.word, this.definition, Map<String, double> terms)
      : terms = terms,
        norm = terms.values.fold(0.0, (a, b) => a + b * b);

  final String word;
  final String definition;
  final Map<String, double> terms;
  final double norm;
}

class ReverseDictionary {
  final List<_IndexedMeaning> _meanings = [];
  final Map<String, double> _idf = {};

  ReverseDictionary(List<(String word, String definition)> entries) {
    final documentFreq = <String, int>{};

    for (final (word, definition) in entries) {
      final terms = _termsFor(word, definition);
      if (terms.isEmpty) continue;

      for (final t in terms.keys.toSet()) {
        documentFreq[t] = (documentFreq[t] ?? 0) + 1;
      }

      _meanings.add(_IndexedMeaning(word, definition, terms));
    }

    // IDF: nadir terimler daha değerli. "vazgeçme" > "bir şey".
    final n = _meanings.length.clamp(1, 1 << 30);
    for (final e in documentFreq.entries) {
      _idf[e.key] = math.log((n + 1) / (e.value + 0.5)) + 1;
    }
  }

  /// Bir kelime + tanımı için terim ağırlıkları.
  ///
  /// Kelimenin kendisi de dizine girer ama zayıf: kullanıcı tanımı yazarken
  /// kelimeyi kullanması beklenmez. Buna karşılık tanımın çekirdek sözcükleri
  /// ağır çeker.
  static Map<String, double> _termsFor(String word, String definition) {
    final terms = <String, double>{};

    void add(String text, double weight) {
      for (final raw in text.split(RegExp(r'[^\wğüşöçıİĞÜŞÖÇ]+'))) {
        if (raw.length < 3) continue;
        final f = foldTurkish(raw);
        if (f.length < 3 || _stopWords.contains(f)) continue;

        // Kök tahmini: "vazgeçmesi" → "vazgeçme" gibi ekleri kırp.
        final stem = _shallowStem(f);
        terms[stem] = (terms[stem] ?? 0) + weight;
      }
    }

    add(definition, 1.0);
    // Kelimenin kendisi: tanımda geçen eş anlamlıları yakalar
    for (final part in word.split(RegExp(r'\s+'))) {
      final f = foldTurkish(part);
      if (f.length >= 3) {
        terms[_shallowStem(f)] = (terms[_shallowStem(f)] ?? 0) + 0.55;
      }
    }

    return terms;
  }

  /// Yüzeysel Türkçe kök kırpma.
  ///
  /// Tam morfolojik analiz Zemberek'in işi; burada yalnızca sık çekim
  /// eklerini kırpıyoruz ki "vazgeçmesi" ile "vazgeçme" aynı terime düşsün.
  /// Fazla kırmak hata üretir, o yüzden sadece bilinen ekler denenir.
  static const _suffixes = <String>[
    'larımızdan', 'lerimizden', 'larımızdan', 'larımız', 'lerimiz',
    'masından', 'mesinden', 'ması', 'mesi', 'madan', 'meden',
    'makta', 'mekte', 'ması', 'mesi', 'mıyor', 'miyor',
    'dığı', 'diği', 'acağı', 'eceği', 'anlar', 'enler',
    'ları', 'leri', 'ları', 'ları',
    'mak', 'mek', 'lık', 'lik', 'lık',
    'dan', 'den', 'tan', 'ten',
    'da', 'de', 'ta', 'te',
    'la', 'le',
    'ın', 'in', 'un', 'ün',
    'ı', 'i', 'u', 'ü',
  ];

  static String _shallowStem(String folded) {
    // Uzun eklere önce bak, kısa ekler sona kalsın.
    final ordered = _suffixes.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final s in ordered) {
      if (folded.length - s.length >= 4 && folded.endsWith(s)) {
        return folded.substring(0, folded.length - s.length);
      }
    }
    return folded;
  }

  /// Sorguyu dizindeki anlamlarla karşılaştırır.
  ///
  /// Dönen liste skor sırasına göredir. [limit] varsayılan 8.
  List<ReverseHit> search(String phrase, {int limit = 8}) {
    final trimmed = phrase.trim();
    if (trimmed.length < 4) return const [];

    final queryTerms = <String, double>{};
    for (final raw in trimmed.split(RegExp(r'[^\wğüşöçıİĞÜŞÖÇ]+'))) {
      if (raw.length < 3) continue;
      final f = foldTurkish(raw);
      if (f.length < 3 || _stopWords.contains(f)) continue;
      final stem = _shallowStem(f);
      queryTerms[stem] = (queryTerms[stem] ?? 0) + 1;
    }

    if (queryTerms.isEmpty) return const [];

    // Sorgu normu
    var queryNorm = 0.0;
    for (final t in queryTerms.entries) {
      final idf = _idf[t.key] ?? 1.0;
      queryNorm += (t.value * idf) * (t.value * idf);
    }
    if (queryNorm == 0) return const [];
    queryNorm = math.sqrt(queryNorm);

    final hits = <ReverseHit>[];

    for (final m in _meanings) {
      var dot = 0.0;
      final matched = <String>[];

      for (final q in queryTerms.entries) {
        final weight = m.terms[q.key];
        if (weight == null) continue;

        final idf = _idf[q.key] ?? 1.0;
        dot += weight * q.value * idf * idf;
        matched.add(q.key);
      }

      if (dot == 0 || matched.isEmpty) continue;

      final mNorm = math.sqrt(m.norm);
      if (mNorm == 0) continue;

      final cosine = dot / (queryNorm * mNorm);

      // Terim kapsamı: kullanıcının yazdığı kavramların ne kadarı
      // tanımda karşılık buldu. Kapsam düşükse eşleşme tesadüfidir.
      final coverage = matched.length / queryTerms.length;

      final score = (cosine * 0.72 + coverage * 0.28).clamp(0.0, 1.0);

      // Çok zayıf eşleşmeleri göstermiyoruz — gürültü.
      if (score < 0.18) continue;

      hits.add(ReverseHit(
        word: m.word,
        matchedDefinition: m.definition,
        score: score,
        matchedTerms: matched,
      ));
    }

    hits.sort((a, b) => b.score.compareTo(a.score));

    // Aynı kelime birden çok anlamla eşleşmişse en iyisini al.
    final seen = <String>{};
    final unique = <ReverseHit>[];
    for (final h in hits) {
      if (seen.add(h.word)) unique.add(h);
      if (unique.length >= limit) break;
    }

    return unique;
  }
}