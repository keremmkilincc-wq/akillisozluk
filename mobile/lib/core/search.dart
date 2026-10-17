// ============================================================================
//  ARAMA MOTORU
//
//  Katman A — aday üretimi (hızlı, seçici)
//    100.000 kelimeyi tek tek taramak istemiyoruz. Trigram benzerliği ile
//    yalnızca makul adayları öne alıyoruz.
//
//  Katman B — sıralama (kesin)
//    Damerau-Levenshtein uzaklığı hesaplanıyor. Klasik Levenshtein'in
//    YANLIŞ olduğu durumlar burada kritik:
//        "yalnış" → "yanlış"   (yer değiştirme / transpozisyon)
//        "kirbit" → "kibrit"
//        "sefer"  → "safer"
//    Levenshtein bunlara 2 ceza verir; Damerau-Levenshtein 1.
//
//  Katman C — kök/ek yönlendirme
//    "kitaplarımızdan" aranırsa önce kök bulunur, sonra ekler açıklanır.
// ============================================================================

library;

import 'turkish.dart';

/// Damerau-Levenshtein (Optimal String Alignment) uzaklığı.
///
/// [b] içinde [a]'yı bulmanın gereken en küçük düzenleme sayısı.
/// Transpozisyon (komşu iki harfin yer değiştirmesi) 1 işlem sayılır.
int damerauLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length;
  final n = b.length;

  // Girdiler katlanmış olmalı — karşılaştırma buna göre yapılır.
  final A = a.codeUnits;
  final B = b.codeUnits;

  var prevPrev = List<int>.filled(n + 1, 0);
  var prev = List<int>.filled(n + 1, 0);
  var curr = List<int>.filled(n + 1, 0);

  for (var j = 0; j <= n; j++) {
    prev[j] = j;
  }

  for (var i = 1; i <= m; i++) {
    curr[0] = i;

    for (var j = 1; j <= n; j++) {
      final cost = A[i - 1] == B[j - 1] ? 0 : 1;

      var value = <int>[
        curr[j - 1] + 1, // ekleme
        prev[j] + 1, // silme
        prev[j - 1] + cost, // değiştirme
      ];

      // Transpozisyon: a[i-2]==b[j-1] ve a[i-1]==b[j-2]
      if (i > 1 && j > 1 && A[i - 1] == B[j - 2] && A[i - 2] == B[j - 1]) {
        value.add(prevPrev[j - 2] + 1);
      }

      curr[j] = value.reduce((x, y) => x < y ? x : y);
    }

    // satır rotasyonu
    prevPrev = prev;
    prev = curr;
    curr = List<int>.filled(n + 1, 0);
  }

  return prev[n];
}

/// Jaro-Winkler benzerliği: 0.0 (hiç benzemez) … 1.0 (aynı).
///
/// Ön ekteki ortak harfleri ödüllendirir. "şöför"/"şoför" gibi
/// Türkçe yazım hatalarında iyi çalışır.
double jaroWinkler(String s1, String s2) {
  if (s1 == s2) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;

  final a = s1.codeUnits;
  final b = s2.codeUnits;
  final maxDist = (a.length > b.length ? a.length : b.length) ~/ 2 - 1;
  if (maxDist < 0) return 0.0;

  final aMatched = List<bool>.filled(a.length, false);
  final bMatched = List<bool>.filled(b.length, false);

  var matches = 0;
  for (var i = 0; i < a.length; i++) {
    final start = i - maxDist < 0 ? 0 : i - maxDist;
    final end = i + maxDist + 1 > b.length ? b.length : i + maxDist + 1;
    for (var j = start; j < end; j++) {
      if (bMatched[j] || a[i] != b[j]) continue;
      aMatched[i] = true;
      bMatched[j] = true;
      matches++;
      break;
    }
  }

  if (matches == 0) return 0.0;

  var transpositions = 0;
  var k = 0;
  for (var i = 0; i < a.length; i++) {
    if (!aMatched[i]) continue;
    while (!bMatched[k]) {
      k++;
    }
    if (a[i] != b[k]) transpositions++;
    k++;
  }
  transpositions = transpositions ~/ 2;

  final m = matches.toDouble();
  final jaro = (m / a.length + m / b.length + (m - transpositions) / m) / 3.0;

  // Winkler öneki: en fazla 4 karakter, her biri %0.1 bonus
  var prefix = 0;
  for (var i = 0; i < 4; i++) {
    if (i >= a.length || i >= b.length) break;
    if (a[i] != b[i]) break;
    prefix++;
  }

  return jaro + prefix * 0.1 * (1 - jaro);
}

