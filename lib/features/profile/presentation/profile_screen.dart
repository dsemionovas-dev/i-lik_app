import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../shared/widgets/placeholder_body.dart';

/// TODO: statistika, XP grafikas, kursų progresas, ženkleliai, lyga.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilis'),
        actions: [
          IconButton(
            tooltip: 'Nustatymai',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: const PlaceholderBody(title: 'Statistika ir ženkleliai'),
    );
  }
}
