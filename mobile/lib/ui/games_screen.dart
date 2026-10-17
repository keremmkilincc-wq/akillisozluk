// ============================================================================
//  KELİME OYUNLARI — Modül 5
//
//  İki oyun, ikisi de kendi verimizle çalışır, ikisi de çevrimdışı:
//
//   1. "Hangi Kelime Öz Türkçe?" — is_pure_turkish alanı Faz 0'dan hazır
//   2. "Eş Anlamlı Düellosu" — 60 saniye, relations tablosundan
//
//  Günlük Wordle bu fazda yok: 139 kelimelik veride 5 harfli yeterli
//  havuz yok. Havuz büyüyünce eklenecek; şimdi koymak sahte içerik olur.
// ============================================================================

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import 'wordle_screen.dart';
import '../data/dictionary_repository.dart';
import '../data/models.dart';
import 'widgets/common.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelime Oyunları', style: AppType.display(19, color: context.scheme.onSurface)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xxl),
          children: [
            Text(
              'Oynayarak öğren.',
              style: AppType.display(24, color: context.scheme.onSurface),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Her iki oyun da sözlük verimiz üzerinden üretilir ve çevrimdışı çalışır.',
              style: AppType.body(13.5, color: context.mutedText),
            ),
            const SizedBox(height: Gap.xl),

            // Wordle listenin başında: en bilinen oyun, ilk bakılan yer.
            _GameCard(
              icon: Icons.grid_view_rounded,
              title: 'Kelime Tahmini',
              subtitle: '5 harf, 6 deneme. Günün kelimesi herkes için aynı',
              accent: context.scheme.primary,
              route: (_) => const WordleScreen(),
            ),
            const SizedBox(height: Gap.md),

            _GameCard(
              icon: Icons.eco_outlined,
              title: 'Hangi Kelime Öz Türkçe?',
              subtitle: 'İki seçenek, bir tanesi Türkçe kökenli',
              accent: originColor('Öz Türkçe'),
              route: (_) => const PureTurkishGame(),
            ),
            const SizedBox(height: Gap.md),

            _GameCard(
              icon: Icons.timer_outlined,
              title: 'Eş Anlamlı Düellosu',
              subtitle: '60 saniye, doğru eş anlamlıyı bul',
              accent: originColor('Arapça'),
              route: (_) => const SynonymDuel(),
            ),

            const SizedBox(height: Gap.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 13, color: context.mutedText),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Günlük kelime bulmaca ve iki kişilik online yarışma, kelime '
                    'havuzu büyüdükten sonra eklenir. Şimdilik 5 harfli yeterli '
                    'havuz yok — sahte soru koymak yerine bekliyoruz.',
                    style: AppType.body(11.5, color: context.mutedText, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget Function(BuildContext) route;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.paperSurface,
      borderRadius: Radii.lg,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: route)),
        borderRadius: Radii.lg,
        child: Container(
          padding: const EdgeInsets.all(Gap.xl),
          decoration: BoxDecoration(
            borderRadius: Radii.lg,
            border: Border.all(color: context.subtleLine),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: Radii.md,
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.display(17, color: context.scheme.onSurface)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppType.body(12.5, color: context.mutedText)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: context.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
//  OYUN 1 — HANGİ KELİME ÖZ TÜRKÇE?
// ============================================================================

class PureTurkishGame extends StatefulWidget {
  const PureTurkishGame({super.key});

  @override
  State<PureTurkishGame> createState() => _PureTurkishGameState();
}

class _PureTurkishGameState extends State<PureTurkishGame> {
  final _rng = math.Random();

  List<Word> _pair = [];
  int _correctIndex = 0;
  int _question = 0;
  int _score = 0;
  int? _chosen;
  bool _finished = false;

  static const _total = 10;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    final repo = context.read<DictionaryRepository>();
    final pure = repo.pureTurkish();
    final mixed = repo.all.where((w) => !w.isPureTurkish).toList();

    if (pure.length < 2 || mixed.isEmpty) {
      setState(() => _finished = true);
      return;
    }

    final a = pure[_rng.nextInt(pure.length)];
    Word b;
    do {
      b = mixed[_rng.nextInt(mixed.length)];
    } while (b.word == a.word);

    final order = _rng.nextBool();
    setState(() {
      _pair = order ? [a, b] : [b, a];
      _correctIndex = order ? 0 : 1;
      _question++;
      _chosen = null;
    });
  }

  void _pick(int index) {
    if (_chosen != null) return;
    HapticFeedback.selectionClick();

    final correct = index == _correctIndex;
    setState(() => _chosen = index);
    if (correct) _score++;

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_question >= _total) {
        setState(() => _finished = true);
      } else {
        _next();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hangi Kelime Öz Türkçe?')),
      body: SafeArea(
        child: _finished ? _result(context) : _play(context),
      ),
    );
  }

  Widget _play(BuildContext context) {
    final c = context.scheme;

    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        Row(
          children: [
            Text('SORU $_question/$_total', style: AppType.label(10, color: context.mutedText)),
            const Spacer(),
            Text(scoreLabel, style: AppType.label(10, color: c.primary)),
          ],
        ),
        const SizedBox(height: Gap.sm),
        LinearProgressIndicator(
          value: _question / _total,
          minHeight: 4,
          backgroundColor: context.subtleLine,
          valueColor: AlwaysStoppedAnimation(c.primary),
        ),
        const SizedBox(height: Gap.xl),
        Text(
          'Hangisi Türkçe kökenli?',
          style: AppType.display(22, color: c.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Gap.xl),
        for (var i = 0; i < _pair.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _option(context, i),
          ),
        const SizedBox(height: Gap.lg),
        if (_chosen != null) _explanation(context),
      ],
    );
  }

  String get scoreLabel => 'PUAN $_score';

  Widget _option(BuildContext context, int index) {
    final c = context.scheme;
    final word = _pair[index];
    final isCorrect = index == _correctIndex;
    final chosen = _chosen == index;

    Color border = context.subtleLine;
    Color? fill;
    if (_chosen != null) {
      if (isCorrect) {
        border = c.secondary;
        fill = c.secondary.withValues(alpha: 0.08);
      } else if (chosen) {
        border = context.destructive;
        fill = context.destructive.withValues(alpha: 0.07);
      }
    }

    return Material(
      color: fill ?? context.paperSurface,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: _chosen == null ? () => _pick(index) : null,
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.all(Gap.xl),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: border, width: 1.4),
          ),
          child: Column(
            children: [
              Text(word.word, style: AppType.display(26, color: c.onSurface)),
              if (_chosen != null) ...[
                const SizedBox(height: Gap.sm),
                OriginBadge(origin: word.origin, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _explanation(BuildContext context) {
    final correct = _pair[_correctIndex];
    final c = context.scheme;
    final wasRight = _chosen == _correctIndex;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: (wasRight ? c.secondary : context.destructive).withValues(alpha: 0.08),
        borderRadius: Radii.md,
        border: Border.all(
          color: (wasRight ? c.secondary : context.destructive).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            wasRight ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: wasRight ? c.secondary : context.destructive,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              '${correct.word}: ${correct.origin} — ${correct.primaryMeaning}',
              style: AppType.body(12.5, color: context.mutedText, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final c = context.scheme;
    final pct = (_score / _total * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '%$pct',
              style: AppType.display(56, color: c.primary),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              '$_score / $_total doğru',
              style: AppType.display(18, color: c.onSurface),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: () {
                setState(() {
                  _score = 0;
                  _question = 0;
                  _finished = false;
                });
                _next();
              },
              child: const Text('Tekrar oyna'),
            ),
            const SizedBox(height: Gap.sm),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('Geri', style: AppType.body(13.5, color: context.mutedText)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  OYUN 2 — EŞ ANLAMLI DÜELLOSU (60 saniye)
// ============================================================================

class SynonymDuel extends StatefulWidget {
  const SynonymDuel({super.key});

  @override
  State<SynonymDuel> createState() => _SynonymDuelState();
}

class _SynonymDuelState extends State<SynonymDuel> {
  static const _duration = 60;

  final _rng = math.Random();
  List<Word> _pool = [];

  Word? _target;
  String _correct = '';
  List<String> _options = [];
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  int _remaining = _duration;
  bool _running = false;
  bool _wrongFlash = false;

  @override
  void initState() {
    super.initState();
    final repo = context.read<DictionaryRepository>();
    _pool = repo.all
        .where((w) => w.relations.any((r) => r.type == 'synonym'))
        .toList();
  }

  void _start() {
    setState(() {
      _running = true;
      _score = 0;
      _streak = 0;
      _remaining = _duration;
      _best = 0;
    });
    _nextQuestion();
    _tick();
  }

  Future<void> _tick() async {
    while (mounted && _running && _remaining > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_running) return;
      setState(() => _remaining--);
    }
    if (mounted && _remaining <= 0) {
      setState(() {
        _running = false;
        _best = _score > _best ? _score : _best;
      });
    }
  }

  void _nextQuestion() {
    if (_pool.isEmpty) return;

    final target = _pool[_rng.nextInt(_pool.length)];
    final synonyms = target.relations
        .where((r) => r.type == 'synonym')
        .map((r) => r.word)
        .toList();
    if (synonyms.isEmpty) return;

    final correct = synonyms[_rng.nextInt(synonyms.length)];

    // Distraktörler: havuzdan rastgele, doğru olmayan
    final distractors = <String>{};
    while (distractors.length < 3) {
      final w = _pool[_rng.nextInt(_pool.length)].word;
      if (w != target.word && w != correct) distractors.add(w);
    }

    final options = [...distractors, correct]..shuffle(_rng);

    setState(() {
      _target = target;
      _correct = correct;
      _options = options;
    });
  }

  void _pick(String option) {
    if (!_running || _target == null) return;

    if (option == _correct) {
      HapticFeedback.selectionClick();
      _score++;
      _streak++;
      _nextQuestion();
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
      setState(() => _wrongFlash = true);
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _wrongFlash = false);
      });
      // Yanlışta soru değişmez — kullanıcı doğruyu görsün.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eş Anlamlı Düellosu')),
      body: SafeArea(
        child: _pool.isEmpty
            ? _noData(context)
            : (_running ? _play(context) : _intro(context)),
      ),
    );
  }

  Widget _noData(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Text(
          'Bu oyun için eş anlamlı kaydı olan kelime gerekli. Veri seti '
          'büyüdüğünde aktif olacak.',
          style: AppType.body(13.5, color: context.mutedText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_remaining == _duration) ...[
              Text('60 saniye', style: AppType.display(34, color: context.scheme.primary)),
              const SizedBox(height: Gap.lg),
              Text(
                'Ekrana gelen kelimenin eş anlamlısını seç.\nYanlış cevap seriyi kırar.',
                style: AppType.body(14, color: context.mutedText, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.xxl),
            ] else ...[
              Text('$_best', style: AppType.display(56, color: context.scheme.primary)),
              const SizedBox(height: Gap.sm),
              Text('doğru cevap', style: AppType.body(14, color: context.mutedText)),
              const SizedBox(height: Gap.xxl),
            ],
            FilledButton.icon(
              onPressed: _start,
              icon: Icon(_remaining == _duration ? Icons.play_arrow_rounded : Icons.refresh_rounded),
              label: Text(_remaining == _duration ? 'Başla' : 'Tekrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _play(BuildContext context) {
    final c = context.scheme;
    final target = _target;

    if (target == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, 'PUAN', '$_score'),
              const Spacer(),
              _timeBar(context),
              const Spacer(),
              _stat(context, 'SERİ', '$_streak'),
            ],
          ),
          const SizedBox(height: Gap.xl),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Gap.xl),
            decoration: BoxDecoration(
              color: _wrongFlash
                  ? context.destructive.withValues(alpha: 0.10)
                  : context.paperSurface,
              borderRadius: Radii.lg,
              border: Border.all(
                color: _wrongFlash ? context.destructive : context.subtleLine,
                width: _wrongFlash ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  target.word,
                  style: AppType.display(34, color: c.onSurface),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'eş anlamlısı hangisi?',
                  style: AppType.body(12, color: context.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xl),

          for (final option in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: _optionButton(context, option),
            ),

          const Spacer(),

          // Yanlış cevapta doğruyu göster — öğrenme anı
          if (_wrongFlash)
            Text(
              'Doğrusu: $_correct',
              style: AppType.display(15, color: c.secondary),
            ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: AppType.label(9, color: context.mutedText)),
        const SizedBox(height: 2),
        Text(value, style: AppType.display(18, color: context.scheme.onSurface)),
      ],
    );
  }

  Widget _timeBar(BuildContext context) {
    final c = context.scheme;
    return SizedBox(
      width: 130,
      child: Column(
        children: [
          Text('$_remaining sn', style: AppType.mono(11, color: context.mutedText)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: Radii.pill,
            child: LinearProgressIndicator(
              value: _remaining / _duration,
              minHeight: 5,
              backgroundColor: context.subtleLine,
              valueColor: AlwaysStoppedAnimation(
                _remaining <= 10 ? context.destructive : c.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionButton(BuildContext context, String option) {
    final c = context.scheme;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: context.paperSurface,
        borderRadius: Radii.md,
        child: InkWell(
          onTap: () => _pick(option),
          borderRadius: Radii.md,
          child: Container(
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              borderRadius: Radii.md,
              border: Border.all(color: context.subtleLine),
            ),
            child: Text(
              option,
              style: AppType.display(17, color: c.onSurface),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}