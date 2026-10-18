import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';
import 'answer_colors.dart';
import 'lesson_image.dart';

/// `hotspot`: vartotojas paspaudžia paveikslėlyje. Valdiklis praneša santykines
/// koordinates (0–1); kol netikrinta, paspausti galima iš naujo. Po „TIKRINTI“
/// ([locked]) parodomos teisingos sritys ir paspaustas taškas.
class HotspotView extends StatelessWidget {
  const HotspotView({
    super.key,
    required this.item,
    required this.tap,
    required this.locked,
    required this.onTap,
  });

  final HotspotItem item;

  /// Paspausta vieta santykinėmis koordinatėmis; `null` – dar nepaspausta.
  final Offset? tap;
  final bool locked;
  final ValueChanged<Offset> onTap;

  static const markerSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tap = this.tap;
    final hit = tap != null && item.isCorrect(tap.dx, tap.dy);
    final markerColor = !locked ? theme.colorScheme.primary : (hit ? theme.correctColor : theme.incorrectColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(item.prompt, style: theme.textTheme.titleLarge),
        Text(
          locked
              ? 'Žalia sritis – teisinga vieta.'
              : (tap == null ? 'Paspausk paveikslėlyje.' : 'Gali paspausti kitoje vietoje, kad pakeistum.'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: item.aspectRatio,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                return Semantics(
                  label: item.image.alt,
                  hint: locked ? null : 'Paspausk paveikslėlyje, kad pažymėtum atsakymą',
                  image: true,
                  child: GestureDetector(
                    key: const ValueKey('hotspot-canvas'),
                    behavior: HitTestBehavior.opaque,
                    onTapUp: locked
                        ? null
                        : (d) => onTap(Offset(
                              (d.localPosition.dx / size.width).clamp(0, 1),
                              (d.localPosition.dy / size.height).clamp(0, 1),
                            )),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: theme.colorScheme.surfaceContainerHigh,
                            // fill – rėmas jau turi paveikslėlio proporcijas.
                            child: LessonImage(image: item.image, fit: BoxFit.fill),
                          ),
                        ),
                        if (locked)
                          for (final (i, area) in item.targetAreas.indexed)
                            Positioned(
                              key: ValueKey('hotspot-area-$i'),
                              left: (area.x - area.r) * size.width,
                              top: area.y * size.height - area.r * size.width,
                              width: 2 * area.r * size.width,
                              height: 2 * area.r * size.width,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.correctColor.withValues(alpha: 0.25),
                                  border: Border.all(color: theme.correctColor, width: 3),
                                ),
                              ),
                            ),
                        if (tap != null)
                          Positioned(
                            key: const ValueKey('hotspot-marker'),
                            left: tap.dx * size.width - markerSize / 2,
                            top: tap.dy * size.height - markerSize / 2,
                            width: markerSize,
                            height: markerSize,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: markerColor,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                              ),
                              child: locked
                                  ? Icon(hit ? Icons.check : Icons.close, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
