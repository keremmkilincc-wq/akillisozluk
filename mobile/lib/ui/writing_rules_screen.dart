// ============================================================================
//  YAZIM KURALLARI EKRANI — Modül 6
//
//  Sınavlara hazırlananın en sık ihtiyacı: "kitabe mi kitabı mı?"
//
//  Bu içerik tamamen özgündür: kural dilbilgisinden türetilir, hiçbir
//  sözlük metni kopyalanmaz. Telif riski sıfır, değer yüksek.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/turkish.dart';
import '../data/dictionary_repository.dart';
import '../data/models.dart';
import 'word_detail_screen.dart';

/// Sınav filtreleri.
const _examFilters = <(String, String)>[
  ('tümü', 'Tümü'),
  ('yks', 'YKS'),
  ('kpss', 'KPSS'),
  ('ales', 'ALES'),
  ('yds', 'YDS'),
];

class WritingRulesScreen extends StatefulWidget {
  const WritingRulesScreen({super.key});

  @override
  State<WritingRulesScreen> createState() => _WritingRulesScreenState();
}

class _WritingRulesScreenState extends State<WritingRulesScreen> {
  String _filter = 'tümü';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<DictionaryRepository>();

    var rules = repo.allRules;
    if (_filter != 'tümü') {
      rules = rules.where((r) => r.exams.contains(_filter)).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      rules = rules
          .where((r) =>
              r.baseWord.toLowerCase().contains(q) ||
              r.wrongForm.toLowerCase().contains(q) ||
              r.correctForm.toLowerCase().contains(q))
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Yazım Kuralları',
            style: AppType.display(19, color: context.scheme.onSurface)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xs, Gap.xl, Gap.md),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppType.body(14.5, color: context.scheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Kelime ara…',
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: context.mutedText),
                  isDense: true,
                ),
              ),
            ),
            _filters(context),
            Expanded(
              child: rules.isEmpty
                  ? _empty(context)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xxl),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.md),
                          child: Text(
                            '${rules.length} kural',
                            style: AppType.label(10, color: context.mutedText),
                          ),
                        ),
                        for (final r in rules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Gap.md),
                            child: _ruleCard(context, r, repo),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- filtreler
  Widget _filters(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        children: [
          for (final (key, label) in _examFilters)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: _filterChip(context, key, label),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, String key, String label) {
    final selected = _filter == key;
    final c = context.scheme;

    return Material(
      color: selected ? c.primary : context.paperSurface,
      borderRadius: Radii.pill,
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: Radii.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: Radii.pill,
            border: Border.all(
              color: selected ? c.primary : context.subtleLine,
            ),
          ),
          child: Text(
            label,
            style: AppType.body(
              12.5,
              weight: FontWeight.w600,
              color: selected ? c.onPrimary : context.mutedText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_alt_off_outlined, size: 30, color: context.mutedText.withValues(alpha: 0.5)),
          const SizedBox(height: Gap.lg),
          Text(
            'Bu filtrede kural yok',
            style: AppType.display(16, color: context.scheme.onSurface),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Başka bir sınav seç ya da aramayı değiştir.',
            style: AppType.body(12.5, color: context.mutedText),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- kart
  Widget _ruleCard(BuildContext context, WritingRule rule, DictionaryRepository repo) {
    final c = context.scheme;
    final target = repo.lookup(rule.baseWord);

    return Material(
      color: context.paperSurface,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: target == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WordDetailScreen(word: target.word),
                  ),
                ),
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
              // Yanlış → Doğru: kartın asıl mesajı, en büyük tipografide
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      rule.wrongForm,
                      style: AppType.display(17, color: context.mutedText).copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: context.destructive.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 15, color: context.mutedText),
                  ),
                  Flexible(
                    child: Text(
                      rule.correctForm,
                      style: AppType.display(18, color: c.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),

              // Kural türü + temel kelimeye gidiş
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.secondary.withValues(alpha: 0.10),
                      borderRadius: Radii.sm,
                    ),
                    child: Text(
                      rule.typeLabel,
                      style: AppType.label(9, color: c.secondary),
                    ),
                  ),
                  if (target != null) ...[
                    const Spacer(),
                    Icon(Icons.arrow_outward, size: 13, color: context.mutedText),
                  ],
                ],
              ),
              const SizedBox(height: Gap.md),

              Text(
                rule.explanation,
                style: AppType.body(12.5, color: context.mutedText, height: 1.55),
              ),

              if (rule.exams.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  children: [
                    for (final e in rule.exams)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.tertiary.withValues(alpha: 0.12),
                          borderRadius: Radii.sm,
                        ),
                        child: Text(
                          turkishUpper(e),
                          style: AppType.label(8.5, color: c.tertiary),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}