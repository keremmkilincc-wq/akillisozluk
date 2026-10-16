// ============================================================================
//  TASARIM SİSTEMİ
//
//  Görsel dil: "edebî sıcaklık".
//  - Kâğıt dokusu zemin, kiremit tonu vurgu, çini yeşili ikincil.
//  - Sözcük başlıkları serif; arayüz sans-serif. İkisi arasındaki
//    kontrast, uygulamayı jenerik bir sözlük listesinden ayırır.
//  - Her renk açık ve koyu temada ayrı ayrı tanımlı — tema çalışıyor.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet kaynakları.
class _Palette {
  // Aydınlık
  static const paper = Color(0xFFFBF7F1); // sıcak kâğıt
  static const paperDim = Color(0xFFF2EBE0); // ikincil yüzey
  static const ink = Color(0xFF241F1B); // ana metin
  static const inkSoft = Color(0xFF6E635A); // ikincil metin
  static const terracotta = Color(0xFFB5533C); // vurgu — kiremit
  static const turquoise = Color(0xFF2F6B5E); // çini yeşili
  static const gold = Color(0xFFC8922F); // altın
  static const hairline = Color(0xFFE6DCCF); // çizgi

  // Karanlık
  static const night = Color(0xFF15120F);
  static const nightDim = Color(0xFF221D19);
  static const chalk = Color(0xFFF3ECE3);
  static const chalkSoft = Color(0xFFA79C92);
  static const ember = Color(0xFFE08B72); // açık temada kiremitin açığı
  static const jade = Color(0xFF7FBFB0);
  static const amber = Color(0xFFE0B458);
  static const hairlineDark = Color(0xFF332C26);
}

/// Köken (etymology) rozetlerinin renkleri — her dil ailesi kendi rengini alır.
Color originColor(String origin) {
  final o = origin.toLowerCase();
  if (o.contains('öz türk') || o.contains('türkçe')) return _Palette.terracotta;
  if (o.contains('arap')) return _Palette.turquoise;
  if (o.contains('fars')) return _Palette.gold;
  if (o.contains('frans')) return Color(0xFF7C6BA8);
  if (o.contains('ital')) return Color(0xFF3E7CB1);
  if (o.contains('yunanc') || o.contains('grek')) return Color(0xFF4F9BA6);
  return _Palette.inkSoft;
}

/// Anlam katmanı etiketinin rengi.
Color senseColor(String sense) {
  switch (sense) {
    case 'gercek':
      return _Palette.turquoise;
    case 'mecaz':
      return _Palette.gold;
    case 'terim':
      return Color(0xFF7C6BA8);
    case 'argo':
      return _Palette.terracotta;
    default:
      return _Palette.inkSoft;
  }
}

String senseLabel(String sense) {
  switch (sense) {
    case 'gercek':
      return 'TEMEL ANLAM';
    case 'mecaz':
      return 'MECAZ';
    case 'terim':
      return 'TERİM';
    case 'argo':
      return 'ARGO / GÜNLÜK DİL';
    default:
      return sense.toUpperCase();
  }
}

/// Ölçü ölçeği — aralıklar birbirine tam sayılarla oturur.
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;
}

class Radii {
  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(14));
  static const lg = BorderRadius.all(Radius.circular(20));
  static const pill = BorderRadius.all(Radius.circular(999));
}

/// Tipografi ailesi.
class AppType {
  /// Büyük sözcük başlıkları — serif, edebî
  static TextStyle display(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.lora(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w600,
        height: 1.12,
        letterSpacing: -0.4,
      );

  /// Gövde metni — okunabilir sans
  static TextStyle body(double size, {Color? color, FontWeight? weight, double? height}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w400,
        height: height ?? 1.55,
      );

  /// Etiket, üst başlık — harf aralığı açılmış
  static TextStyle label(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontWeight: weight ?? FontWeight.w600,
        letterSpacing: 0.9,
      );

  /// Tanım metni — biraz daha büyük, rahat satır aralığı
  static TextStyle definition(double size, {Color? color}) => GoogleFonts.inter(
        fontSize: size,
        color: color,
        height: 1.62,
        letterSpacing: -0.1,
      );

  /// Örnek cümle — italik, sessiz
  static TextStyle quote(double size, {Color? color}) => GoogleFonts.inter(
        fontSize: size,
        color: color,
        fontStyle: FontStyle.italic,
        height: 1.6,
      );

  static TextStyle mono(double size, {Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
      );
}

/// Uygulama teması.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? _Palette.night : _Palette.paper;
    final surface = isDark ? _Palette.nightDim : Colors.white;
    final text = isDark ? _Palette.chalk : _Palette.ink;
    final textSoft = isDark ? _Palette.chalkSoft : _Palette.inkSoft;
    final accent = isDark ? _Palette.ember : _Palette.terracotta;
    final line = isDark ? _Palette.hairlineDark : _Palette.hairline;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? _Palette.night : Colors.white,
      secondary: isDark ? _Palette.jade : _Palette.turquoise,
      onSecondary: isDark ? _Palette.night : Colors.white,
      tertiary: isDark ? _Palette.amber : _Palette.gold,
      onTertiary: isDark ? _Palette.night : Colors.white,
      error: const Color(0xFFC0553F),
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: isDark ? const Color(0xFF2A2420) : _Palette.paperDim,
      outline: line,
      outlineVariant: line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,

      textTheme: TextTheme(
        displayLarge: AppType.display(48, color: text),
        displayMedium: AppType.display(38, color: text),
        displaySmall: AppType.display(30, color: text),
        headlineMedium: AppType.display(24, color: text),
        headlineSmall: AppType.display(20, color: text),
        titleLarge: AppType.body(18, color: text, weight: FontWeight.w600),
        titleMedium: AppType.body(15.5, color: text, weight: FontWeight.w600),
        bodyLarge: AppType.body(15, color: text),
        bodyMedium: AppType.body(14, color: textSoft),
        bodySmall: AppType.body(12.5, color: textSoft),
        labelLarge: AppType.body(13.5, color: text, weight: FontWeight.w600),
        labelSmall: AppType.label(10.5, color: textSoft),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.display(19, color: text),
        iconTheme: IconThemeData(color: textSoft),
      ),

      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: _inputBorder(line),
        enabledBorder: _inputBorder(line),
        focusedBorder: _inputBorder(accent, width: 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 15),
        hintStyle: AppType.body(15, color: textSoft),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: Radii.pill),
          textStyle: AppType.body(14.5, weight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lg),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: line),
        labelStyle: AppType.body(12, color: text),
        shape: const RoundedRectangleBorder(borderRadius: Radii.pill),
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _Palette.chalk : _Palette.ink,
        contentTextStyle: AppType.body(13.5, color: isDark ? _Palette.night : Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.md),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: Radii.pill,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Tema dışında kullanılan, bağımlılıksız renk erişimi.
extension ThemeShade on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;

  Color get subtleLine =>
      isDark ? _Palette.hairlineDark : _Palette.hairline;
  Color get mutedText => isDark ? _Palette.chalkSoft : _Palette.inkSoft;
  Color get paperSurface => isDark ? _Palette.nightDim : Colors.white;
}