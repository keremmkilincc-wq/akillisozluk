// ============================================================================
//  AKILLI TÜRKÇE SÖZLÜK — giriş noktası
// ============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'core/theme.dart';
import 'data/dictionary_repository.dart';
import 'data/favorites_store.dart';
import 'ui/favorites_screen.dart';
import 'ui/games_screen.dart';
import 'ui/wordle_screen.dart';
import 'ui/home_screen.dart';
import 'ui/reverse_screen.dart';
import 'ui/search_screen.dart';
import 'ui/word_detail_screen.dart';
import 'ui/writing_rules_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sözlük SQLite'tan okunur. Fabrika platforma göre seçilir.
  //
  // NEDEN: sqflite'in WEB UYGULAMASI YOKTUR. Veri tabanını SQLite'a
  // taşıdığımızda web derlemesi sessizce bozuldu — ekranlar tarayıcıda
  // hiç açılmadı, konsolda tek satırlık bir hata. Bu derleme yalnızca QA
  // için kullanılıyor ama görsel doğrulamanın tek yolu; kaybedilmesi
  // kabul edilemezdi.
  //
  // Mobil: sqflite'ın kendi fabrikası.
  // Web:    wasm tabanlı SQLite (sqflite_common_ffi_web).
  final factory = await resolveDatabaseFactory();

  final repo = DictionaryRepository();
  String? loadError;
  try {
    await repo.load(factory: factory);
  } catch (e) {
    // Sessizce boş ekran yerine sebebi göster.
    //
    // Bu bir hata değil, bilinen bir sınır: web derlemesi sözlük
    // veritabanını açamıyor (bkz. sqlite_dictionary_source.dart). Ürün
    // etkilenmez. QA sırasında ekranın neden boş olduğu görünsün.
    loadError = '$e';
  }

  runApp(AkilliSozlukApp(repository: repo, loadError: loadError));
}

/// Platforma uygun veritabanı fabrikası.
Future<DatabaseFactory> resolveDatabaseFactory() async {
  if (kIsWeb) {
    // Web'de SQLite bir SharedWorker üzerinden çalışır; wasm motoru ve
    // worker önce kurulur.
    //
    // Bu kurulum web/ klasöründeki sqlite3.wasm ve sqflite_sw.js dosyalarını
    // gerektirir. Bunlar
    //   dart run sqflite_common_ffi_web:setup
    // ile indirilir. Bu komut olmadan web derlemesi açılır ama veritabanını
    // açamaz.
    await sqfliteFfiWebLoadSqlite3Wasm(SqfliteFfiWebOptions());
    return databaseFactoryFfiWeb;
  }
  return sqflite.databaseFactory;
}

/// Geliştirme/QA için: URL parametresiyle ekran seçimi.
///
///   ?screen=search&q=şöför         → arama ekranı, sorgu dolu
///   ?screen=detail&word=kitap      → kelime detay
///   ?screen=wordle                 → kelime tahmini oyunu
///
/// Üretimde etkisi yok; yalnızca web derlemesinde anlamlıdır. Bu olmadan
/// ekranları doğrulamak için her seferinde uygulamayı yeniden derlemek
/// gerekir.
Widget _initialScreen(DictionaryRepository repo) {
  final params = Uri.base.queryParameters;
  switch (params['screen']) {
    case 'search':
      return SearchScreen(initialQuery: params['q']);
    case 'detail':
      return WordDetailScreen(word: params['word'] ?? 'kitap');
    case 'reverse':
      return const ReverseScreen();
    case 'rules':
      return const WritingRulesScreen();
    case 'wordle':
      return const WordleScreen();
    case 'games':
      return const GamesScreen();
    case 'lists':
      return const FavoritesScreen();
    default:
      return const HomeScreen();
  }
}

/// Veri tabanı açılamadığında gösterilen ekran.
///
/// Neden ayrı ekran: daha önce web'de uygulama sessizce BOŞ EKRANLA
/// çöküyordu. Konsoldaki tek satırlık hata sebebi söylemiyordu, ekran
/// da söylemiyordu. Şimdi ekran neden boş olduğunu açıkça söylüyor.
class _LoadErrorScreen extends StatelessWidget {
  final String message;
  const _LoadErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_outlined, size: 40),
              const SizedBox(height: 16),
              Text(
                'Sözlük yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AkilliSozlukApp extends StatelessWidget {
  final DictionaryRepository repository;

  /// Veri tabanı açılamadıysa sebebi. Sessiz boş ekran yerine
  /// kullanıcıya (ve QA sırasında bize) ne olduğu görünür.
  final String? loadError;

  const AkilliSozlukApp({
    super.key,
    required this.repository,
    this.loadError,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repository),
        ChangeNotifierProvider(create: (_) => FavoritesStore()),
      ],
      child: MaterialApp(
        title: 'Akıllı Türkçe Sözlük',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: loadError != null
            ? _LoadErrorScreen(message: loadError!)
            : _initialScreen(repository),
        builder: (context, child) {
          // Sistem yazı tipi ölçeğini makul tut — 2x büyütmede arayüz dağılmasın.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(
                mq.textScaler.scale(1).clamp(0.9, 1.25),
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}