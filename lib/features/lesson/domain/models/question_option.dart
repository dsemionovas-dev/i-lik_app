import '../../../../core/utils/json.dart';
import 'media_image.dart';

/// Atsakymo variantas. Teisingumas laikomas atskirai (`correctOptionIds`),
/// todėl variantus galima laisvai maišyti.
class QuestionOption {
  const QuestionOption({required this.id, this.text, this.image, this.outcome})
      : assert(text != null || image != null,
            'Variantas turi turėti tekstą arba paveikslėlį');

  final String id;
  final String? text;
  final MediaImage? image;

  /// Tik `scenario` tipui – kas nutinka pasirinkus šį variantą.
  final String? outcome;

  factory QuestionOption.fromJson(Json json) => QuestionOption(
        id: json['id'] as String,
        text: json['text'] as String?,
        image: MediaImage.maybeFromJson(json['image']),
        outcome: json['outcome'] as String?,
      );

  Json toJson() => {
        'id': id,
        if (text != null) 'text': text,
        if (image != null) 'image': image!.toJson(),
        if (outcome != null) 'outcome': outcome,
      };
}

/// Paaiškinimas, rodomas po atsakymo.
class ItemFeedback {
  const ItemFeedback({this.correct, this.incorrect});

  final String? correct;
  final String? incorrect;

  static const empty = ItemFeedback();

  factory ItemFeedback.fromJson(Object? json) {
    if (json == null) return empty;
    final map = json as Json;
    return ItemFeedback(
      correct: map['correct'] as String?,
      incorrect: map['incorrect'] as String?,
    );
  }

  Json toJson() => {
        if (correct != null) 'correct': correct,
        if (incorrect != null) 'incorrect': incorrect,
      };
}
