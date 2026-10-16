// ============================================================================
//  ORTAK BİLEŞENLER
// ============================================================================

library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Köken rozeti: "Öz Türkçe", "Arapça" … renkli etiket
class OriginBadge extends StatelessWidget {
  final String origin;
  final bool compact;

  const OriginBadge({super.key, required this.origin, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = originColor(origin);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Gap.sm : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: Radii.pill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        origin,
        style: AppType.body(compact ? 11 : 12, color: color, weight: FontWeight.w600),
      ),
    );
  }
}

/// Anlam katmanı etiketi: "TEMEL ANLAM", "MECAZ", "TERİM", "ARGO"
class SenseChip extends StatelessWidget {
  final String sense;
  final String wordType;

  const SenseChip({super.key, required this.sense, required this.wordType});

  @override
  Widget build(BuildContext context) {
    final color = senseColor(sense);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${senseLabel(sense)}  ·  ${wordType.toUpperCase()}',
            style: AppType.label(10, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Güven rozeti. AI üretimi ve henüz doğrulanmamış içeriklerde görünür.
class ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    if (confidence >= 0.95) return const SizedBox.shrink();

    final c = context.scheme;
    return Tooltip(
      message: 'Bu içerik henüz editör tarafından doğrulanmadı. '
          'Güven puanı: %${(confidence * 100).round()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.onSurface.withValues(alpha: 0.05),
          borderRadius: Radii.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 12, color: context.mutedText),
            const SizedBox(width: 4),
            Text(
              'DOĞRULANMADI',
              style: AppType.label(9, color: context.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bölüm başlığı: ince çizgi + küçük büyük harfli etiket
class SectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md, top: Gap.xs),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: AppType.label(10.5, color: context.mutedText)),
          const SizedBox(width: Gap.md),
          Expanded(child: Container(height: 1, color: context.subtleLine)),
          if (trailing != null) ...[
            const SizedBox(width: Gap.md),
            GestureDetector(
              onTap: onTap,
              child: Text(
                trailing!,
                style: AppType.body(11.5, color: context.scheme.primary, weight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hızlı erişim kartı — ana ekrandaki dört kutu
class QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final bool locked;
  final VoidCallback? onTap;

  const QuickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.subtitle,
    this.locked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.paperSurface,
      borderRadius: Radii.md,
      child: InkWell(
        onTap: locked ? null : onTap,
        borderRadius: Radii.md,
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            borderRadius: Radii.md,
            border: Border.all(color: context.subtleLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: Radii.sm,
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  if (locked)
                    Icon(Icons.lock_outline, size: 12, color: context.mutedText)
                  else
                    Icon(Icons.arrow_outward, size: 13, color: context.mutedText),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                label,
                style: AppType.body(
                  13,
                  weight: FontWeight.w600,
                  color: locked ? context.mutedText : context.scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppType.body(11, color: context.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kelime listesi satırı — arama sonuçları ve ilgili kelimelerde kullanılır
class WordRow extends StatelessWidget {
  final String word;
  final String definition;
  final String origin;
  final bool isPureTurkish;
  final VoidCallback onTap;

  const WordRow({
    super.key,
    required this.word,
    required this.definition,
    required this.origin,
    required this.isPureTurkish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word,
                            style: AppType.display(19, color: context.scheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPureTurkish) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.eco_outlined, size: 13, color: originColor('Öz Türkçe')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      definition,
                      style: AppType.body(13, color: context.mutedText, height: 1.45),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: OriginBadge(origin: origin, compact: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}