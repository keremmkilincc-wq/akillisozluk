// ============================================================================
//  TERSİ SÖZLÜK EKRANI
//
//  Kullanıcı kelimeyi hatırlayamıyorsa tanımını yazar. Uygulama en yakın
//  kelimeleri sıralar. Tamamen çevrimdışı: LLM yok, vektör yok — yalnızca
//  kendi sözlük verimiz üzerinden BM25 benzeri skorlama.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/reverse_dictionary.dart';
import '../core/theme.dart';
import '../data/dictionary_repository.dart';
import 'widgets/common.dart';
import 'word_detail_screen.dart';

class ReverseScreen extends StatefulWidget {
  const ReverseScreen({super.key});

  @override
  State<ReverseScreen> createState() => _ReverseScreenState();
}

class _ReverseScreenState extends State<ReverseScreen> {
  final _controller = TextEditingController();

  List<ReverseHit> _hits = [];
  bool _searched = false;

  static const _examples = <(String, String)>[
    (
      'Bir şeyin tam gerçekleşeceği sırada vazgeçme durumu',
      'tereddüt'
    ),
    (
      'Birine karşı duyulan derin sevgi ve saygı',
      'hürmet'
    ),
    (
      'Uzun süre bekledikten sonra gelen sevinç',
      'hasret'
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String phrase) {
    final repo = context.read<DictionaryRepository>();
    setState(() {
      _hits = repo.reverseSearch(phrase);
      _searched = true;
    });
  }

  void _open(ReverseHit hit) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WordDetailScreen(word: hit.word)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tersi Sözlük', style: AppType.display(19, color: context.scheme.onSurface)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
          children: [
            Text(
              'Kelime aklının ucunda ama\nçıkmıyor mu?',
              style: AppType.display(24, color: context.scheme.onSurface, height: 1.25),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Nasıl bir şey olduğunu yaz. Tanımını arıyoruz, ismini değil.',
              style: AppType.body(13.5, color: context.mutedText),
            ),
            const SizedBox(height: Gap.lg),

            _input(context),
            const SizedBox(height: Gap.xl),

            if (!_searched)
              ..._idle(context)
            else if (_hits.isEmpty)
              ..._empty(context)
            else
              ..._results(context),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- giriş
  Widget _input(BuildContext context) {
    final c = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.search,
          onSubmitted: _run,
          style: AppType.body(15, color: c.onSurface, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Örn: Bir şeyin tam gerçekleşeceği sırada vazgeçme durumu',
            hintMaxLines: 3,
            border: OutlineInputBorder(
              borderRadius: Radii.md,
              borderSide: BorderSide(color: context.subtleLine),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.md,
              borderSide: BorderSide(color: context.subtleLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Radii.md,
              borderSide: BorderSide(color: c.primary, width: 1.6),
            ),
            contentPadding: const EdgeInsets.all(Gap.lg),
          ),
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _run(_controller.text),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Ara'),
            ),
            const Spacer(),
            if (_searched)
              TextButton(
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _hits = [];
                    _searched = false;
                  });
                },
                child: Text('Temizle', style: AppType.body(13, color: context.mutedText)),
              ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------- boş durum
  List<Widget> _idle(BuildContext context) {
    return [
      const SectionHeader(label: 'Örnekler'),
      for (final (phrase, hint) in _examples)
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: _exampleCard(context, phrase, hint),
        ),
      const SizedBox(height: Gap.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: context.mutedText),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Bu özellik çevrimdışı çalışır. Cevabın kendi sözlük verimizden gelir, '
              'yapay zekaya gönderilmez.',
              style: AppType.body(11.5, color: context.mutedText, height: 1.5),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _exampleCard(BuildContext context, String phrase, String hint) {
    return Material(
      color: context.paperSurface,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: () {
          _controller.text = phrase;
          _controller.selection = TextSelection.collapsed(offset: phrase.length);
          _run(phrase);
        },
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: context.subtleLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '"$phrase"',
                  style: AppType.quote(13, color: context.scheme.onSurface),
                ),
              ),
              const SizedBox(width: Gap.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.scheme.primary.withValues(alpha: 0.10),
                  borderRadius: Radii.sm,
                ),
                child: Text(
                  '→ $hint',
                  style: AppType.body(11.5, color: context.scheme.primary, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- boş durum
  List<Widget> _empty(BuildContext context) {
    return [
      const SizedBox(height: Gap.xl),
      Icon(Icons.search_off_rounded, size: 32, color: context.mutedText.withValues(alpha: 0.5)),
      const SizedBox(height: Gap.lg),
      Text(
        'Bu tanıma uyan kelime bulamadım',
        style: AppType.display(17, color: context.scheme.onSurface),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: Gap.sm),
      Text(
        'Farklı sözcüklerle dene ya da tanımı biraz genişlet. '
        'Eş anlamlı kullanmak isabeti artırır.',
        style: AppType.body(12.5, color: context.mutedText),
        textAlign: TextAlign.center,
      ),
    ];
  }

  // ---------------------------------------------------------- sonuçlar
  List<Widget> _results(BuildContext context) {
    return [
      Row(
        children: [
          Text('${_hits.length} aday', style: AppType.label(10, color: context.mutedText)),
          const SizedBox(width: Gap.md),
          Expanded(child: Container(height: 1, color: context.subtleLine)),
        ],
      ),
      const SizedBox(height: Gap.md),
      for (final hit in _hits) _resultCard(context, hit),
    ];
  }

  Widget _resultCard(BuildContext context, ReverseHit hit) {
    final c = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Material(
        color: context.paperSurface,
        borderRadius: Radii.md,
        child: InkWell(
          onTap: () => _open(hit),
          borderRadius: Radii.md,
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              borderRadius: Radii.md,
              border: Border.all(color: context.subtleLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hit.word,
                        style: AppType.display(22, color: c.onSurface),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    _scoreBadge(context, hit.score),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  hit.matchedDefinition,
                  style: AppType.definition(13.5, color: context.mutedText),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Gap.md),
                // Neden bu kelime? — eşleşen kavramlar açıkça gösterilir.
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final term in hit.matchedTerms.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.secondary.withValues(alpha: 0.10),
                          borderRadius: Radii.pill,
                        ),
                        child: Text(
                          term,
                          style: AppType.body(11, color: c.secondary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreBadge(BuildContext context, double score) {
    final c = context.scheme;
    final percent = (score * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.10),
        borderRadius: Radii.pill,
      ),
      child: Text(
        '%$percent',
        style: AppType.mono(11, color: c.primary),
      ),
    );
  }
}