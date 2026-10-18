import 'dart:math' as math;

import '../../../../core/utils/json.dart';
import 'media_image.dart';
import 'question_option.dart';

/// Viena pamokos užduotis. Konkretus potipis parenkamas pagal JSON lauką `type`,
/// todėl UI gali naudoti išsamų `switch` per visus tipus.
sealed class LessonItem {
  const LessonItem({required this.id, this.xp = 0});

  final String id;

  /// XP už teisingą atsakymą į šią užduotį.
  final int xp;

  /// Ar užduotis vertinama (teorijos kortelė – ne).
  bool get isGraded => true;

  String get type;

  factory LessonItem.fromJson(Json json) {
    final type = json['type'] as String;
    return switch (type) {
      InfoCardItem.typeKey => InfoCardItem.fromJson(json),
      TrueFalseItem.typeKey => TrueFalseItem.fromJson(json),
      OrderStepsItem.typeKey => OrderStepsItem.fromJson(json),
      MatchPairsItem.typeKey => MatchPairsItem.fromJson(json),
      HotspotItem.typeKey => HotspotItem.fromJson(json),
      _ when ChoiceType.fromKey(type) != null => ChoiceItem.fromJson(json),
      // Naujesnės turinio versijos tipas – senesnė programėlė jį praleidžia, o ne lūžta.
      _ => UnsupportedItem(id: json['id'] as String, type: type, raw: json),
    };
  }

  Json toJson();

  Json _baseJson() => {'id': id, 'type': type, if (xp != 0) 'xp': xp};
}

/// Teorijos kortelė be vertinimo („Supratau“).
class InfoCardItem extends LessonItem {
  const InfoCardItem({required super.id, required this.title, required this.body, this.image});

  static const typeKey = 'info_card';

  final String title;
  final String body;
  final MediaImage? image;

  @override
  String get type => typeKey;

  @override
  bool get isGraded => false;

  factory InfoCardItem.fromJson(Json json) => InfoCardItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    image: MediaImage.maybeFromJson(json['image']),
  );

  @override
  Json toJson() => {..._baseJson(), 'title': title, 'body': body, 'image': image?.toJson()};
}

enum ChoiceType {
  single('single_choice'),
  multi('multi_choice'),
  image('image_choice'),
  scenario('scenario');

  const ChoiceType(this.key);
  final String key;

  static ChoiceType? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// Visi pasirinkimo tipai: vienas / keli atsakymai, paveikslėliai, situacijos scenarijus.
class ChoiceItem extends LessonItem {
  const ChoiceItem({
    required super.id,
    required this.choiceType,
    required this.prompt,
    required this.options,
    required this.correctOptionIds,
    super.xp,
    this.image,
    this.shuffleOptions = true,
    this.feedback = ItemFeedback.empty,
  });

  final ChoiceType choiceType;
  final String prompt;
  final MediaImage? image;
  final List<QuestionOption> options;
  final List<String> correctOptionIds;
  final bool shuffleOptions;
  final ItemFeedback feedback;

  @override
  String get type => choiceType.key;

  bool get allowsMultiple => choiceType == ChoiceType.multi;

  /// Teisinga tik tada, kai pasirinkta lygiai teisingų variantų aibė.
  bool isCorrect(Set<String> selectedIds) =>
      selectedIds.length == correctOptionIds.length && selectedIds.containsAll(correctOptionIds);

  factory ChoiceItem.fromJson(Json json) => ChoiceItem(
    id: json['id'] as String,
    choiceType: ChoiceType.fromKey(json['type'] as String)!,
    prompt: json['prompt'] as String,
    image: MediaImage.maybeFromJson(json['image']),
    options: parseList(json['options'], QuestionOption.fromJson),
    correctOptionIds: parseStringList(json['correctOptionIds']),
    shuffleOptions: json['shuffleOptions'] as bool? ?? true,
    feedback: ItemFeedback.fromJson(json['feedback']),
    xp: json['xp'] as int? ?? 0,
  );

  @override
  Json toJson() => {
    ..._baseJson(),
    'prompt': prompt,
    'image': image?.toJson(),
    'options': options.map((o) => o.toJson()).toList(),
    'correctOptionIds': correctOptionIds,
    'shuffleOptions': shuffleOptions,
    'feedback': feedback.toJson(),
  };
}

class TrueFalseItem extends LessonItem {
  const TrueFalseItem({
    required super.id,
    required this.prompt,
    required this.correctAnswer,
    super.xp,
    this.image,
    this.feedback = ItemFeedback.empty,
  });

  static const typeKey = 'true_false';

  final String prompt;
  final bool correctAnswer;
  final MediaImage? image;
  final ItemFeedback feedback;

  @override
  String get type => typeKey;

  bool isCorrect(bool answer) => answer == correctAnswer;

  factory TrueFalseItem.fromJson(Json json) => TrueFalseItem(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    correctAnswer: json['correctAnswer'] as bool,
    image: MediaImage.maybeFromJson(json['image']),
    feedback: ItemFeedback.fromJson(json['feedback']),
    xp: json['xp'] as int? ?? 0,
  );

  @override
  Json toJson() => {
    ..._baseJson(),
    'prompt': prompt,
    'correctAnswer': correctAnswer,
    'image': image?.toJson(),
    'feedback': feedback.toJson(),
  };
}

class OrderStep {
  const OrderStep({required this.id, required this.text});

  final String id;
  final String text;

  factory OrderStep.fromJson(Json json) => OrderStep(id: json['id'] as String, text: json['text'] as String);

  Json toJson() => {'id': id, 'text': text};
}

/// „Sudėliok tvarką“ – pvz., ugnies kūrimo žingsniai.
class OrderStepsItem extends LessonItem {
  const OrderStepsItem({
    required super.id,
    required this.prompt,
    required this.steps,
    required this.correctOrder,
    super.xp,
    this.feedback = ItemFeedback.empty,
  });

