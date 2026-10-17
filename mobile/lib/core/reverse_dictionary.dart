// ============================================================================
//  TERSİ SÖZLÜK — Faz 2, Katman A (çevrimdışı)
//
//  Kullanıcı kelimenin adını hatırlayamadığında tanımını yazar:
//    "suyun biriktiği geniş çukur"
//  → göl
//
//  Bu örnek ÖLÇÜLMÜŞTÜR: bu sürümde gerçekten ilk sonuç "göl"dür
//  (test/reverse_rank_test.dart). Başta burada "tereddüt" vardı — ekrandaki
//  örneklerle aynı tuzağa düşmüştüm: tereddüt bu sözlükte KESİNLİKLE
//  tanımsız, yani örnek vaat ettiği şeyi veremeyecekti. Sözlükte olmayan
//  ya da tanımsız bir kelimeyi örnek seçmek, özelliğin ne yapamayacağını
//  gizlemekten başka işe yaramıyor.
//
//  Bu sürüm LLM'siz çalışır. Yöntem: tanım metinleri üzerinden IDF ağırlıklı
//  terim eşleştirmesi, kosinüs benzerliğiyle normalize edilmiş hâli.
//
//  Planın Faz 2'sinde bunun üzerine gömme vektörleri (embedding) eklenecek.
//  Sözcüksel yöntem tek başına da iyi çalışır çünkü kullanıcı zaten tanıma
//  yakın kelime seçer; embedding yalnızca "isim geçmeyen" tanımlarda fark
//  yaratır. Yani bu katman çöpe gitmez, birleşir.
//
// ---------------------------------------------------------------------------
//  ÖLÇÜLEN DURUM — 26 soruluk küme (test/reverse_rank_test.dart)
//
//      düzeltmelerden önce     ilk  8/26    ilk3 13/26
//      düzeltmelerden sonra    ilk 12/26    ilk3 15/26
//      parti 003 verisiyle     ilk 11/26    ilk3 15/26
//
//  Üçüncü satır bir regresyon değil, ölçümün çalıştığının kanıtı: 67 yeni
//  tanım bazı eşleşmelerin ayrımını bozdu. Tek vaka, 26 soruluk kümede
//  gürültü sınırında. Kademeli veri yazımı, ölçümsüz ilerlemeyi bozuyor —
//  her partiden sonra bu tablo yeniden okunmalı.
//
//  Kalan hataların çoğu kavramsal boşluk. Sınırların hepsi test dosyasında
//  açıkça yazılı; uydurma bir başarı oranı yok.
//
// ---------------------------------------------------------------------------
//  DÜZELTME 1 — norm hatası, en ciddisi (ölçülmüş)
//
//  Sıralama bozuktu ve sebebi tahmin değil ÖLÇÜMle bulundu. Tanılama şunu
//  bastı:
//
//      Atölyede çalışıp bir şey üretmek
//        iş      skor=1.000  cos=2.935
//        ekmek   skor=1.000  cos=1.465
//        atölye  skor=0.747  cos=0.908
//
//  kos=2.935 İMKANSIZ. Kosinüs benzerliğinin üst sınırı 1'dir. Demek ki
//  ölçüm değil, formül bozuk:
//
//    dot       = Σ ( belge_agirligi · sorgu_agirligi · idf · idf )
//    sorguNorm = √ Σ ( sorgu_agirligi · idf )²
//    belgeNorm = √ Σ ( belge_agirligi )²        <-- idf YOK
//
//  Nokta çarpımının BELGE tarafı idf² ile ağırlıklandırılıyordu ama belgenin
//  normu idf'siz alınıyordu. İki taraf farklı ölçekteydi; sonuç bire bir
//  kosinüs değil, 1'i aşan keyfî bir büyüklüktü. Karşılaştırılamaz olduğu
//  için de .clamp() hepsini 1.000'a yapıyor, sıralama keyfîleşiyor ve
//  Dart'ın kararsız sort'u belgedeki ilk eşleşmeyi öne getiriyordu — yani
//  "iş" sadece listede daha önce geçtiği için kazanıyordu, ANLAMI yüzünden
//  değil.
//
//  Düzeltme: belge normu da IDF ağırlıklı. İki taraf aynı ölçekte, kosinüs
//  gerçekten [0,1] ve sıralama anlamlı.
//
//  DÜZELTME 2 — kapsam (coverage) sayımı değil ağırlık oldu. Önceki hâlde
//  bir tanım "bulunan" gibi jenerik bir terimi bulduğunda, "kaygı" gibi
//  nadir bir terimi bulan tanımla aynı sayılıyordu.
//
//  DÜZELTME 3 — sıralama eşitlikte keyfîydi. Dart'ın List.sort'u kararsız
//  (küçük listelerde insertion sort, büyüklerde dual-pivot quicksort).
//  Skor eşitse ikincil ölçüt eşleşen terim sayısı, üçüncül ölçüt alfabetik
//  sıra. Aynı sorgu her zaman aynı listeyi vermeli.
//
//  DÜZELTME 4 — zincirleme gövde kırpma. Tek seferde tek ek kırpılıyordu;
//  ekler zincir hâlinde gelir (-ler + -de + -i) ve kırpma ortada duruyordu.
//  Ayrıntı _shallowStem'de.
//
//  DÜZELTME 5 — elle yazılmış eşanlamlı köprüsü (turkish_synonyms.dart).
//  İlk sıra doğruluğunu 8'den 11'e çıkardı. Kapsamı sınırlı, bkz. o dosya.
// ============================================================================

