import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';

/// Atmintinės be žaidimo mechanikos – turi veikti be interneto ir be prisijungimo.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  static const _cards = {
    'kuprine-72h': '72 val. kuprinė',
    'sirenu-signalai': 'Sirenų signalai',
    'priedangos': 'Priedangos',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gidas')),
      body: ListView(
        children: [
          for (final MapEntry(key: id, value: title) in _cards.entries)
            ListTile(
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.guideCard(id)),
            ),
        ],
      ),
    );
  }
}
