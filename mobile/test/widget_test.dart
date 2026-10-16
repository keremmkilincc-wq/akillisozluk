// ============================================================================
//  DUMAN TESTİ
//
//  Gerçek veri dosyasını yükleyip uygulamayı ayağa kaldırır. Buradaki amaç
//  ekranların çizilmesi değil, veri hattı ile arayüz arasındaki bağın
//  kırılmadığını görmek: JSON bozulursa veya şema değişirse burada patlar.
// ============================================================================

import 'package:akilli_sozluk/core/theme.dart';
import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:akilli_sozluk/main.dart';
import 'package:akilli_sozluk/ui/word_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

Future<DictionaryRepository> _loadRepo([WidgetTester? tester]) async {
  final repo = DictionaryRepository();

  if (tester == null) {
    await repo.load();
    return repo;
  }

  // testWidgets içinde gerçek dosya G/Ç'si yalnızca runAsync içinde tamamlanır.
  // Sarılmazsa sahte olay döngüsü beklemeye girer ve test sonsuza kadar asılı
  // kalır — bu davranışı test etmek için bu yardımcıyı yazmadık, iki saat
  // kaybettiğimiz için yazdık.
  await tester.runAsync(repo.load);
  return repo;
}

void main() {
  // Test ortamında ağa çıkma: google_fonts varsayılan olarak fontu
  // uzaktan çeker, flutter_test ise ağ erişimini engeller. İkisi
  // çakışınca test sonsuza kadar bekler. Yerleşik fontlara düş.
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('veri seti yükleniyor ve beklenen içerik yerinde', (tester) async {
    final repo = await _loadRepo(tester);

    expect(repo.size, greaterThan(100));
    expect(repo.info.wordCount, greaterThan(100));

    // Türkçe harfler bozulmadan geldi mi?
    final goz = repo.lookup('göz');
    expect(goz, isNotNull);
    expect(goz!.isPureTurkish, isTrue);
    expect(goz.meanings, isNotEmpty);
  });

    testWidgets('ana ekran açılıyor ve günün kelimesi görünüyor', (tester) async {
    final repo = await _loadRepo(tester);
    // Uygulama DateTime.now() kullanıyor; test aynı hesabı yapmalı yoksa
    // gece yarısını geçtiğinde test bozulur.
    final expected = repo.wordOfTheDay(DateTime.now());

    await tester.pumpWidget(AkilliSozlukApp(repository: repo));
    // pumpAndSettle KULLANILMAZ: ilişki grafikteki nabız animasyonu hiç
    // durmaz, pumpAndSettle sonsuza kadar bekler ve test asılı kalır.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('GÜNÜN KELİMESİ'), findsOneWidget);
    expect(find.text(expected.word), findsWidgets);
  });

  testWidgets('kelime detay ekranı anlamları ve ilişkileri gösteriyor', (tester) async {
    final repo = await _loadRepo(tester);
    expect(repo.lookup('kitap'), isNotNull);

    // Sliver'lar viewport dışındaki içeriği KURMAZ. Uzun yüzey verip
    // her şeyin tek seferde kurulmasını sağlıyoruz; aksi hâlde aşağıdaki
    // bölümler için ayrı ayrı kaydırma gerekir.
    tester.view.physicalSize = const Size(430, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: WordDetailScreen(word: 'kitap'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('kitap'), findsWidgets);
    // Kök/ek ayrımı görünmeli
    expect(find.textContaining('KÖK VE EKLER'), findsOneWidget);
    // Anlam katmanı etiketleri
    expect(find.textContaining('TEMEL ANLAM'), findsWidgets);
    // İlişki ağı başlığı
    expect(find.textContaining('İLİŞKİ AĞI'), findsOneWidget);
  });

  test('arama motoru gerçek veri üzerinde çalışıyor', () async {
    final repo = await _loadRepo();

    // Birebir
    expect(repo.search('göz').results.first.word, 'göz');

    // Diyakritik hatası: 'ates' katlamada 'ateş' ile aynı hâle gelir.
    // Öneri değil SONUÇ döner — kullanıcı zaten doğru kelimeye ulaşır,
    // arayüz yalnızca doğru yazımı işaretler.
    final diacritic = repo.search('ates');
    expect(diacritic.results.map((r) => r.word), contains('ateş'));
  });

  test('günün kelimesi tarihe göre sabit', () async {
    final repo = await _loadRepo();
    final a = repo.wordOfTheDay(DateTime(2026, 10, 16));
    final b = repo.wordOfTheDay(DateTime(2026, 10, 16));
    final c = repo.wordOfTheDay(DateTime(2026, 10, 17));

    expect(a.word, b.word); // aynı gün → aynı kelime
    expect(a.word, isNot(c.word)); // farklı gün → farklı kelime
  });
}