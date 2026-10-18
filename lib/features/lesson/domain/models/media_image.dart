import '../../../../core/utils/json.dart';

/// Iliustracija iš CDN su alternatyviu tekstu (prieinamumui).
class MediaImage {
  const MediaImage({required this.url, required this.alt});

  final String url;
  final String alt;

  factory MediaImage.fromJson(Json json) => MediaImage(
        url: json['url'] as String,
        alt: json['alt'] as String? ?? '',
      );

  static MediaImage? maybeFromJson(Object? json) =>
      json == null ? null : MediaImage.fromJson(json as Json);

  Json toJson() => {'url': url, 'alt': alt};

  @override
  bool operator ==(Object other) =>
      other is MediaImage && other.url == url && other.alt == alt;

  @override
  int get hashCode => Object.hash(url, alt);
}
