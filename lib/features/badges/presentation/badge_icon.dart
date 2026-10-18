import 'package:flutter/material.dart';

IconData badgeIcon(String key) => switch (key) {
  'flag' => Icons.flag,
  'explore' => Icons.explore,
  'hiking' => Icons.hiking,
  'star' => Icons.star,
  'fire' => Icons.local_fire_department,
  'bolt' => Icons.bolt,
  'compass' => Icons.navigation,
  'fire_master' => Icons.whatshot,
  _ => Icons.military_tech,
};

/// Apvalus ženklelis: gautas – spalvotas, negautas – pilkas.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({super.key, required this.icon, required this.earned, this.size = 56});

  final String icon;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? scheme.tertiaryContainer : scheme.surfaceContainerHighest,
        border: Border.all(color: earned ? scheme.tertiary : scheme.outlineVariant, width: 2),
      ),
      child: Icon(badgeIcon(icon), size: size * 0.5, color: earned ? scheme.onTertiaryContainer : scheme.outline),
    );
  }
}
