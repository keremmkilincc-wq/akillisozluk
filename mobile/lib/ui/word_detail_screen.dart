// ============================================================================
//  KELİME DETAY EKRANI
//
//  Akış: kelime kimliği → kök/ek → anlam katmanları → örnek cümleler →
//        ilişki ağı → yazım uyarısı.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/turkish.dart';
import '../data/dictionary_repository.dart';
import '../data/favorites_store.dart';
import '../data/models.dart';
import 'widgets/common.dart';
import 'widgets/relation_graph.dart';

class WordDetailScreen extends StatefulWidget {
  final String word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final _tts = FlutterTts();
  final _bookmarkTick = ValueNotifier<bool>(false);
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.42);
  }

  @override
  void dispose() {
    _bookmarkTick.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    HapticFeedback.selectionClick();
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    setState(() => _speaking = true);
    await _tts.speak(text);
    await _tts.awaitSpeakCompletion(true);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DictionaryRepository>();
    final word = repo.lookup(widget.word);

    if (word == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('"${widget.word}" bulunamadı',
              style: AppType.body(14, color: context.mutedText)),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _appBar(context, word),
          SliverToBoxAdapter(child: _identity(context, word)),
          SliverToBoxAdapter(child: _writingRules(context, word, repo)),
          SliverToBoxAdapter(child: _morphology(context, word)),
          SliverToBoxAdapter(child: _meanings(context, word)),
          SliverToBoxAdapter(child: _relations(context, word, repo)),
          SliverToBoxAdapter(child: _footer(context, word)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- app bar
  Widget _appBar(BuildContext context, Word word) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 132,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: _bookmarkTick,
          builder: (context, _, __) => _bookmarkButton(context, word),
        ),
        IconButton(
          icon: Icon(Icons.more_horiz_rounded),
          onPressed: () => _coming(context, 'Paylaşım — Faz 7'),
        ),
        const SizedBox(width: Gap.xs),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14, right: 56),
        title: Text(
          word.word,
          style: AppType.display(18, color: context.scheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Favoriye ekle/çıkar. ValueListenable ile AppBar butonu yeniden çizilir.
  Widget _bookmarkButton(BuildContext context, Word word) {
    final store = context.watch<FavoritesStore>();
    final isFav = store.isFavorite(word.word);
    final c = context.scheme;

    return IconButton(
      icon: Icon(
        isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isFav ? c.primary : null,
      ),
      tooltip: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
      onPressed: () {
        HapticFeedback.selectionClick();
        store.toggleFavorite(word.word);
        _bookmarkTick.value = !isFav;
      },
    );
  }

  void _coming(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(what)),
    );
  }

  // ------------------------------------------------------------ kimlik
  Widget _identity(BuildContext context, Word word) {
    final c = context.scheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: context.paperSurface,
        borderRadius: Radii.lg,
        border: Border.all(color: context.subtleLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: AppType.display(34, color: c.onSurface),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      syllabify(word.word),
                      style: AppType.mono(11.5, color: context.mutedText),
                    ),
                  ],
                ),
              ),
              _audioButton(context),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OriginBadge(origin: word.origin),
              if (word.originPeriod.isNotEmpty)
                _metaChip(context, Icons.history_rounded, word.originPeriod),
              if (word.isPureTurkish)
                _metaChip(context, Icons.eco_outlined, 'Öz Türkçe'),
              if (word.phonetics != null)
                _metaChip(context, Icons.graphic_eq_rounded, word.phonetics!),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Text('GÜNLÜK KULLANIM', style: AppType.label(9.5, color: context.mutedText)),
              const SizedBox(width: Gap.md),
              Expanded(child: _usageBar(context, word.usageFrequency)),
              const SizedBox(width: Gap.md),
              Text(
                '%${(word.usageFrequency * 100).round()}',
                style: AppType.mono(11, color: context.mutedText),
              ),
            ],
          ),
          if (word.examList.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Text('SINAVLARDA GEÇER', style: AppType.label(9.5, color: context.mutedText)),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Wrap(
                    spacing: Gap.sm,
                    children: [
                      for (final e in word.examList)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.secondary.withValues(alpha: 0.10),
                            borderRadius: Radii.pill,
                          ),
                          child: Text(
                            turkishUpper(e),
                            style: AppType.label(9, color: c.secondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.subtleLine.withValues(alpha: 0.45),
        borderRadius: Radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.mutedText),
          const SizedBox(width: 5),
          Text(label, style: AppType.body(11.5, color: context.mutedText)),
        ],
      ),
    );
  }

  Widget _usageBar(BuildContext context, double value) {
    return ClipRRect(
      borderRadius: Radii.pill,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 5,
          backgroundColor: context.subtleLine.withValues(alpha: 0.6),
          valueColor: AlwaysStoppedAnimation(context.scheme.primary),
        ),
      ),
    );
  }

  Widget _audioButton(BuildContext context) {
    return Material(
      color: context.scheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _speak(widget.word),
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _speaking
                ? const Icon(Icons.stop_rounded, key: ValueKey('stop'), color: Colors.white, size: 22)
                : const Icon(Icons.volume_up_rounded, key: ValueKey('play'), color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- yazım uyarıları
  Widget _writingRules(BuildContext context, Word word, DictionaryRepository repo) {
    final rules = repo.rulesForWord(word.word);
    if (rules.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'Sık Karıştırılan Yazım'),
          for (final r in rules.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: WritingRuleCard(
                wrongForm: r.wrongForm,
                correctForm: r.correctForm,
                ruleLabel: r.typeLabel,
                explanation: r.explanation,
                exams: r.exams,
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- kök ve ekler
  Widget _morphology(BuildContext context, Word word) {
    if (word.morphology.isEmpty) return const SizedBox.shrink();
    final c = context.scheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'Kök ve Ekler'),
          for (final m in word.morphology.take(4))
            Container(
              margin: const EdgeInsets.only(bottom: Gap.sm),
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: c.secondary.withValues(alpha: 0.06),
                borderRadius: Radii.md,
                border: Border.all(color: c.secondary.withValues(alpha: 0.20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İki satır: yüzey → kök, sonra ekler. Tek satırda
                  // "kitaplarımızdan + lar + ımız + dan" dar ekranda taşar.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          m.surface,
                          style: AppType.display(16, color: c.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text('→', style: AppType.body(12, color: context.mutedText)),
                      const SizedBox(width: Gap.sm),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.secondary.withValues(alpha: 0.16),
                            borderRadius: Radii.sm,
                          ),
                          child: Text(
                            m.root,
                            style: AppType.display(14, color: c.secondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (m.suffixes.isNotEmpty) ...[
                    const SizedBox(height: Gap.sm),
                    Text(
                      '+ ${m.suffixes.join(' + ')}',
                      style: AppType.mono(10.5, color: context.mutedText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: Gap.sm),
                  Text(m.explanation, style: AppType.body(12, color: context.mutedText)),
                  if (m.note != null) ...[
                    const SizedBox(height: Gap.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 12, color: c.tertiary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            m.note!,
                            style: AppType.body(11.5, color: c.tertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- anlamlar
  Widget _meanings(BuildContext context, Word word) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: 'Anlam Katmanları · ${word.meanings.length}'),
          for (final m in word.meanings)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: _meaningCard(context, m),
            ),
        ],
      ),
    );
  }

  Widget _meaningCard(BuildContext context, Meaning m) {
    final c = context.scheme;

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: context.paperSurface,
        borderRadius: Radii.md,
        border: Border(
          left: BorderSide(color: senseColor(m.sense).withValues(alpha: 0.55), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SenseChip(sense: m.sense, wordType: m.wordType)),
              ConfidenceBadge(confidence: m.confidence),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(m.definition, style: AppType.definition(14.5, color: c.onSurface)),

          if (m.exampleModern != null) ...[
            const SizedBox(height: Gap.lg),
            _example(
              context,
              m.exampleModern!,
              'Günlük dilde',
              c.secondary,
            ),
          ],

          if (m.exampleClassic != null) ...[
            const SizedBox(height: Gap.md),
            _example(
              context,
              m.exampleClassic!,
              m.exampleAuthor != null ? m.exampleAuthor! : 'Klasik edebiyattan',
              c.tertiary,
            ),
          ],

          // Alıntı yoksa neden olduğunu açıkla — dürüstlük ilkesi.
          if (m.exampleClassic == null && m.exampleNote != null) ...[
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: c.tertiary.withValues(alpha: 0.07),
                borderRadius: Radii.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.balance_rounded, size: 13, color: c.tertiary),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      m.exampleNote!,
                      style: AppType.body(11.5, color: c.tertiary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _example(BuildContext context, String sentence, String source, Color accent) {
    return Container(
      padding: const EdgeInsets.only(left: Gap.lg),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent.withValues(alpha: 0.4), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“$sentence”', style: AppType.quote(13.5, color: context.scheme.onSurface)),
          const SizedBox(height: 3),
          Text(turkishUpper(source), style: AppType.label(9, color: accent)),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- ilişkiler
  Widget _relations(BuildContext context, Word word, DictionaryRepository repo) {
    if (word.relations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'İlişki Ağı'),
          ClipRRect(
            borderRadius: Radii.md,
            child: ColoredBox(
              color: context.paperSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: RelationGraph(
                  word: word,
                  onNodeTap: (w) {
                    final target = repo.lookup(w);
                    if (target != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WordDetailScreen(word: target.word),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          for (final rel in word.relations.take(8))
            _relationRow(context, rel, repo),
        ],
      ),
    );
  }

  Widget _relationRow(BuildContext context, Relation rel, DictionaryRepository repo) {
    final target = repo.lookup(rel.word);
    final color = switch (rel.type) {
      'synonym' => const Color(0xFF2F6B5E),
      'antonym' => const Color(0xFFB5533C),
      'derivative' => const Color(0xFFC8922F),
      _ => context.scheme.onSurface,
    };

    return InkWell(
      onTap: target == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WordDetailScreen(word: target.word)),
              ),
      borderRadius: Radii.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
        child: Row(
          children: [
            Container(width: 3, height: 26, color: color.withValues(alpha: 0.5)),
            const SizedBox(width: Gap.md),
            SizedBox(
              width: 92,
              child: Text(rel.typeLabel, style: AppType.body(11, color: context.mutedText)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rel.word,
                    style: AppType.display(15, color: context.scheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rel.note != null)
                    Text(
                      rel.note!,
                      style: AppType.body(10.5, color: context.scheme.tertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (target == null)
              Icon(Icons.schedule_rounded, size: 13, color: context.mutedText)
            else
              Icon(Icons.chevron_right_rounded, size: 16, color: context.mutedText),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- alt
  Widget _footer(BuildContext context, Word word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.xl),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.paperSurface.withValues(alpha: 0.5),
        borderRadius: Radii.md,
        border: Border.all(color: context.subtleLine),
      ),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_outlined, size: 15, color: context.mutedText),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DİKSİYON KOÇU', style: AppType.label(9.5, color: context.mutedText)),
                const SizedBox(height: 2),
                Text(
                  'Kelimeyi okuyun, puanınızı görün',
                  style: AppType.body(12, color: context.mutedText),
                ),
              ],
            ),
          ),
          Text(
            'Faz 4',
            style: AppType.label(9.5, color: context.mutedText),
          ),
        ],
      ),
    );
  }
}