library;

import 'dart:math' as math;

import 'turkish.dart';
import 'turkish_synonyms.dart';

/// Türkçede eşleşmede bilgi taşımayan sözcükler.
///
/// KARŞILAŞTIRMA KATLANMIŞ METİN ÜZERİNDEN YAPILIR: bu yüzden set
/// çalışma anında foldTurkish ile dönüştürülür. Elle 'şey' yazıp
/// 'sey' ile eşleştirmeye çalışırsak filtre sessizce çalışmaz — bu
/// hatayı test yakaladı.
///
/// İKİ AYRI KÜME VAR VE FARK NEDEN ÖNEMLİ:
///
/// * [_functionWords] — dilin bağlaç/zarf/eylem takıları. Bunlar hiçbir
///   tanımı ayırt etmez, ama hepsinde bulunur.
/// * [_definitionMeta] — SÖZLÜKÇÜYE AİT, DİLİN DEĞİL. "anlamında",
///   "deyimi", "şekilde", "edilen" gibi sözcükler bir kelimenin NE
///   olduğunu anlatmaz, tanımın NASIL yazıldığını anlatır. Bunlar her
///   tanımda geçtiği için ayırt edici güçleri sıfırdır; sıralamada
///   jenerik sözcük gibi davranırlar.
///
/// Kural: buraya yalnızca "bir tanımı diğerinden ayırt etmeye yaramaz"
/// dediğimiz sözcük girer. "büyük", "küçük", "iyi", "kötü", "yer", "iş"
/// GİRMEZ — onlar gerçek anlam taşıyor ve anlam taşıdıkları için
/// kullanılmalı. (Sözcük listesini gözle genişletmek yerine ölçümle
/// daraltıp genişletmek gerekir; _diag ölçümüyle doğrulandı.)
const _functionWordsRaw = <String>{
  'bir', 'bu', 'şu', 'o', 'şey', 'olan', 'olur', 'için', 'gibi',
  've', 'veya', 'ile', 'olarak', 'ama', 'fakat', 'ancak', 'de', 'da', 'ki',
  'mi', 'mı', 'en', 'çok', 'daha', 'birçok', 'her', 'tüm', 'kendi', 'onun',
  'onların', 'bunun', 'şunun', 'olduğu', 'kadar', 'sonra',
  'önce', 'zaman', 'an', 'hâl', 'hal', 'var', 'yok', 'eder', 'etme',
  'yapma', 'yapan', 'veren', 'alan', 'görülen', 'bilinen',
  // Dönüşlü zamirler: "birbirini anlamak" cümlesindeki "birbirini"
  // bilgi taşımıyor. SİLİNMEDEN ÖNCE ÖLÇÜLDÜ: "birbirini" sorgusu
  // "zaman" ve "arkadaş" tanımlarını "birbirini izleme", "birbirini
  // tanıyan" kalıplarından yanlışlıkla yakalıyordu.
  'birbiri', 'birbirini', 'birbirine', 'birbiriyle', 'birbirlerini',
  'kendisi', 'kendisine', 'kendisini', 'kendinde', 'kendine', 'kendini',
  'kendileri', 'kendilerine', 'kendilerini', 'kendim', 'kendimi',
  'benim', 'sana', 'bana', 'senin', 'bizim', 'sizin', 'onlar',
  'beni', 'seni', 'bizi', 'sizi', 'ona',
};

