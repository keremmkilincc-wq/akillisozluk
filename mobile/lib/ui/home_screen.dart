// ============================================================================
//  ANA EKRAN
//
//  Sıralama kasıtlı: önce arama (tek işi olan bir uygulamanın tek işi),
//  sonra günün kelimesi, sonra kısayollar. Kullanıcı ilk açılışta ne yapacağını
//  düşünmek zorunda olmamalı.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/turkish.dart';
import '../data/dictionary_repository.dart';
import '../data/models.dart';
import 'reverse_screen.dart';
import 'search_screen.dart';
import 'widgets/common.dart';
import 'word_detail_screen.dart';
import 'writing_rules_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _days = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSearch({String initial = ''}) async {
    _searchController.text = initial;
    _searchController.selection = TextSelection.collapsed(offset: initial.length);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DictionaryRepository>();
    final now = DateTime.now();
    final wotd = repo.wordOfTheDay(now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context, now)),
            SliverToBoxAdapter(child: _searchBar(context)),
            SliverToBoxAdapter(child: _wordOfTheDay(context, wotd)),
            SliverToBoxAdapter(child: _quickAccess(context)),
            SliverToBoxAdapter(child: _explore(context, repo)),
            SliverToBoxAdapter(child: _datasetFooter(context, repo)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- başlık
  Widget _header(BuildContext context, DateTime now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${turkishUpper(_days[now.weekday - 1])}  ·  ${turkishUpper(_months[now.month - 1])} ${now.day}',
                  style: AppType.label(10, color: context.mutedText),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  _greeting(),
                  style: AppType.display(28, color: context.scheme.onSurface),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_stories_rounded, size: 19, color: context.scheme.primary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- arama
  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Material(
        color: context.paperSurface,
        borderRadius: Radii.pill,
        child: InkWell(
          onTap: () => _openSearch(),
          borderRadius: Radii.pill,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            decoration: BoxDecoration(
              borderRadius: Radii.pill,
              border: Border.all(color: context.subtleLine),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 21, color: context.mutedText),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'Kelime ara…',
                    style: AppType.body(15, color: context.mutedText),
                  ),
                ),
                _roundIcon(Icons.mic_none_rounded, () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesli arama — Faz 1 sonrası')),
                  );
                }),
                const SizedBox(width: Gap.sm),
                _roundIcon(Icons.center_focus_weak_rounded, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kamera ile kelime tarama — Faz 3')),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: context.subtleLine.withValues(alpha: 0.5), shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: context.mutedText),
      ),
    );
  }

  // ------------------------------------------------------- günün kelimesi
  Widget _wordOfTheDay(BuildContext context, Word word) {
    final c = context.scheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WordDetailScreen(word: word.word)),
          ),
          borderRadius: Radii.lg,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: Radii.lg,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  c.primary.withValues(alpha: context.isDark ? 0.16 : 0.09),
                  c.secondary.withValues(alpha: context.isDark ? 0.13 : 0.07),
                ],
              ),
              border: Border.all(color: c.primary.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('GÜNÜN KELİMESİ', style: AppType.label(10, color: c.primary)),
                      const Spacer(),
                      Icon(Icons.arrow_outward, size: 15, color: c.primary.withValues(alpha: 0.7)),
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    word.word,
                    style: AppType.display(38, color: c.onSurface),
                  ),
                  const SizedBox(height: Gap.sm),
                  Row(
                    children: [
                      OriginBadge(origin: word.origin, compact: true),
                      if (word.phonetics != null) ...[
                        const SizedBox(width: Gap.sm),
                        Text(word.phonetics!, style: AppType.mono(11.5, color: context.mutedText)),
                      ],
                    ],
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    word.primaryMeaning,
                    style: AppType.definition(14.5, color: c.onSurface.withValues(alpha: 0.85)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (word.meanings.first.exampleModern != null) ...[
                    const SizedBox(height: Gap.lg),
                    Container(
                      padding: const EdgeInsets.only(left: Gap.md),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: c.secondary.withValues(alpha: 0.45), width: 2),
                        ),
                      ),
                      child: Text(
                        word.meanings.first.exampleModern!,
                        style: AppType.quote(13, color: context.mutedText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- kısayollar
  Widget _quickAccess(BuildContext context) {
    final tiles = <Widget>[
      QuickTile(
        icon: Icons.extension_rounded,
        label: 'Kelime Oyunları',
        subtitle: 'Günlük bulmaca',
        accent: originColor('Arapça'),
        locked: true,
      ),
      QuickTile(
        icon: Icons.school_outlined,
        label: 'Sınav Modu',
        subtitle: 'Yazım kuralları',
        accent: originColor('Fransızca'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WritingRulesScreen()),
        ),
      ),
      QuickTile(
        icon: Icons.bookmark_border_rounded,
        label: 'Listelerim',
        subtitle: 'Kişisel sözlük',
        accent: originColor('Farsça'),
        locked: true,
      ),
      QuickTile(
        icon: Icons.forum_outlined,
        label: 'Tersi Sözlük',
        subtitle: '"Bunu nasıl derlerim?"',
        accent: context.scheme.primary,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReverseScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'Keşfet'),
          SizedBox(
            height: 108,
            child: Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  Expanded(child: tiles[i]),
                  if (i < tiles.length - 1) const SizedBox(width: Gap.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- keşfet
  Widget _explore(BuildContext context, DictionaryRepository repo) {
    final pure = repo.pureTurkish().take(4).toList();
    final exam = repo.byExam('yds').take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
          child: SectionHeader(
            label: 'Öz Türkçe',
            trailing: '${pure.length} sözcük',
          ),
        ),
        for (final w in pure)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            child: WordRow(
              word: w.word,
              definition: w.primaryMeaning,
              origin: w.origin,
              isPureTurkish: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WordDetailScreen(word: w.word)),
              ),
            ),
          ),
        const SizedBox(height: Gap.lg),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
          child: SectionHeader(
            label: 'YDS Sınavında Çıkan',
            trailing: 'Hepsi',
          ),
        ),
        for (final w in exam)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            child: WordRow(
              word: w.word,
              definition: w.primaryMeaning,
              origin: w.origin,
              isPureTurkish: w.isPureTurkish,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WordDetailScreen(word: w.word)),
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- altbilgi
  Widget _datasetFooter(BuildContext context, DictionaryRepository repo) {
    final i = repo.info;
    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, 0),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.paperSurface.withValues(alpha: 0.6),
        borderRadius: Radii.md,
        border: Border.all(color: context.subtleLine),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 15, color: context.mutedText),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERİ SETİ · ${i.version}',
                  style: AppType.label(9.5, color: context.mutedText),
                ),
                const SizedBox(height: 3),
                Text(
                  '${i.wordCount} kelime · ${i.meaningCount} anlam · ${i.relationCount} ilişki',
                  style: AppType.body(12, color: context.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}