/// Kelimenin trigram kümesi. 3'ten kısa sözcükler kendi kendine eklenir.
Set<String> trigrams(String input) {
  final s = foldTurkish(input);
  final out = <String>{};

  if (s.length < 3) {
    if (s.isNotEmpty) out.add(s);
    return out;
  }

  for (var i = 0; i <= s.length - 3; i++) {
    out.add(s.substring(i, i + 3));
  }
  return out;
}

/// Trigram Jaccard benzerliği.
double trigramSimilarity(String a, String b) {
  final ta = trigrams(a);
  final tb = trigrams(b);
  if (ta.isEmpty || tb.isEmpty) return 0.0;

  var intersection = 0;
  for (final t in ta) {
    if (tb.contains(t)) intersection++;
  }
  return intersection / (ta.length + tb.length - intersection);
}

/// Arama sonucunun türü.
enum MatchKind {
  /// Birebir eşleşme
  exact,

  /// Katlama sonrası birebir (kullanıcı diyakritik hatası yapmış —
  /// "şöför" katlanınca "şoför" ile aynı hâle gelir)
  spellingVariant,

  /// Kök eki ayrıldıktan sonra eşleşme ("kitaplarımızdan" → "kitap")
  root,

  /// Tanım metni içinde geçiyor
  definition,

  /// Yakın yazım — "Bunu mu demek istediniz?"
  suggestion,
}

/// Tek bir arama sonucu.
class SearchHit {
  final String word;
  final MatchKind kind;
  final double score;
  final String? matchedOn;

  const SearchHit({
    required this.word,
    required this.kind,
    required this.score,
    this.matchedOn,
  });
}

/// Arama motoru. Sözlüğü bir kez indeksler, sonra bellekten döner.
///
/// İndeksler:
///   1. Katlanmış sözcük → gerçek yazım        (tam eşleşme)
///   2. Trigram → sözcükler                     (yumuşak eşleşme)
///   3. Silme komşuluğu → sözcükler            (harf yer değişikliği)
///
/// Üçüncü indeks şart. Trigram tek başına yetmez: "kirbit" ile "kibrit"
/// yalnızca "bit" trigramını paylaşır, geri kalan üçü farklıdır. Yani
/// yazım hatası olan kullanıcı hiçbir aday bulunamaz ve motor "bulunamadı"
/// der. Silme komşuluğu ikisini de "kibit"te buluşturur.
class FuzzySearch {
  late final Map<String, String> _foldedWords;
  late final Map<String, List<String>> _trigramIndex;
  final List<String> _allWords;

  /// Silme komşuluğu indeksi.
  ///
  /// TBMLE kurulur ve 58.809 kelimede 778 ms suruyordu — uygulama acilisinin
  /// %59'u. Ama o 778 ms aciilis sirasinda hic kullanilmaz; indeks yalnizca
  /// ilk aramada ise yarar.
  ///
  /// Yani kullanicidan 778 ms saklamak yerine, onu SONRA'ya tasiyorduk.
  /// Burada yapilan: kurulum ilk aramada yapilir, sonucu onbelleklenir.
  /// Uygulama hizli acilir; ilk arama bir kez bekler.
  Map<String, Set<String>>? _deletionIndex;

  /// Indeks bu cumle ile bir kez kuruldu mu?
  bool _deletionIndexReady = false;

  /// Indeks gercekten KURULDU mu? [_deletionIndexReady] tek basina yeterli
  /// degildi: atama `if` blogunun disinda oldugu icin, indeks hic kurulmasa
  /// bile "hazir" gorunuyordu.
  bool _deletionIndexBuilt = false;