const _definitionMetaRaw = <String>{
  // Tanımın kendisine dair sözcükler
  'anlam', 'anlamda', 'anlamında', 'anlamı', 'deyim', 'deyimi', 'atasozu',
  'terim', 'isim', 'sıfat', 'fiil', 'zarf', 'mecaz', 'gerçek', 'gercek',
  'tanım', 'tanımı',
  // Biçim belirteçleri
  'şekilde', 'şeklinde', 'biçim', 'biçimde', 'biçimi', 'tip', 'tür', 'türü',
  // Fiilleştirici kalıplar: "X edilen Y", "X olan Z"
  'eden', 'edilen', 'edilir', 'edilmesi', 'olduğu', 'olmak', 'olması',
  'bulunan', 'bulunur', 'içeren', 'içine', 'içerir', 'kullanılan',
  'kullanılır', 'kullanmak', 'denen', 'sayılan', 'sayılır', 'denir',
  'kastedilir', 'oluşan', 'olusturan', 'ortaya',
  // Zaman/kişi kalıpları
  'eskir', 'eskice', 'eskimiş', 'eskiden', 'yaygın', 'genellikle',
  'özellikle', 'çoğunlukla', 'genelde', 'ara', 'arasında', 'boyunca',
  'hakkında', 'göre', 'kadar',
};

final _stopWords = <String>{
  ..._functionWordsRaw.map(foldTurkish),
  ..._definitionMetaRaw.map(foldTurkish),
};

/// Eşanlamlı köprüsünün ağırlığı.
///
/// 1.0'ın altında, çünkü eşanlamlı henüz KANIT değil. Kullanıcı "varak"
/// dediğinde "yaprak"la eşleştirmek yardımcıdır ama tanımların büyük
/// kısmı doğrudan kelime örtüşmesiyle bulunur. 1.0 olsaydı eşanlamlı
/// eşleşmesi, gerçek kelime örtüşmesinden daha ağır basardı.
const _synonymWeight = 0.40;

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
///
/// [weighted] IDF ile çarpılmış terim ağırlıklarıdır; [norm] de aynı
/// ağırlıklarla hesaplanır. İkisi AYNI ölçekte olmak zorunda — değilse
/// kosinüs 1'i aşar ve sıralama çöker (dosya başındaki kayıt).
class _IndexedMeaning {
  _IndexedMeaning(this.word, this.definition, this.weighted)
      : norm = math.sqrt(
          weighted.values.fold<double>(0, (a, b) => a + b * b),
        );

  final String word;
  final String definition;
  final Map<String, double> weighted;
  final double norm;
}

class ReverseDictionary {
  final List<_IndexedMeaning> _meanings = [];
  final Map<String, double> _idf = {};

  /// Gövde → eşanlamlı gövdeler.
  ///
  /// Anahtarlar burada, kendi gövde kırpıcımızla kırpılıp haritalanıyor.
  /// Kırpma yapılmadan harita kurulursa anahtarlar hiç eşleşmiyor ve
  /// katman sessizce hiç iş yapmıyor — ilk denemede olan buydu.
  late final Map<String, List<String>> _synonyms = _buildSynonyms();

  Map<String, List<String>> _buildSynonyms() {
    final out = <String, List<String>>{};

    for (final group in turkishSynonymGroups) {
      final anahtar = _shallowStem(foldTurkish(group.first));
      if (anahtar.length < 3) continue;

      for (final yuzey in group.skip(1)) {
        final g = _shallowStem(foldTurkish(yuzey.trim()));
        if (g.length < 3 || g == anahtar) continue;

        final liste = out.putIfAbsent(anahtar, () => <String>[]);
        if (!liste.contains(g)) liste.add(g);
      }
    }

    return out;
  }

