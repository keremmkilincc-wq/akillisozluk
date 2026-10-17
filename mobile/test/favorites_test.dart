// ============================================================================
//  FAVORİLER DEPOSU TESTLERİ
//
//  Kullanıcı verisi kaybolursa uygulamanın değeri silinir. Kalıcılık
//  (persist) burada test edilir: ekle → yeni depoya yükle → hâlâ orada mı?
// ============================================================================

import 'package:akilli_sozluk/data/favorites_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('favori ekleme ve çıkarma', () async {
    final store = FavoritesStore();
    await store.load();

    expect(store.isFavorite('kitap'), isFalse);
    await store.toggleFavorite('kitap');
    expect(store.isFavorite('kitap'), isTrue);
    await store.toggleFavorite('kitap');
    expect(store.isFavorite('kitap'), isFalse);
  });

  test('favori kalıcı — yeni depoya yüklendiğinde duruyor', () async {
    final first = FavoritesStore();
    await first.load();
    await first.toggleFavorite('ateş');
    await first.toggleFavorite('göz');

    final second = FavoritesStore();
    await second.load();

    expect(second.isFavorite('ateş'), isTrue);
    expect(second.isFavorite('göz'), isTrue);
    expect(second.favorites.length, 2);
  });

  test('liste oluşturma — aynı isim reddedilir', () async {
    final store = FavoritesStore();
    await store.load();

    expect(await store.createList('Şiirlerim'), isTrue);
    expect(await store.createList('Şiirlerim'), isFalse);
    expect(await store.createList('   '), isFalse);
  });

  test('listeye kelime ekleme ve kalıcılık', () async {
    final first = FavoritesStore();
    await first.load();
    await first.createList('Sınav kelimelerim');
    await first.addToList('Sınav kelimelerim', 'kibrit');

    final second = FavoritesStore();
    await second.load();

    expect(second.lists['Sınav kelimelerim'], contains('kibrit'));
  });

  test('listeden çıkarma', () async {
    final store = FavoritesStore();
    await store.load();
    await store.createList('Test');
    await store.addToList('Test', 'yol');
    expect(store.lists['Test'], contains('yol'));

    await store.removeFromList('Test', 'yol');
    expect(store.lists['Test'], isNot(contains('yol')));
  });

  test('kelimenin hangi listelerde olduğu bulunur', () async {
    final store = FavoritesStore();
    await store.load();
    await store.createList('A');
    await store.createList('B');
    await store.addToList('A', 'su');
    await store.addToList('B', 'su');

    expect(store.listsContaining('su'), containsAll(['A', 'B']));
  });

  test('liste silme', () async {
    final store = FavoritesStore();
    await store.load();
    await store.createList('Gidecek');
    await store.deleteList('Gidecek');
    expect(store.lists.containsKey('Gidecek'), isFalse);
  });

  test('dışa aktarma metni kelime içerir', () async {
    final store = FavoritesStore();
    await store.load();
    await store.createList('Deneme');
    await store.addToList('Deneme', 'kalem');

    final text = store.exportAsText('Deneme');
    expect(text, contains('kalem'));
    expect(text, contains('Deneme'));
  });
}