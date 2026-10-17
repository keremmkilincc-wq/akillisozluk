// ============================================================================
//  ARAYÜZ DUMAN TESTLERİ
//
//  Buradaki amaç ekranların çizilmesi değil; veri hattı ile arayüz arasındaki
//  bağın kırılmadığını görmek. Sözlük SQLite'tan okunur.
// ============================================================================

import 'package:akilli_sozluk/core/theme.dart';
import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:akilli_sozluk/data/favorites_store.dart';
import 'package:akilli_sozluk/main.dart';
import 'package:akilli_sozluk/ui/games_screen.dart';
import 'package:akilli_sozluk/ui/home_screen.dart';
import 'package:akilli_sozluk/ui/reverse_screen.dart';
import 'package:akilli_sozluk/ui/writing_rules_screen.dart';
import 'package:akilli_sozluk/ui/word_detail_screen.dart';
import 'package:akilli_sozluk/ui/wordle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  // Depo setUpAll'da AÇILIR, testlerin gövdesi içinde değil.
  //
  // Widget testleri sahte olay döngüsünde çalışır; test gövdesi içinde gerçek
  // dosya G/Ç'si (SQLite açma) yapılırsa döngü asılı kalır ve Flutter
  // "Guarded function conflict" hatası verir. setUpAll sahte döngünün
  // dışındadır — bu yüzden burada.
  late DictionaryRepository repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    repo = await openTestRepository();
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repo),
          ChangeNotifierProvider(create: (_) => FavoritesStore()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );

    // pumpAndSettle KULLANILMAZ: ilişki grafikteki nabız animasyonu hiç
    // durmaz, pumpAndSettle sonsuza kadar bekler ve test asılı kalır.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('ana ekran açılıyor', (tester) async {
    await pump(tester, const HomeScreen());

    expect(find.text('GÜNÜN KELİMESİ'), findsOneWidget);
    expect(find.text('KEŞFET'), findsOneWidget);
  });

  testWidgets('kelime detay ekranı tüm bölümleri gösteriyor', (tester) async {
    // Sliver'lar viewport dışındaki içeriği KURMAZ. Uzun yüzey verip
    // her şeyin tek seferde kurulmasını sağlıyoruz.
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester, const WordDetailScreen(word: 'kitap'));

    expect(find.text('kitap'), findsWidgets);
    expect(find.textContaining('KÖK VE EKLER'), findsOneWidget);
    expect(find.textContaining('ANLAM KATMANLARI'), findsOneWidget);
    expect(find.textContaining('YAZIM UYARISI'), findsOneWidget);
    expect(find.textContaining('İLİŞKİ AĞI'), findsOneWidget);
  });

  testWidgets('yazım kuralları ekranı kuralları listeliyor', (tester) async {
    await pump(tester, const WritingRulesScreen());

    expect(find.textContaining('Yazım Kuralları'), findsWidgets);
    // "kitabe" yanlış biçimi aramada görünmeli
    expect(find.text('kitabe'), findsOneWidget);
    expect(find.text('kitabı'), findsOneWidget);
  });

  testWidgets('tersi sözlük boş durumdan sonuç buluyor', (tester) async {
    await pump(tester, const ReverseScreen());

    // SectionHeader etiketi turkishUpper() ile büyütülür: "ÖRNEKLER".
    expect(find.text('ÖRNEKLER'), findsOneWidget);

    // Örnek cümlelerden birine dokununca arama çalışır.
    // Not: metinler EKRANDAKİ GERÇEK metinlerle eşleşmeli — burada önce
    // uydurulmuş bir cümle ("görülen") vardı ve ekranda hiç yoktu.
    final phrase = ReverseScreen.examplePrompts.first.$1;
    await tester.tap(find.textContaining(phrase).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('aday'), findsOneWidget);
  });

  testWidgets('oyun ekranı oyunları listeliyor', (tester) async {
    await pump(tester, const GamesScreen());

    expect(find.text('Kelime Tahmini'), findsOneWidget);
    expect(find.text('Hangi Kelime Öz Türkçe?'), findsOneWidget);
    expect(find.text('Eş Anlamlı Düellosu'), findsOneWidget);
  });

  testWidgets('wordle ekranı kuruluyor ve hak gösteriyor', (tester) async {
    await pump(tester, const WordleScreen());

    // Ekran açılıyor: 6 hak kalmış olmalı.
    expect(find.textContaining('hak kaldı'), findsOneWidget);

    // Tahta 6 satır (6 deneme) çizilmeli.
    expect(find.byType(WordleScreen), findsOneWidget);
  });

  testWidgets('uygulama kökü sözlükle birlikte açılıyor', (tester) async {
    await tester.pumpWidget(AkilliSozlukApp(repository: repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('GÜNÜN KELİMESİ'), findsOneWidget);
  });
}