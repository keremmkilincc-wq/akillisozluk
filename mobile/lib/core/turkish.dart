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
        buffer.writeCharCode(rune.toLowerCase().runes.first);
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
        buffer.writeCharCode(rune.toUpperCase().runes.first);
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

/// Türkçe hece tahmini (telaffuz ipuçları için).
///
/// Türkçede hece yapısı son çekimli ünsüze göre: VCV → VCeV,
/// VCCV → VCeCV (sert ünsüzler: ç, f, h, k, p, s, ş, t; sertlik ünsüzü beklemez).
String syllabify(String word) {
  final letters = turkishLower(word).split('');
  if (letters.length < 2) return word;

  const hard = {'f', 'h', 'k', 'p', 's', 'ş', 'ç', 't'};
  const soft = {'b', 'c', 'd', 'g', 'ğ', 'j', 'l', 'm', 'n', 'r', 's', 'v', 'z'};

  final vowels = 'aeıioöuü'.split('').toSet();
  final isVowel = (String c) => vowels.contains(c);

  final syllables = <String>[];
  var current = '';

  for (var i = 0; i < letters.length; i++) {
    current += letters[i];
    final nextIsLast = i == letters.length - 1;
    if (nextIsLast) break;

    final next = letters[i + 1];
    final nextNext = i + 2 < letters.length ? letters[i + 2] : null;

    // Ünsüz çifti: araya ünlü girer (VCCV → VCeCV)
    if (!isVowel(next) && nextNext != null) {
      if (isVowel(nextNext)) {
        // sert ünsüzse bölme, yumuşak ünsüzse böl
        if (!hard.contains(next)) {
          syllables.add(current);
          current = '';
        }
      }
      continue;
    }

    // Ünsüz + ünlü: sert ünsüz ünlüyü çeker, yumuşak bırakır (VCV → VCeV)
    if (!isVowel(next) && i + 2 < letters.length) {
      final after = letters[i + 2];
      if (isVowel(after)) {
        if (hard.contains(next)) {
          syllables.add(current);
          current = '';
        } else if (soft.contains(next)) {
          // yumuşak ünsüz: sonraki ünlü yeni heceyi başlatır
          syllables.add(current);
          current = '';
        }
      }
    }
  }

  if (current.isNotEmpty) syllables.add(current);
  return syllables.where((s) => s.isNotEmpty).join('-');
}