  ReverseDictionary(List<(String word, String definition)> entries) {
    // 1. GEÇİŞ — ham terim ağırlıklarını ve belge sıklıklarını topla.
    //    Kelime/tanım çifti TERİM HARİTASIYLA BİRLİKTE saklanıyor. İkisi
    //    ayrı listelerde tutulsaydı, terimi boş çıkan bir girdi
    //    skip edilince bundan sonraki tüm eşleşmeler bir kayar ve kelime
    //    yanlış tanımla gösterilirdi. Sessiz ve inandırıcı bir hata.
    final raw = <((String, String), Map<String, double>)>[];
    final documentFreq = <String, int>{};

    for (final (word, definition) in entries) {
      final terms = _termsFor(word, definition);
      if (terms.isEmpty) continue;

      for (final t in terms.keys.toSet()) {
        documentFreq[t] = (documentFreq[t] ?? 0) + 1;
      }
      raw.add(((word, definition), terms));
    }

    // 2. IDF — BM25 yumuşatması. Klasik log((N-df+0.5)/(df+0.5)) negatif
    //    IDF üretir (df > N/2 olan terimlerde) ve kesme işi gerekir; burada
    //    daima pozitif kalan log(1 + ...) varyantı kullanılıyor.
    final n = raw.length.clamp(1, 1 << 30);
    for (final e in documentFreq.entries) {
      _idf[e.key] = math.log(1 + (n - e.value + 0.5) / (e.value + 0.5)) + 1;
    }

    // 3. GEÇİŞ — ağırlıkları IDF ile çarp ve belgeleri kur. Norm da bu
    //    çarpılmış ağırlıklardan alınır; iki taraf ölçek olarak eşitlenir.
    for (final ((word, definition), terms) in raw) {
      final weighted = <String, double>{};
      for (final e in terms.entries) {
        weighted[e.key] = e.value * (_idf[e.key] ?? 1.0);
      }
      _meanings.add(_IndexedMeaning(word, definition, weighted));
    }
  }

  /// Bir kelime + tanımı için terim ağırlıkları.
  ///
  /// Kelimenin kendisi de dizine girer ama zayıf: kullanıcı tanımı yazarken
  /// kelimeyi kullanması beklenmez. Buna karşılık tanımın çekirdek sözcükleri
  /// ağır çeker.
  Map<String, double> _termsFor(String word, String definition) {
    final terms = <String, double>{};

    void add(String text, double weight) {
      for (final raw in text.split(RegExp(r'[^\wğüşöçıİĞÜŞÖÇ]+'))) {
        if (raw.length < 3) continue;
        final f = foldTurkish(raw);
        if (f.length < 3 || _stopWords.contains(f)) continue;

        // Kök tahmini: "vazgeçmesi" → "vazgeçme" gibi ekleri kırp.
        final stem = _shallowStem(f);
        terms[stem] = (terms[stem] ?? 0) + weight;

        // Eşanlamlı köprüsü: kullanıcı "anlamak" yazıp tanım "kavramak"
        // dediğinde iki taraf da aynı köprüden geçiyor. Ağırlık düşük
        // tutuluyor — eşanlamlı HENÜZ kanıt değil, ipucu.
        for (final syn in _synonyms[stem] ?? const <String>[]) {
          terms[syn] = (terms[syn] ?? 0) + weight * _synonymWeight;
        }
      }
    }

    add(definition, 1.0);
    // Kelimenin kendisi: tanımda geçen eş anlamlıları yakalar
    for (final part in word.split(RegExp(r'\s+'))) {
      final f = foldTurkish(part);
      if (f.length >= 3) {
        final s = _shallowStem(f);
        terms[s] = (terms[s] ?? 0) + 0.55;
        for (final syn in _synonyms[s] ?? const <String>[]) {
          terms[syn] = (terms[syn] ?? 0) + 0.55 * _synonymWeight;
        }
      }
    }

    return terms;
  }

  /// Yüzeysel Türkçe kök kırpma — ZİNCİRLİ.
  ///
  /// Tam morfolojik analiz Zemberek'in işi ve bu projede kullanılamıyor
  /// (bkz. docs/VERI-PLANI.md). Burada amaç tam gövde değil, iki yüzeyin
  /// AYNI gövdeye düşmesini sağlamak.
  ///
  /// NEDEN ZİNCİR: önceki sürüm tek seferde tek ek kırpıyordu ve şu
  /// ikisini eşleştiremiyordu:
  ///
  ///     "işleri"  ->  "isler"      (ek: -leri)
  ///     "işi"     ->  "isi"        (ek: -i, ama 3-1 < 4 koruması atladı)
  ///
  /// Sonuç: kullanıcı "el işi yapan yer" yazdığında "iş" geçmiyordu.
  /// Ekler zincir hâlinde gelir (-ler + -de + -i); tek tek kırpma zincirin
  /// ortasında durur.
  ///
  /// KORUMA: gövde 3 harften kısa kalıyorsa kırpma durur. Bu eşik
  /// ölçülerek kondu — 2'ye düşürmek kısa gövdelerde yanlış eşleşme
  /// üretiyor.
  ///
  /// ALTERNATİF (denenmedi): her terim için birden çok gövde üretip
  /// kesişimi aramak. Dizini büyüttüğü için tek-gövde yaklaşımı
  /// tercih edildi; doğruluğu ayrıca ölçülmedi.
  static const _suffixes = <String>[
    // Uzun ve zincirleşmiş kalıplar önce
    'larımızdan', 'lerimizden', 'larından', 'lerinden', 'larımız', 'lerimiz',
    'larına', 'lerine', 'larda', 'lerde', 'lardan', 'lerden',
    'masından', 'mesinden', 'masında', 'mesinde', 'ması', 'mesi',
    'madan', 'meden', 'makta', 'mekte',
    'mış', 'miş', 'mu', 'mü',
    'nın', 'nin', 'nun', 'nün',
    'dığı', 'diği', 'duğu', 'düğü', 'acağı', 'eceği',
    'anlar', 'enler', 'ları', 'leri',
    'mak', 'mek',
    'lık', 'lik', 'luk', 'lük',
    'cı', 'ci', 'cu', 'cü', 'çı', 'çi', 'çu', 'çü',
    'lı', 'li', 'lu', 'lü',
    'sız', 'siz', 'suz', 'süz',
    'sı', 'si', 'su', 'sü',
    'da', 'de', 'ta', 'te',
    'dan', 'den', 'tan', 'ten',
    'la', 'le', 'ya', 'ye',
    'ın', 'in', 'un', 'ün',
    'a', 'e',
    'ı', 'i', 'u', 'ü',
    'n',
  ];

