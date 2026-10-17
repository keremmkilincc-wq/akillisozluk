// ============================================================================
//  LİSTELErim EKRANI — Modül 7
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/dictionary_repository.dart';
import '../data/favorites_store.dart';
import 'word_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    context.read<FavoritesStore>().load();
    // +1: Favoriler sekmesi
    _tabs = TabController(length: 1, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lists = context.watch<FavoritesStore>().lists;
    // Sekme sayısı liste sayısıyla eşlenir; sekme seçimi korunur.
    if (_tabs.length != lists.length + 1) {
      _tabs.dispose();
      _tabs = TabController(length: lists.length + 1, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FavoritesStore>();
    final listNames = store.lists.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('Listelerim', style: AppType.display(19, color: context.scheme.onSurface)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yeni liste',
            onPressed: () => _newListDialog(context),
          ),
          const SizedBox(width: Gap.xs),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: context.scheme.primary,
          unselectedLabelColor: context.mutedText,
          indicatorColor: context.scheme.primary,
          dividerColor: context.subtleLine,
          tabs: [
            const Tab(text: 'Favoriler'),
            for (final name in listNames) Tab(text: name),
          ],
        ),
      ),
      body: store.loaded
          ? TabBarView(
              controller: _tabs,
              children: [
                _FavoritesTab(),
                for (final name in listNames) _CustomListTab(listName: name),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _newListDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yeni liste', style: AppType.display(18, color: context.scheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppType.body(14.5, color: context.scheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'Örn: Şiirlerimde kullanacaklarım',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Vazgeç', style: AppType.body(13.5, color: context.mutedText)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    if (name == null || context.mounted == false) return;

    final store = context.read<FavoritesStore>();
    final ok = await store.createList(name);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" zaten var')),
      );
    }
  }
}

// --------------------------------------------------------------- favoriler
class _FavoritesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<FavoritesStore>();
    final repo = context.watch<DictionaryRepository>();
    final words = store.favorites.toList()..sort();

    if (words.isEmpty) return _empty(context, 'Henüz favori yok');

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
      children: [
        _exportRow(context, 'Favoriler', words),
        const SizedBox(height: Gap.md),
        for (final w in words)
          _wordRow(context, w, repo, onRemove: () => store.toggleFavorite(w)),
      ],
    );
  }
}

// ---------------------------------------------------------- kişisel liste
class _CustomListTab extends StatelessWidget {
  final String listName;

  const _CustomListTab({required this.listName});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FavoritesStore>();
    final repo = context.watch<DictionaryRepository>();
    final words = (store.lists[listName] ?? const <String>{}).toList()..sort();

    if (words.isEmpty) {
      return _empty(context, '"$listName" boş — kelime detay sayfasından ekle');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
      children: [
        _exportRow(context, listName, words),
        const SizedBox(height: Gap.md),
        for (final w in words)
          _wordRow(context, w, repo,
              onRemove: () => store.removeFromList(listName, w)),
      ],
    );
  }
}

// ------------------------------------------------------------ ortak parça
Widget _empty(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded,
              size: 30, color: context.mutedText.withValues(alpha: 0.5)),
          const SizedBox(height: Gap.lg),
          Text(
            message,
            style: AppType.body(13.5, color: context.mutedText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _exportRow(BuildContext context, String name, List<String> words) {
  return Row(
    children: [
      Text('${words.length} kelime', style: AppType.label(10, color: context.mutedText)),
      const Spacer(),
      TextButton.icon(
        onPressed: () async {
          final store = context.read<FavoritesStore>();
          final text = store.exportAsText(name);
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Panoya kopyalandı')),
            );
          }
        },
        icon: Icon(Icons.copy_rounded, size: 14, color: context.scheme.primary),
        label: Text('Kopyala', style: AppType.body(12, color: context.scheme.primary)),
      ),
    ],
  );
}

Widget _wordRow(
  BuildContext context,
  String word,
  DictionaryRepository repo, {
  required VoidCallback onRemove,
}) {
  final w = repo.lookup(word);

  return Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Material(
      color: context.paperSurface,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: w == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => WordDetailScreen(word: w.word)),
                ),
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: context.subtleLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w?.word ?? word,
                      style: AppType.display(16, color: context.scheme.onSurface),
                    ),
                    if (w != null)
                      Text(
                        w.primaryMeaning,
                        style: AppType.body(12, color: context.mutedText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 17, color: context.mutedText),
                tooltip: 'Listeden çıkar',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}