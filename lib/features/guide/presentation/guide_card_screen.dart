import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_body.dart';

class GuideCardScreen extends StatelessWidget {
  const GuideCardScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atmintinė')),
      body: PlaceholderBody(title: 'Atmintinė: $cardId'),
    );
  }
}
