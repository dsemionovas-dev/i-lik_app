import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_body.dart';

/// TODO: priminimai, garsas, vibracija, atsisiųstas turinys, paskyra, privatumas.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nustatymai')),
      body: const PlaceholderBody(title: 'Nustatymai'),
    );
  }
}
