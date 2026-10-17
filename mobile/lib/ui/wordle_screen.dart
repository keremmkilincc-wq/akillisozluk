// ============================================================================
//  WORDLE EKRANI
//
//  5 harf, 6 deneme, Türkçe. Tamamen çevrimdışı: kelime listesi pakette,
//  günün cevabı gün numarasına göre tohumlanıyor, sunucu yok.
// ============================================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../core/wordle.dart';
import '../data/wordle_store.dart';

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  WordleEngine? _engine;
  String _input = '';
  String? _error;
  bool _loading = true;
  bool _revealing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await WordleWords.load();
      if (!mounted) return;
      setState(() {
        _engine = WordleEngine.forToday(
          answers: w.answers,
          allowed: w.pool,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Kelime listesi yüklenemedi: $e';
      });
    }
  }

  // ------------------------------------------------------------------ oynama

  void _onKey(String key) {
    final e = _engine;
    if (e == null || e.isOver || _revealing) return;

    setState(() {
      _error = null;
      if (key == 'backspace') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 5) {
        _input += key;
      }
    });
  }

  Future<void> _submit() async {
    final e = _engine;
    if (e == null || _input.length != 5 || e.isOver || _revealing) return;

    if (!e.isAllowed(_input)) {
      setState(() {
        _error = 'Bu kelime listede yok. Sözlükte olan bir kelime gir.';
        _input = '';
      });
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.selectionClick();

    // Puanlamayı hemen ekle; sonra satırları sırayla aç.
    e.guess(_input);
    final g = _input;
    setState(() {
      _input = '';
      _revealing = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _revealing = false);
    if (e.isWon) HapticFeedback.heavyImpact();
    debugPrint('[wordle] tahmin: $g');
  }

  // ------------------------------------------------------------------ çizim

  @override
  Widget build(BuildContext context) {
    final c = context.scheme;
    final e = _engine;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kelime Tahmini',
          style: AppType.display(19, color: c.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && e == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppType.body(13, color: context.mutedText),
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(child: _board(e!)),
                      if (_error != null) _errorBar(),
                      _keyboard(),
                      const SizedBox(height: Gap.sm),
                    ],
                  ),
                ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: Gap.sm,
      ),
      color: context.destructive.withValues(alpha: 0.12),
      child: Text(
        _error!,
        textAlign: TextAlign.center,
        style: AppType.body(12, color: context.destructive),
      ),
    );
  }

  Widget _board(WordleEngine e) {
    final history = e.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl),
      children: [
        Center(child: _statusLine(e)),
        const SizedBox(height: Gap.xl),
        for (var i = 0; i < WordleEngine.maxGuesses; i++)
          _row(i < history.length ? history[i] : null, i),
        const SizedBox(height: Gap.xl),
        if (e.isOver) _endCard(e),
      ],
    );
  }

  Widget _statusLine(WordleEngine e) {
    String text;
    if (e.isWon) {
      text = e.guessesUsed == 1
          ? 'İlk tahminde buldun.'
          : '${e.guessesUsed}. tahminde buldun.';
    } else if (e.isOver) {
      text = 'Bulamadın. Doğru kelime: ${_engine!.answer}';
    } else {
      text = '${WordleEngine.maxGuesses - e.guessesUsed} hak kaldı';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: context.subtleLine.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppType.label(11.5, color: context.mutedText),
      ),
    );
  }

  Widget _row(GuessResult? r, int index) {
    // Son satır: kullanıcının yazdığı harfler.
    if (r == null && index == _engine!.guessesUsed && !_engine!.isOver) {
      return _tileRow(
        index < _engine!.history.length ? null : _input,
        null,
        active: true,
      );
    }
    return _tileRow(r?.guess, r?.states, active: false);
  }

  Widget _tileRow(String? word, List<LetterState>? states,
      {required bool active}) {
    const size = 54.0;
    final letters = (word ?? '').padRight(5).split('');
    final isActiveRow = active;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              width: size,
              height: size,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: states == null
                    ? (isActiveRow && i < _input.length
                        ? context.subtleLine.withValues(alpha: 0.30)
                        : null)
                    : _stateColor(states[i]),
                borderRadius: BorderRadius.circular(6),
                border: states == null
                    ? Border.all(color: context.subtleLine, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                letters[i].isEmpty ? '' : letters[i],
                style: AppType.body(
                  22,
                  weight: FontWeight.w700,
                  color: states == null
                      ? context.scheme.onSurface
                      : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _stateColor(LetterState s) {
    switch (s) {
      case LetterState.correct:
        return const Color(0xFF3A9B5C);
      case LetterState.present:
        return const Color(0xFFC9A227);
      case LetterState.absent:
        return const Color(0xFF5B6472);
    }
  }

  Widget _endCard(WordleEngine e) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: context.subtleLine.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            e.isWon ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
            size: 22,
            color: context.scheme.primary,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              e.isWon
                  ? 'Aferin. Kelime: ${e.answer}'
                  : 'Kelime: ${e.answer}. Yarın yeni bir kelime var.',
              style: AppType.body(13, color: context.scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ klavye

  Widget _keyboard() {
    // Bir harfin daha önce doğru yerde bulunduğu gösterilir.
    final best = <String, LetterState>{};
    for (final r in _engine!.history) {
      for (var i = 0; i < 5; i++) {
        final ch = r.guess[i];
        final prev = best[ch];
        if (prev == null ||
            (prev == LetterState.absent && r.states[i] != LetterState.absent) ||
            (prev == LetterState.present &&
                r.states[i] == LetterState.correct)) {
          best[ch] = r.states[i];
        }
      }
    }

    // Klavye TURKCE ALFABESINE gore dizildi, QWERTY'e gore degil.
    //
    // QWERTY denen varyantta 'q', 'w' ve 'x' tuslari var — bu harfler
    // Turkce kelime OLUSTREMEZ. Onceli basinda onlari sunmak kullaniciya
    // olamaz tuslar gostermek demek: basar, "kelime listede yok" hatasi
    // alir. Klavye alfabetik kuruldu.
    const rows = [
      ['a', 'b', 'c', 'ç', 'd', 'e', 'f', 'g', 'ğ', 'h'],
      ['ı', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'ö', 'p'],
      ['r', 's', 'ş', 't', 'u', 'ü', 'v', 'y', 'z'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.only(top: Gap.xs, left: r == 2 ? Gap.xl : 0,
                right: r == 2 ? Gap.xl : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (r == 2)
                  _actionKey(Icons.arrow_back_rounded, 'backspace'),
                for (final key in rows[r])
                  _letterKey(key, best[key]),
                if (r == 2) _actionKey(Icons.check_rounded, null, _submit),
              ],
            ),
          ),
        if (_input.length == 5)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: TextButton.icon(
              onPressed: _revealing ? null : _submit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('Tahmin et', style: AppType.body(13)),
            ),
          ),
      ],
    );
  }

  Widget _letterKey(String key, LetterState? state) {
    final bg = switch (state) {
      LetterState.correct => const Color(0xFF3A9B5C),
      LetterState.present => const Color(0xFFC9A227),
      LetterState.absent => const Color(0xFF5B6472),
      null => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: 30,
        height: 44,
        child: Material(
          color: bg ?? context.subtleLine.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _onKey(key),
            child: Center(
              child: Text(
                key.toUpperCase(),
                style: AppType.label(
                  12,
                  color: state == null
                      ? context.scheme.onSurface
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey(IconData icon, String? key, [VoidCallback? onTap]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        width: key != null ? 46 : 56,
        height: 44,
        child: Material(
          color: context.subtleLine.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              final action = onTap;
              if (action != null) {
                action();
              } else if (key != null) {
                _onKey(key);
              }
            },
            child: Icon(icon, size: 20, color: context.scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
