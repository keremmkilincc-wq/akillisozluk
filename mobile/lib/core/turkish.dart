// ============================================================================
//  TÜRKÇE METİN İŞLEME
//
//  Türkçe, arama motorları için dünyanın en sinir bozucu dillerinden biridir:
//
//   1. I / ı ve İ / i ayrı harflerdir. Unicode'un varsayılan toLowerCase()'i
//      'I' harfini 'i' yapar — Türkçe için YANLIŞ. Doğrusu 'ı'.
//   2. 'İ' harfinin küçük hâli 'i' DEĞİL, 'i' + birleşen nokta (U+0307).
//      String.toLowerCase() bunu ayrıştırılmış biçimde üretir ve indeks
//      karşılaştırmalarını sessizce bozar.
//   3. 'ı' harfi için i-ek düşmez: 'kitabı' → 'kitabe' DEĞİL, 'kitabı'.
//
//  Bu dosya bu kuralları tek yerde toplar.
// ============================================================================

library;

/// Türkçe kurallarına uygun küçük harfe çevirir.
///
/// Dart'ın varsayılan [String.toLowerCase] metodu Türkçe için yanlıştır:
/// `'I'.toLowerCase()` → `'i'`   (Türkçede doğrusu `'ı'`)
/// `'İ'.toLowerCase()` → `'i̇'`  (birleşik noktalı, ayrıştırılmış)
String turkishLower(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      // Latin büyük harf I → küçük harf ı  (Türkçe kuralı)
      case 0x0049: // I
        buffer.writeCharCode(0x0131); // ı
        break;
      // Latin büyük harf İ → küçük harf i  (birleşen nokta atılır)
      case 0x0130: // İ
        buffer.writeCharCode(0x0069); // i
        break;
      default:
        buffer.write(String.fromCharCode(rune).toLowerCase());
    }
  }
  return buffer.toString();
}

/// Türkçe kurallarına uygun büyük harfe çevirir.
String turkishUpper(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    switch (rune) {
      case 0x0131: // ı
        buffer.writeCharCode(0x0049); // I
        break;
      case 0x0069: // i
        buffer.writeCharCode(0x0130); // İ
        break;
      default:
        buffer.write(String.fromCharCode(rune).toUpperCase());
    }
  }
  return buffer.toString();
}

/// Tek bir harfin arama için katlanmış (folded) hâli.
///
/// Diyakritikler kaldırılır ve ı/i tek harfe indirgenir. Böylece kullanıcı
/// "kitabı" yazdığında "kitabi" da bulunur — ama "kitabe" bulunmaz, çünkü
/// bu artık bir yazım hatasıdır ve uyarı olarak gösterilir.
String foldChar(String ch) {
  switch (ch) {
    case 'ç':
    case 'Ç':
      return 'c';
    case 'ğ':
    case 'Ğ':
      return 'g';
    case 'ö':
    case 'Ö':
      return 'o';
    case 'ş':
    case 'Ş':
      return 's';
    case 'ü':
    case 'Ü':
      return 'u';
    // Düzeltme imli harfler (rûgar, âdet, îrade)
    case 'â':
    case 'Â':
      return 'a';
    case 'î':
    case 'Î':
      return 'i';
    case 'û':
    case 'Û':
      return 'u';
    case 'ı':
    case 'I':
      return 'i';
    case 'İ':
    case 'i':
      return 'i';
    default:
      return ch;
  }
}

/// Sözcüğü arama için normalize eder: küçük harf + diyakritik katlama.
String foldTurkish(String input) {
  final lowered = turkishLower(input);
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    buffer.write(foldChar(String.fromCharCode(rune)));
  }
  return buffer.toString();
}

/// Veritabanı `normalized_word` alanı için: gerçek küçük harf, diyakritik KORUNUR.
///
/// "Rüzgâr" → "rüzgâr". Bu alan dilbilimsel karşılaştırmada kullanılır,
/// katlanmış arama için değil.
String normalizeTurkish(String input) => turkishLower(input.trim());

/// Kelimenin yazımı TDK kurallarına uygun mu? (yazım denetimi — Faz 5 için)
///
/// Şimdilik kaba bir kontrol. Gerçek kural motoru `writing_rules` tablosundan
/// beslenecek; burada yalnızca en sık görülen çift yazım tuzakları yakalanır.
const _knownTraps = <String, String>{
  'milyar': 'milyar',
  'bilgiyi': 'bilgiyi', // doğru — 'bilgi' + '-yi' (Faz 5'te kural tablosundan)
  'tarihi': 'tarihî',
  'kâğıt': 'kâğıt',
  'kibrit': 'kibrit',
};

/// Sözcük yanlış yazıldıysa doğru hâlini döner, doğruysa null.
String? checkSpelling(String word) {
  final folded = foldTurkish(word);
  return _knownTraps[folded];
}

/// Türkçe hece ayrımı.
///
/// Kural basit: bir ünlüden sonra tek ünsüz geliyorsa hece ünlüde biter
/// (ki-tap, ka-dın). İki ünsüz geliyorsa birincisi önceki hecede kalır
/// (kit-ta-lar). Sertlik yalnızca üç ünsüzden sonra bir hece bırakmadığında
/// devreye girer; basit bir kuralda sert ünsüzü yumuşak saymak yanlış
/// heceleme üretir.
///
/// Çıktı: "ki-tap"
String syllabify(String word) {
  final letters = turkishLower(word).split('');
  if (letters.length < 2) return word;

  final vowels = 'aeıioöuü'.split('').toSet();
  bool isVowel(String c) => vowels.contains(c);

  final syllables = <String>[];
  var start = 0;
  var i = 0;

  while (i < letters.length) {
    if (!isVowel(letters[i])) {
      i++;
      continue;
    }

    // i: bir ünlü. Sonrasına bakalım.
    final after = i + 1;
    if (after >= letters.length) {
      // Sözcük ünlüyle bitiyor → hece burada kapanır
      syllables.add(letters.sublist(start, after).join());
      start = after;
      i = after;
      continue;
    }

    // V tek ünsüz V → hece ünlüde kapanır (ki-tap, ka-dın)
    var nextStart = after;

    // İki ünsüz üst üste mi? (VCCV → ilk ünsüz önceki hecede kalır)
    if (!isVowel(letters[after]) &&
        after + 1 < letters.length &&
        !isVowel(letters[after + 1])) {
      nextStart = after + 1;
    }

    syllables.add(letters.sublist(start, nextStart).join());
    start = nextStart;
    i = nextStart;
  }

  if (start < letters.length) {
    final tail = letters.sublist(start).join();
    if (tail.isNotEmpty) {
      if (syllables.isEmpty) {
        syllables.add(tail);
      } else {
        syllables[syllables.length - 1] += tail;
      }
    }
  }

  return syllables.where((s) => s.isNotEmpty).join('-');
}