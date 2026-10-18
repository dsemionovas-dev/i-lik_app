import 'package:flutter/material.dart';

/// Laikinas turinys ekranams, kurių UI dar kuriamas.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            ...children,
          ],
        ),
      ),
    );
  }
}