  /// Uzun ek önce denensin diye bir kez sıralanır.
  static final List<String> _suffixesByLength =
      _suffixes.toList()..sort((a, b) => b.length.compareTo(a.length));

  static const _minStem = 3;
  static const _maxRounds = 3;

  static String _shallowStem(String folded) {
    var cur = folded;

    for (var round = 0; round < _maxRounds; round++) {
      String? cut;
      for (final s in _suffixesByLength) {
        if (cur.length - s.length >= _minStem && cur.endsWith(s)) {
          cut = s;
          break;
        }
      }
      if (cut == null) break;
      cur = cur.substring(0, cur.length - cut.length);
    }

    return cur;
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

      // Sorgu tarafı da köprüden geçiyor. Sadece belge tarafı genişletilseydi
      // kullanıcının yazdığı yeni kavram hiçbir belgeye bağlanamazdı.
      for (final syn in _synonyms[stem] ?? const <String>[]) {
        queryTerms[syn] = (queryTerms[syn] ?? 0) + _synonymWeight;
      }
    }

    if (queryTerms.isEmpty) return const [];

    // Sorgu vektörü: aynı anda hem nokta çarpımı hem norm için kullanılır.
    final qw = <String, double>{};
    var queryNorm = 0.0;
    for (final t in queryTerms.entries) {
      final v = t.value * (_idf[t.key] ?? 1.0);
      qw[t.key] = v;
      queryNorm += v * v;
    }
    if (queryNorm == 0) return const [];
    queryNorm = math.sqrt(queryNorm);

    // Kapsam payı: IDF ağırlıklı terim toplamı. Sayı değil ağırlık, çünkü
    // "yer" ile "kaygı" eşit değildir.
    var queryMass = 0.0;
    for (final t in queryTerms.keys) {
      queryMass += _idf[t] ?? 1.0;
    }
    if (queryMass == 0) return const [];

    final hits = <ReverseHit>[];

    for (final m in _meanings) {
      var dot = 0.0;
      var matchedMass = 0.0;
      final matched = <String>[];

      for (final q in queryTerms.keys) {
        final w = m.weighted[q];
        if (w == null) continue;
        dot += w * qw[q]!;
        matchedMass += _idf[q] ?? 1.0;
        matched.add(q);
      }

      if (dot == 0 || matched.isEmpty) continue;
      if (m.norm == 0) continue;

      // Artık gerçekten kosinüs: her iki taraf IDF ağırlıklı olduğu için
      // sonuç [0, 1] aralığındadır. clamp() bir güvenlik ağı, düzeltme değil.
      final cosine = dot / (queryNorm * m.norm);

      // Terim kapsamı: kullanıcının yazdığı kavramların ne kadarı
      // tanımda karşılık buldu. Kapsam düşükse eşleşme tesadüfidir.
      final coverage = matchedMass / queryMass;

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

    // Skor eşitse sıra keyfî olmamalı: aynı sorgu her zaman aynı listeyi
    // vermek zorunda. Dart'ın List.sort'u kararsızdır (küçük listelerde
    // insertion sort, büyüklerde dual-pivot quicksort); bu yüzden ikincil
    // ve üçüncül ölçütler açıkça yazılıyor.
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byMatched = b.matchedTerms.length.compareTo(a.matchedTerms.length);
      if (byMatched != 0) return byMatched;
      return a.word.compareTo(b.word);
    });

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