  static const typeKey = 'order_steps';

  final String prompt;
  final List<OrderStep> steps;
  final List<String> correctOrder;
  final ItemFeedback feedback;

  @override
  String get type => typeKey;

  bool isCorrect(List<String> orderedIds) {
    if (orderedIds.length != correctOrder.length) return false;
    for (var i = 0; i < orderedIds.length; i++) {
      if (orderedIds[i] != correctOrder[i]) return false;
    }
    return true;
  }

  factory OrderStepsItem.fromJson(Json json) => OrderStepsItem(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    steps: parseList(json['steps'], OrderStep.fromJson),
    correctOrder: parseStringList(json['correctOrder']),
    feedback: ItemFeedback.fromJson(json['feedback']),
    xp: json['xp'] as int? ?? 0,
  );

  @override
  Json toJson() => {
    ..._baseJson(),
    'prompt': prompt,
    'steps': steps.map((s) => s.toJson()).toList(),
    'correctOrder': correctOrder,
    'feedback': feedback.toJson(),
  };
}

class MatchPair {
  const MatchPair({required this.left, required this.right});

  final String left;
  final String right;

  factory MatchPair.fromJson(Json json) => MatchPair(left: json['left'] as String, right: json['right'] as String);

  Json toJson() => {'left': left, 'right': right};
}

/// „Sujunk poras“ – pvz., įrankis ↔ paskirtis.
class MatchPairsItem extends LessonItem {
  const MatchPairsItem({
    required super.id,
    required this.prompt,
    required this.pairs,
    super.xp,
    this.feedback = ItemFeedback.empty,
  });

  static const typeKey = 'match_pairs';

  final String prompt;
  final List<MatchPair> pairs;
  final ItemFeedback feedback;

  @override
  String get type => typeKey;

  /// [matches] – kairė pusė → vartotojo pasirinkta dešinė pusė.
  bool isCorrect(Map<String, String> matches) =>
      matches.length == pairs.length && pairs.every((p) => matches[p.left] == p.right);

  factory MatchPairsItem.fromJson(Json json) => MatchPairsItem(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    pairs: parseList(json['pairs'], MatchPair.fromJson),
    feedback: ItemFeedback.fromJson(json['feedback']),
    xp: json['xp'] as int? ?? 0,
  );

  @override
  Json toJson() => {
    ..._baseJson(),
    'prompt': prompt,
    'pairs': pairs.map((p) => p.toJson()).toList(),
    'feedback': feedback.toJson(),
  };
}

/// Apskrita zona paveikslėlyje. `x` – pločio dalis, `y` – aukščio dalis (0–1),
/// `r` – spindulys pločio dalimis, todėl ekrane tai visada tikras apskritimas.
class HotspotArea {
  const HotspotArea({required this.x, required this.y, required this.r});

  final double x;
  final double y;
  final double r;

  /// [aspectRatio] – paveikslėlio plotis / aukštis.
  bool contains(double px, double py, {double aspectRatio = 1}) {
    // Aukščio dalis → pločio dalys: 1 aukščio = 1 / aspectRatio pločio.
    final dx = px - x, dy = (py - y) / aspectRatio;
    return math.sqrt(dx * dx + dy * dy) <= r;
  }

  factory HotspotArea.fromJson(Json json) =>
      HotspotArea(x: (json['x'] as num).toDouble(), y: (json['y'] as num).toDouble(), r: (json['r'] as num).toDouble());

  Json toJson() => {'x': x, 'y': y, 'r': r};
}

/// „Pažymėk paveikslėlyje“ – pvz., šiaurė žemėlapyje.
class HotspotItem extends LessonItem {
  const HotspotItem({
    required super.id,
    required this.prompt,
    required this.image,
    required this.targetAreas,
    super.xp,
    this.aspectRatio = 1,
    this.feedback = ItemFeedback.empty,
  }) : assert(aspectRatio > 0);

  static const typeKey = 'hotspot';

  final String prompt;
  final MediaImage image;
  final List<HotspotArea> targetAreas;

  /// Paveikslėlio plotis / aukštis. Turi atitikti tikrą failą: paveikslėlis
  /// ištempiamas į šį rėmą, kad santykinės koordinatės sutaptų su pikseliais.
  final double aspectRatio;
  final ItemFeedback feedback;

  @override
  String get type => typeKey;

  bool isCorrect(double x, double y) => targetAreas.any((a) => a.contains(x, y, aspectRatio: aspectRatio));

  factory HotspotItem.fromJson(Json json) => HotspotItem(
    id: json['id'] as String,
    prompt: json['prompt'] as String,
    image: MediaImage.fromJson(json['image'] as Json),
    targetAreas: parseList(json['targetAreas'], HotspotArea.fromJson),
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1,
    feedback: ItemFeedback.fromJson(json['feedback']),
    xp: json['xp'] as int? ?? 0,
  );

  @override
  Json toJson() => {
    ..._baseJson(),
    'prompt': prompt,
    'image': image.toJson(),
    'targetAreas': targetAreas.map((a) => a.toJson()).toList(),
    'aspectRatio': aspectRatio,
    'feedback': feedback.toJson(),
  };
}

/// Šios programėlės versijai nežinomas tipas. Laikomas kaip yra, kad
/// `toJson` grąžintų originalą, o pamokos ekranas jį praleistų.
class UnsupportedItem extends LessonItem {
  const UnsupportedItem({required super.id, required this.type, required this.raw});

  @override
  final String type;
  final Json raw;

  @override
  bool get isGraded => false;

  @override
  Json toJson() => raw;
}
