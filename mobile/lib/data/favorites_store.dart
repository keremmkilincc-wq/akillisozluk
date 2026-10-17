// ============================================================================
//  FAVORİLER VE KİŞİSEL LİSTELER — Modül 7
//
//  Kullanıcı verisi, sözlük verisinden tamamen ayrı tutulur:
//    dict.db / JSON  → salt okunur, uygulamayla gelir
//    user data       → burada, cihazda, SharedPreferences ile
//
//  Bulut senkronizasyonu Faz 7'de. O zamana kadar veri cihazdan çıkmaz.
// ============================================================================

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  static const _keyFavorites = 'favorites';
  static const _keyLists = 'lists';

  /// Favoriler — hızlı erişim için ayrı bir küme.
  final Set<String> _favorites = {};

  /// Kişisel listeler: liste adı → kelime kümesi.
  final Map<String, Set<String>> _lists = {};

  bool _loaded = false;

  bool get loaded => _loaded;
  Set<String> get favorites => Set.unmodifiable(_favorites);
  Map<String, Set<String>> get lists => _lists
      .map((k, v) => MapEntry(k, Set<String>.unmodifiable(v)));

  bool isFavorite(String word) => _favorites.contains(word);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    _favorites
      ..clear()
      ..addAll(prefs.getStringList(_keyFavorites) ?? const []);

    final raw = prefs.getString(_keyLists);
    if (raw != null) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      for (final e in decoded.entries) {
        _lists[e.key] = Set<String>.from((e.value as List<dynamic>).cast<String>());
      }
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavorites, _favorites.toList());
    // Map<String, Set> → JSON
    await prefs.setString(
      _keyLists,
      json.encode(_lists.map((k, v) => MapEntry(k, v.toList()))),
    );
  }

  Future<void> toggleFavorite(String word) async {
    if (!_favorites.remove(word)) {
      _favorites.add(word);
    }
    notifyListeners();
    await _persist();
  }

  /// Liste oluşturur. Aynı isim varsa değiştirmez, false döner.
  Future<bool> createList(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (_lists.containsKey(trimmed)) return false;

    _lists[trimmed] = <String>{};
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> deleteList(String name) async {
    _lists.remove(name);
    notifyListeners();
    await _persist();
  }

  Future<void> addToList(String listName, String word) async {
    final list = _lists[listName];
    if (list == null) return;
    if (list.add(word)) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> removeFromList(String listName, String word) async {
    final list = _lists[listName];
    if (list == null) return;
    if (list.remove(word)) {
      notifyListeners();
      await _persist();
    }
  }

  /// Kelimenin hangi listelerde olduğunu döner.
  List<String> listsContaining(String word) =>
      _lists.entries.where((e) => e.value.contains(word)).map((e) => e.key).toList();

  /// Dışa aktarma: düz metin. PDF/Excel Faz 7'de; şimdilik panoya kopyalama
  /// yeterli ve bağımlılık gerektirmez.
  String exportAsText(String listName) {
    final words = _lists[listName] ?? _favorites;
    final buffer = StringBuffer('$listName — Akıllı Türkçe Sözlük\n\n');
    for (final w in words) {
      buffer.writeln('• $w');
    }
    return buffer.toString();
  }
}