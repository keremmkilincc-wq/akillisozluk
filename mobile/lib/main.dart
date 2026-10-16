// ============================================================================
//  AKILLI TÜRKÇE SÖZLÜK — giriş noktası
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/dictionary_repository.dart';
import 'ui/home_screen.dart';
import 'ui/search_screen.dart';
import 'ui/word_detail_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sözlük belleğe alınır. Faz 1'de SQLite'a taşınacak; buradaki tek
  // değişiklik repository'nin iç yüzü olacak.
  final repo = DictionaryRepository();
  await repo.load();

  runApp(AkilliSozlukApp(repository: repo));
}

/// Geliştirme/QA için: URL parametresiyle ekran seçimi.
///
///   ?screen=search&q=şöför         → arama ekranı, sorgu dolu
///   ?screen=detail&word=kitap      → kelime detay
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
    default:
      return const HomeScreen();
  }
}

class AkilliSozlukApp extends StatelessWidget {
  final DictionaryRepository repository;

  const AkilliSozlukApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: repository,
      child: MaterialApp(
        title: 'Akıllı Türkçe Sözlük',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: _initialScreen(repository),
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