// ============================================================================
//  ARAMA EKRANI
//
//  Yazarken sonuçlar anında akar. Bulunamayan yazımlarda "Bunu mu demek
//  istediniz?" şeridi çıkar — uygulamanın en görünür akıllı özelliği.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/search.dart';
import '../core/theme.dart';
import '../data/dictionary_repository.dart';
import '../data/models.dart';
import 'widgets/common.dart';
import 'word_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  /// URL üzerinden gelinen başlangıç sorgusu (QA için).
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<Word> _results = [];
  List<SearchHit> _suggestions = [];

  /// Kullanıcının yazdığı hâli standart yazımdan ayrık ise doğru hâli.
  /// "şöför" → "şoför". Yazım kuralı tablosundan gelir.
  String? _correction;
  bool _hasQuery = false;

  /// Yazım hatası örnekleri — bu fazın amacı bu davranışı göstermek.
  static const _probes = ['şoför', 'yalnış', 'kirbit', 'kitaplarımızdan', 'güneş batmadan'];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      _controller.selection =
          TextSelection.collapsed(offset: widget.initialQuery!.length);
    }
    _controller.addListener(_run);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _controller.removeListener(_run);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run() {
    final repo = context.read<DictionaryRepository>();
    final q = _controller.text.trim();

    if (q.isEmpty) {
      setState(() {
        _results = [];
        _suggestions = [];
        _correction = null;
        _hasQuery = false;
      });
      return;
    }

    final outcome = repo.search(q);

    // Kullanıcının yazdığı hâli standart Türkçe yazımdan ayrık mı?
    // "şöför" katlamada "şoför" ile aynı hâle gelir; kullanıcı yine de
    // yanlış yazdığını bilmelidir.
    final correction = repo.correctSpelling(q);

    setState(() {
      _results = outcome.results.map((h) => repo.lookup(h.word)).whereType<Word>().toList();
      _suggestions = outcome.suggestions;
      _correction = correction;
      _hasQuery = true;
    });
  }

  void _acceptSuggestion(String word) {
    HapticFeedback.selectionClick();
    _controller.text = word;
    _controller.selection = TextSelection.collapsed(offset: word.length);
  }

  void _open(Word w) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WordDetailScreen(word: w.word)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DictionaryRepository>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _inputBar(context),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: !_hasQuery
                    ? _idleState(context)
                    : (_results.isEmpty && _suggestions.isEmpty)
                        ? _emptyState(context)
                        : _resultsList(context),
              ),
            ),
            if (_hasQuery && repo.size > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(
                  '${_results.length} sonuç',
                  style: AppType.body(11, color: context.mutedText),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- giriş
  Widget _inputBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              style: AppType.body(16.5, color: context.scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Kelime yazın…',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.mutedText),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: context.mutedText),
                        onPressed: () => _controller.clear(),
                      ),
              ),
            ),
          ),
          const SizedBox(width: Gap.xs),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('Kapat', style: AppType.body(13.5, color: context.mutedText)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- boş durum
  Widget _idleState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, 0),
      children: [
        Text(
          'Yazım hatası yaptığınızda\nyine de bulur.',
          style: AppType.display(24, color: context.scheme.onSurface, height: 1.25),
        ),
        const SizedBox(height: Gap.md),
        Text(
          'Aşağıdakilerden birine dokunun — arama motoru yazdığınız hâliyle '
          'değil, ne demek istediğinizle arar.',
          style: AppType.body(13.5, color: context.mutedText),
        ),
        const SizedBox(height: Gap.xl),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final p in _probes)
              _probeChip(context, p),
          ],
        ),
        const SizedBox(height: Gap.xxl),
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 14, color: context.mutedText),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                '"yalnış" → "yanlış" gibi düz harf yer değişimlerinde '
                'mesafe 2 değil 1 sayılır.',
                style: AppType.body(11.5, color: context.mutedText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _probeChip(BuildContext context, String text) {
    return Material(
      color: context.paperSurface,
      borderRadius: Radii.pill,
      child: InkWell(
        onTap: () {
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(offset: text.length);
        },
        borderRadius: Radii.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: Radii.pill,
            border: Border.all(color: context.subtleLine),
          ),
          child: Text(text, style: AppType.body(13.5, color: context.scheme.onSurface)),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 34, color: context.mutedText.withValues(alpha: 0.5)),
            const SizedBox(height: Gap.lg),
            Text(
              '"${_controller.text.trim()}" bulunamadı',
              style: AppType.display(18, color: context.scheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Farklı bir yazımla dene ya da terim olarak ara.',
              style: AppType.body(13, color: context.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- sonuçlar
  Widget _resultsList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
      children: [
        if (_correction != null) _correctionBanner(context, _correction!),
        if (_suggestions.isNotEmpty) _suggestionBanner(context),
        for (final w in _results)
          WordRow(
            word: w.word,
            definition: w.primaryMeaning,
            origin: w.origin,
            isPureTurkish: w.isPureTurkish,
            onTap: () => _open(w),
          ),
        if (_results.isEmpty && _suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Gap.lg),
            child: Text(
              'Yukarıdaki öneriye dokunarak doğru kelimeye geçebilirsiniz.',
              style: AppType.body(12, color: context.mutedText),
            ),
          ),
      ],
    );
  }

  /// "şöför yazdınız, doğru yazım şoför" şeridi.
  Widget _correctionBanner(BuildContext context, String correct) {
    final c = context.scheme;

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.destructive.withValues(alpha: 0.07),
        borderRadius: Radii.md,
        border: Border.all(color: context.destructive.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.spellcheck_rounded, size: 16, color: context.destructive),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOĞRU YAZIM',
                  style: AppType.label(9.5, color: context.destructive),
                ),
                const SizedBox(height: 3),
                Text(
                  correct,
                  style: AppType.display(17, color: c.onSurface),
                ),
              ],
            ),
          ),
          Material(
            color: context.destructive.withValues(alpha: 0.10),
            shape: const StadiumBorder(),
            child: InkWell(
              onTap: () {
                _controller.text = correct;
                _controller.selection =
                    TextSelection.collapsed(offset: correct.length);
              },
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 8),
                child: Text('Kabul et', style: AppType.body(12, color: context.destructive, weight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionBanner(BuildContext context) {
    final top = _suggestions.first;
    final others = _suggestions.skip(1).take(2).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.scheme.tertiary.withValues(alpha: 0.10),
        borderRadius: Radii.md,
        border: Border.all(color: context.scheme.tertiary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 14, color: context.scheme.tertiary),
              const SizedBox(width: Gap.sm),
              Text(
                'BUNU MU DEMEK İSTEDİNİZ?',
                style: AppType.label(9.5, color: context.scheme.tertiary),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              _suggestionChip(context, top.word, isPrimary: true),
              for (final o in others) _suggestionChip(context, o.word),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(BuildContext context, String word, {bool isPrimary = false}) {
    return Material(
      color: isPrimary ? context.scheme.tertiary : Colors.transparent,
      borderRadius: Radii.pill,
      child: InkWell(
        onTap: () => _acceptSuggestion(word),
        borderRadius: Radii.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: Radii.pill,
            border: Border.all(
              color: isPrimary
                  ? context.scheme.tertiary
                  : context.scheme.tertiary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            word,
            style: AppType.display(
              15,
              color: isPrimary
                  ? (context.isDark ? context.scheme.onSurface : Colors.white)
                  : context.scheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}