import 'package:flutter/material.dart';

import '../../domain/models/lesson.dart';

/// Pamokos iliustracija iš CDN. Neprisijungus ar nepavykus įkelti rodoma
/// piktograma – prasmę tada perteikia šalia esantis tekstas.
class LessonImage extends StatelessWidget {
  const LessonImage({super.key, required this.image, this.fit = BoxFit.cover});

  final MediaImage? image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.image_outlined, size: 48, color: Theme.of(context).colorScheme.outline);
    final image = this.image;
    if (image == null) return Center(child: fallback);
    return Image.network(
      image.url,
      fit: fit,
      semanticLabel: image.alt,
      errorBuilder: (_, _, _) => Center(child: fallback),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
