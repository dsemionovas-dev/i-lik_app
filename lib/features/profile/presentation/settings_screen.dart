import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/config/env.dart';

/// TODO: priminimai, garsas, vibracija, atsisiųstas turinys, privatumas.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nustatymai')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Pranešti apie klaidą'),
            subtitle: const Text('Klaida turinyje, pavojingas patarimas ar programėlės klaida'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.report()),
          ),
          const Divider(),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('Versija'), subtitle: Text(Env.appVersion)),
        ],
      ),
    );
  }
}