  /// Indeks kurulmadan atlandiysa nedeni. null ise sorun yok.
  String? _deletionIndexSkipReason;

  Map<String, Set<String>> _ensure() {
    if (_deletionIndexReady) return _deletionIndex!;
    _ensureDeletionIndex();
    return _deletionIndex!;
  }

  /// Silme indeksinin GERÇEKTEN kurulup kurulmadığı.
  ///
  /// [_deletionIndexReady] bunu YANLIŞ bildiriyordu: atama, `if` bloğunun
  /// DIŞINDA olduğu için indeks hiç kurulmasa da `true` dönüyordu. Yani
  /// "hazır" olan bir şey "hazır değil" diyordu. Ölçüm: 60.298 yüzeylik
  /// gerçek korpusta indeks kurulmadı ve bu bayrak yine `true` idi.
  bool get deletionIndexReady => _deletionIndexReady && _deletionIndexBuilt;

  /// İndeksin kurulmadan atlandığı neden — varsa. Testler ve ölçümler
  /// bunu okur. Sessiz bir sınır, sessiz bir ölüm demektir.
  String? get deletionIndexSkippedReason => _deletionIndexSkipReason;

  int _ensureDeletionIndex() {
    if (_deletionIndexReady) return 0;
    final started = DateTime.now();
    final index = <String, Set<String>>{};

    if (_allWords.length <= _maxWordsForDeletionIndex) {
      for (final w in _allWords) {
        final f = foldTurkish(w);
        if (f.length < _minIndexedLength || f.length > _maxIndexedLength) continue;
        for (final variant in _deletions(f)) {
          index.putIfAbsent(variant, () => <String>{}).add(w);
        }
      }
      _deletionIndexBuilt = true;
    } else {
      // SESSİZCE ATLAMAK YANLIŞTI. Bu yol bir kez çalıştı: korpus 60.298
      // yüzeye çıkınca (sınır 60.000) yazım düzeltme katmanı tamamen ve
      // fark edilmeden öldü. "kirbit" yazınca "kibrit" önerilmiyordu.
      _deletionIndexSkipReason =
          'yüzey sayısı ${_allWords.length} > sınır $_maxWordsForDeletionIndex';
      _deletionIndexBuilt = false;
    }

    _deletionIndex = index;
    _deletionIndexReady = true;
    return DateTime.now().difference(started).inMilliseconds;
  }

  /// Silme indeksine alınacak en kısa sözcük. Üç harften kısası için
  /// silme komşuluğu anlamsız: "at" için iki harf silmek, her şeyi getirir.
  static const _minIndexedLength = 3;

  /// Silme indeksine alınacak azami sözcük uzunluğu.
  ///
  /// ÖLÇÜLDÜ (58.813 kelime, masaüstü):
  ///
  ///   uzunluk 3..14   1.091 ms   +118,6 MB
  ///   uzunluk 3..10     976 ms     +5,5 MB
  ///
  /// Uzun sözcükler indekse çok sayıda varyant üretir ve bellek buna orantısız
  /// öder. 10 harften uzun sözcüklerdeki yazım hataları zaten ön ek ve
  /// trigram katmanlarıyla yakalanıyor. 14 → 10: bellek 118 MB'tan 5,5 MB'a.
  ///
  /// (Tek RSS örneği gürültülüdür; oran güvenilir, mutlak değerler az.)
  static const _maxIndexedLength = 10;

  /// Silme indeksi için sözcük sayısı sınırı.
  ///
  /// ÖLÇÜLEN KORPUS: 58.813 kelime + 1.485 morfoloji yüzeyi = 60.298.
  /// Eski sınır 60.000 idi ve aşıldığı için indeks kurulmuyordu. Sınır
  /// artık gerçek verinin çok üstünde; asıl koruma uzunluk kısıtı.
  static const _maxWordsForDeletionIndex = 200000;

  /// Indeks KURULMAZ; ilk aramada kurulur (bkz. [_ensureDeletionIndex]).
  FuzzySearch(List<String> words) : _allWords = List.unmodifiable(words) {
    _foldedWords = {};
    _trigramIndex = {};

    for (final w in words) {
      final f = foldTurkish(w);
      _foldedWords.putIfAbsent(f, () => w);

      for (final t in trigrams(w)) {
        _trigramIndex.putIfAbsent(t, () => <String>[]).add(w);
      }
    }
  }

