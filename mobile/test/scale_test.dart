// ============================================================================
//  ÖLÇEK DENETIMİ — 58.809 madde
//
//  Bu dosya bir test değil, bir ÖLÇÜM. Beklenen davranışı doğrulamaz;
//  maliyeti kaydeder ve sinirlarin asilip asilmadigini gosterir.
//
//  Neden sart: proje 139 kelimeyle kuruldu. Arama motoru bellekte
//  calisiyor ve silme-komsulugu indeksi kuruyor. 139 kelimede
//  ihmal edilebilir; 58.000 kelimede telefonu oldurebilir. Ustune
//  inşa etmeden once olmek gerekir.
//
//  Kirmizi esik: acilis suresi 2000 ms, arama suresi 120 ms, bellek 200 MB.
//  Bunlarin usteligi kaba bir gostergedir; asil hedef degisimi gormek.
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// Surec bellek kullanimi (MB). Windows uzerinde GetProcessMemoryInfo ile
/// okunur; Linux/macOS'ta null doner ve test yine de calisir.
///
/// Bu deger test kosullarina baglidir (JIT, tanilayici acik). Amac kesin
/// saymak degil, 139 kelime ile 58.000 kelime arasindaki FARKI gormek.
double? _rssMb() {
  if (!Platform.isWindows) return null;
  try {
    final result = Process.runSync(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'(Get-Process -Id $PID).WorkingSet64',
      ],
      runInShell: true,
    );
    final bytes = int.tryParse((result.stdout as String).trim());
    return bytes == null ? null : bytes / 1048576;
  } catch (_) {
    return null;
  }
}

String _fmtRss(double? mb) {
  if (mb == null) return 'olcemedi';
  return '${mb.toStringAsFixed(1)} MB';
}

void main() {
  test('olcek olcumu', () async {
    sqfliteFfiInit();

    final stopwatch = Stopwatch()..start();
    final repo = await openTestRepository();
    final loadMs = stopwatch.elapsedMilliseconds;

    final rssMb = _rssMb();

    debugPrint('--- OLCEK ---');
    debugPrint('madde        : ${repo.size}');
    debugPrint('acilis suresi: $loadMs ms');
    debugPrint('bellek (RSS) : ${_fmtRss(rssMb)}');

    // Arama suresi — ilk arama indeksi ısıtır, ikincisi gercek maliyettir
    final queries = ['kitap', 'ev', 'göz', 'araba', 'okul', 'zzz'];
    for (final q in queries) {
      final sw = Stopwatch()..start();
      repo.search(q);
      debugPrint('  arama "$q": ${sw.elapsedMilliseconds} ms');
    }

    // Ikinci tur: indeks sicak
    var warm = 0;
    for (final q in queries) {
      final sw = Stopwatch()..start();
      repo.search(q);
      warm += sw.elapsedMilliseconds;
    }
    debugPrint('sicak arama ort.: ${(warm / queries.length).toStringAsFixed(1)} ms');

    // Tersi sozluk yalnizca 277 anlamdan besleniyor; olcek testi degil
    debugPrint('tersi aday  : ${repo.reverseSearch('yanma alani').length}');

    debugPrint('--- SINIRLAR ---');
    debugPrint('acilis  ${loadMs > 2000 ? "ASILDI" : "ok"} (<=2000 ms)');
    debugPrint('bellek  ${rssMb == null ? 'olcemedi' : (rssMb > 200 ? 'ASILDI' : 'ok')} (<=200 MB)');

    // En azindan dogru calistigini dogrula
    expect(repo.size, greaterThan(50000));
    expect(repo.search('kitap').results, isNotEmpty);
  });
}