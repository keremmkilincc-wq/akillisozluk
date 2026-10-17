// ============================================================================
//  TEST ALTYAPISI
//
//  Testler de AYNI SQLite yolundan geçer. JSON'dan okumak gerçek davranışı
//  test etmezdi — üretim hattı JSON'a değil dict.db'ye yazıyor.
//
//  path_provider masaüstünde test sırasında platform kanalı bulamaz; bu
//  yüzden teste dosya yolu doğrudan verilir. Sorgu mantığının tamamı
//  (anlamlar, ilişkiler, morfoloji, yazım kuralları) gerçek kod yolundan
//  geçer, yalnızca "asset'i nereye kopyalayayım" adımı atlanır.
// ============================================================================

library;

import 'dart:io';

import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// `mobile/assets/dict.db` dosyasının mutlak yolu.
///
/// Bu dosya testten de varlık PAKETİNE girer. `flutter test` sırasında
/// rootBundle çalışır, dolayısıyla ayrıca "dict.db gerçekten pakette mi"
/// kontrolü de yapılabilir.
String dictDbPath() {
  // flutter test çalışma dizini proje köküdür (mobile/)
  final f = File(p.join('assets', 'dict.db'));
  if (!f.existsSync()) {
    throw StateError(
      'dict.db bulunamadı.\n'
      'Önce şunu çalıştır:  python tools/build_dict.py',
    );
  }
  return f.absolute.path;
}

/// ffi tabanlı fabrika ile sözlük deposunu açar.
Future<DictionaryRepository> openTestRepository() async {
  sqfliteFfiInit();
  final repo = DictionaryRepository();
  await repo.load(
    factory: databaseFactoryFfi,
    databasePath: dictDbPath(),
  );
  return repo;
}

/// Bir kez açılan depo — testler arası paylaşılır, açılış maliyeti ödenmez.
DictionaryRepository? _shared;

Future<DictionaryRepository> sharedRepository() async {
  _shared ??= await openTestRepository();
  return _shared!;
}