  /// Sözcükten tek harf silerek elde edilen tüm varyantlar.
  static Set<String> _deletions(String s) {
    final out = <String>{s};
    for (var i = 0; i < s.length; i++) {
      out.add(s.substring(0, i) + s.substring(i + 1));
    }
    return out;
  }

  /// Sözlükteki toplam kelime sayısı.
  int get size => _allWords.length;

  /// Ana arama. Hem sonuç hem "bunu mu demek istediniz" önerisini döner.
  ({List<SearchHit> results, List<SearchHit> suggestions}) search(
    String query,
    List<String> knownRoots,
  ) {
    final q = query.trim();
    if (q.isEmpty) {
      return (results: <SearchHit>[], suggestions: <SearchHit>[]);
    }

    final fq = foldTurkish(q);

    // --- Katman A: aday üretimi -------------------------------------------
    final candidateWords = <String>{};

    // Tam önek — "kit" → kitap, kitabe
    for (final entry in _foldedWords.entries) {
      if (entry.key.startsWith(fq)) candidateWords.add(entry.value);
    }

    // Trigram benzerliği
    for (final t in trigrams(q)) {
      final bucket = _trigramIndex[t];
      if (bucket != null && bucket.length <= 200) {
        candidateWords.addAll(bucket);
      }
    }

    // Silme komşuluğu — harf yer değişikliği ve atlanan/eklenen harf
    if (fq.length >= 3 && fq.length <= _maxIndexedLength) {
      // Indeks ilk aramada kurulur; aciilis maliyetini oteye atar.
      final deletionIndex = _ensure();
      for (final variant in _deletions(fq)) {
        final bucket = deletionIndex[variant];
        if (bucket != null) candidateWords.addAll(bucket);
      }
    }

    // Kök eşleşmesi: "kitaplarımızdan" → "kitap"
    final fRoot = foldTurkish(knownRoots.isEmpty ? '' : knownRoots.first);
    if (fRoot.isNotEmpty && _foldedWords.containsKey(fRoot)) {
      candidateWords.add(_foldedWords[fRoot]!);
    }

    // --- Katman B: sıralama ------------------------------------------------
    final results = <SearchHit>[];
    final suggestions = <SearchHit>[];

    for (final word in candidateWords) {
      final fw = foldTurkish(word);

      // Katlanmış hâlleri aynı. Gerçek yazımlar farklı mı?
      if (fw == fq) {
        final sameSpelling = turkishLower(word) == turkishLower(q);
        results.add(
          SearchHit(
            word: word,
            kind: sameSpelling ? MatchKind.exact : MatchKind.spellingVariant,
            score: sameSpelling ? 1.0 : 0.97,
          ),
        );
        continue;
      }

      // Önek
      if (fw.startsWith(fq)) {
        final score = fq.length / fw.length;
        results.add(
          SearchHit(word: word, kind: MatchKind.exact, score: 0.90 + score * 0.09),
        );
        continue;
      }

      // Yakın yazım: uzaklık + ön ek benzerliği birlikte değerlendirilir.
      final distance = damerauLevenshtein(fq, fw);
      final maxAllowed = fq.length <= 4
          ? 1
          : fq.length <= 7
              ? 2
              : 3;

      if (distance <= maxAllowed) {
        // Damerau tek başına yeterli değil: "kitap" ile "kitaba" 1 uzaklıkta
        // ama ön ek puanı bunları ayırır.
        final similarity = jaroWinkler(fq, fw);
        final adjusted = similarity * 0.75 + (1 - distance / 4) * 0.25;

        if (adjusted >= 0.70) {
          suggestions.add(
            SearchHit(
              word: word,
              kind: MatchKind.suggestion,
              score: adjusted.clamp(0.0, 1.0),
            ),
          );
        }
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    suggestions.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final uniqueSuggestions = suggestions
        .where((s) => seen.add(s.word))
        .take(3)
        .toList();

    return (results: results, suggestions: uniqueSuggestions);
  }
}