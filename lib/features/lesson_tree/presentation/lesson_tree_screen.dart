import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';

/// TODO: vingiuotas kelias su mazgų būsenomis (užrakinta / aktyvi / baigta / auksinė).
class LessonTreeScreen extends StatelessWidget {
  const LessonTreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelias · Navigacija')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Kompaso azimutas'),
            subtitle: const Text('5 min · 10 XP'),
            onTap: () => context.push(Routes.lesson('nav-u02-l03')),
          ),
        ],
      ),
    );
  }
}
