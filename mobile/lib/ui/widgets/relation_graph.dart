// ============================================================================
//  İLİŞKİ AĞI
//
//  Merkezde kelime, çevresinde ilişkiler. Bağlantı türlerine göre gruplanır:
//  eş anlamlılar üst yarı, zıt anlamlılar alt yarı, akraba kelimeler dış halka.
//
//  Kuvvet tabanlı (force-directed) benzetim yerine belirlenimci (deterministik)
//  yerleşim kullanılıyor: her açılışta aynı görünüm, amaç üst üste binme
//  değil, okunabilirlik.
// ============================================================================

library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';

class RelationGraph extends StatefulWidget {
  final Word word;
  final ValueChanged<String> onNodeTap;

  const RelationGraph({super.key, required this.word, required this.onNodeTap});

  @override
  State<RelationGraph> createState() => _RelationGraphState();
}

class _RelationGraphState extends State<RelationGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  static const _typeOrder = ['synonym', 'antonym', 'derivative', 'related'];
  static const _typeColors = {
    'synonym': Color(0xFF2F6B5E),
    'antonym': Color(0xFFB5533C),
    'derivative': Color(0xFFC8922F),
    'related': Color(0xFF7C6BA8),
    'idiom': Color(0xFF4F9BA6),
  };

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relations = widget.word.relations.take(12).toList();

    if (relations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        child: Text(
          'Bu kelime için ilişki kaydı bulunmuyor.',
          style: AppType.body(12.5, color: context.mutedText),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: GestureDetector(
            onScaleUpdate: (d) {
              setState(() {
                _scale = (_scale * d.scale).clamp(0.7, 2.4);
                _pan += d.focalPointDelta;
              });
            },
            onDoubleTap: () => setState(() {
              _scale = 1.0;
              _pan = Offset.zero;
            }),
            child: ClipRRect(
              borderRadius: Radii.md,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _GraphPainter(
                      word: widget.word.word,
                      relations: relations,
                      scale: _scale,
                      pan: _pan,
                      pulse: _pulse.value,
                      lineColor: context.subtleLine,
                      centerColor: context.scheme.primary,
                      nodeFill: context.paperSurface,
                      nodeText: context.scheme.onSurface,
                      typeColors: _typeColors,
                      typeOrder: _typeOrder,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final t in _typeOrder)
              if (relations.any((r) => r.type == t))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _typeColors[t],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      relations.firstWhere((r) => r.type == t).typeLabel,
                      style: AppType.body(11, color: context.mutedText),
                    ),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}

class _Node {
  _Node(this.relation, this.center, this.angle);

  final Relation relation;
  final Offset center;
  final double angle;
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.word,
    required this.relations,
    required this.scale,
    required this.pan,
    required this.pulse,
    required this.lineColor,
    required this.centerColor,
    required this.nodeFill,
    required this.nodeText,
    required this.typeColors,
    required this.typeOrder,
  });

  final String word;
  final List<Relation> relations;
  final double scale;
  final Offset pan;
  final double pulse;
  final Color lineColor;
  final Color centerColor;
  final Color nodeFill;
  final Color nodeText;
  final Map<String, Color> typeColors;
  final List<String> typeOrder;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2) + pan;
    final center = origin;
    final radius = (size.width < size.height ? size.width : size.height) * 0.33 * scale;

    // Yerleşim: tür başına ayrı yarım daire dilimi
    final nodes = <_Node>[];
    var index = 0;

    for (final type in typeOrder) {
      final ofType = relations.where((r) => r.type == type).toList();
      if (ofType.isEmpty) continue;

      final typeIndex = typeOrder.indexOf(type);
      final slot = math.pi * 2 / typeOrder.length;
      final baseAngle = -math.pi / 2 + slot * typeIndex + slot * 0.18;
      final spread = slot * 0.64;
      final step = ofType.length == 1 ? 0.0 : spread / (ofType.length - 1);

      for (var i = 0; i < ofType.length; i++) {
        final angle = baseAngle - spread / 2 + step * i;
        nodes.add(
          _Node(
            ofType[i],
            center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
            angle,
          ),
        );
        index++;
      }
    }

    // --- Bağlantılar -----------------------------------------------------
    for (final node in nodes) {
      final color = typeColors[node.relation.type] ?? lineColor;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          (center.dx + node.center.dx) / 2 + math.cos(node.angle + 1.57) * 14,
          (center.dy + node.center.dy) / 2 + math.sin(node.angle + 1.57) * 14,
          node.center.dx,
          node.center.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Düğüm noktası
      canvas.drawCircle(
        node.center,
        3.2,
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }

    // --- Merkez halka ----------------------------------------------------
    final halo = centerColor.withValues(alpha: 0.06 + pulse * 0.05);
    canvas.drawCircle(center, 44 + pulse * 5, Paint()..color = halo);
    canvas.drawCircle(center, 40, Paint()..color = nodeFill);
    canvas.drawCircle(
      center,
      40,
      Paint()
        ..color = centerColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _text(
      canvas,
      word,
      center,
      AppType.display(16, color: nodeText),
      maxWidth: 66,
    );

    // --- Düğüm etiketleri ------------------------------------------------
    for (final node in nodes) {
      _text(
        canvas,
        node.relation.word,
        node.center,
        AppType.body(11.5, color: nodeText),
        maxWidth: 92,
        align: node.center.dx < center.dx - 8
            ? TextAlign.right
            : (node.center.dx > center.dx + 8 ? TextAlign.left : TextAlign.center),
        offsetX: node.center.dx < center.dx - 8 ? -8 : (node.center.dx > center.dx + 8 ? 8 : 0),
        offsetY: node.center.dy < center.dy - 8
            ? -12
            : (node.center.dy > center.dy + 8 ? 16 : 0),
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    required double maxWidth,
    TextAlign align = TextAlign.center,
    double offsetX = 0,
    double offsetY = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final dx = switch (align) {
      TextAlign.right => at.dx - tp.width,
      TextAlign.left => at.dx,
      _ => at.dx - tp.width / 2,
    };

    tp.paint(
      canvas,
      Offset(dx + offsetX, at.dy + offsetY - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.pulse != pulse || old.scale != scale || old.pan != pan;
}