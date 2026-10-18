import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../shared/widgets/placeholder_body.dart';

/// TODO: serija, širdelės, dienos tikslas, „Tęsti“ kortelė, dienos iššūkis.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pradžia')),
      body: PlaceholderBody(
        title: 'Kita pamoka: Kompaso azimutas',
        children: [
          FilledButton(
            onPressed: () => context.push(Routes.lesson('nav-u02-l03')),
            child: const Text('PRADĖTI'),
          ),
        ],
      ),
    );
  }
}
