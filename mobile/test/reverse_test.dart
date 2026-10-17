// ============================================================================
//  TERSİ SÖZLÜK TESTLERİ
//
//  BURADA ÇÖZÜLEN GERÇEK BİR HATA
//  ------------------------------
//  Tersi Sözlük ekranındaki örnek cümleler "tereddüt", "hürmet", "hasret"
//  kelimelerini vaat ediyordu. Üçü de sözlükte YOKTU. Kullanıcı örneğe
//  dokununca sıfır sonuç alıyordu — ve hiçbir hata görünmüyordu, ekran
//  "bulunamadı" diye dürüstçe davranıyordu. Ama bir örnek, vaat ettiği
//  cevabı vermiyorsa örnek değildir.
//
//  Bu dosya iki şeyi garanti eder:
//    1. Ekrandaki HER örnek en az bir sonuç döndürür.
//    2. Örneğin vaat ettiği kelime ilk sıradadır.
//
//  Sözlük büyüdükçe örnekler eskir; bu test o sessiz bozulmayı görünür
//  kılar. Yeni kelime eklendiğinde buraya yeni örnek de eklenmelidir.
// ============================================================================

import 'package:akilli_sozluk/data/dictionary_repository.dart';
import 'package:akilli_sozluk/ui/reverse_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  late DictionaryRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    repo = await openTestRepository();
  });

  group('ekrandaki örnekler vaadini tutuyor', () {
    test('en az bir örnek tanımlı', () {
      expect(ReverseScreen.examplePrompts, isNotEmpty);
    });

    test('her örnek en az bir sonuç döndürür', () {
      final bos = <String>[];

      for (final (phrase, hint) in ReverseScreen.examplePrompts) {
        final hits = repo.reverseSearch(phrase);
        if (hits.isEmpty) bos.add('$phrase  (vaat: $hint)');
      }

      expect(
        bos,
        isEmpty,
        reason: 'Bu örnekler sonuç döndürmüyor — kullanıcı boş ekran görür:\n'
            '${bos.join('\n')}',
      );
    });

    test('her örnek kendi cevabını ilk sırada bulur', () {
      final yanlis = <String>[];

      for (final (phrase, hint) in ReverseScreen.examplePrompts) {
        final hits = repo.reverseSearch(phrase);
        if (hits.isEmpty || hits.first.word != hint) {
          final ilk = hits.isEmpty ? '(sonuç yok)' : hits.first.word;
          yanlis.add('$phrase\n'
              '    vaat edilen: $hint\n'
              '    ilk sonuç   : $ilk');
        }
      }

      expect(
        yanlis,
        isEmpty,
        reason: 'Örnekler kendi cevabını ilk sırada bulamıyor:\n'
            '${yanlis.join('\n')}',
      );
    });
  });

  group('tersi sözlük davranışı', () {
    test('tanımdan kavram buluyor', () {
      final hits = repo.reverseSearch('görme organı');
      expect(hits.map((h) => h.word), contains('göz'));
    });

    test('sözlükte olmayan kavram reddediliyor', () {
      expect(repo.reverseSearch('zümrüt ejderha şövalye'), isEmpty);
    });

    test('tanımı doğrudan yazmak da kelimeyi bulur', () {
      // Kullanıcı bazen kelimeyi bilir, tanımını arar. Bu yol çalışmalı.
      final hits = repo.reverseSearch('Yer yüzünün yaklaşık yüzde yetmişini '
          'kaplayan, tuzlu su kütlesi');
      expect(hits.map((h) => h.word), contains('deniz'));
    });
  });
}