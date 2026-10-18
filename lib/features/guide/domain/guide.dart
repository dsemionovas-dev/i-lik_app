import '../../../core/utils/json.dart';

enum GuideBlockKind {
  text,

  /// Numeruoti žingsniai.
  steps,
  bullets,

  /// Pažymimas sąrašas (pvz., 72 val. kuprinė) – žymės saugomos įrenginyje.
  checklist,
  warning;

  static GuideBlockKind fromKey(String key) =>
      values.firstWhere((k) => k.name == key, orElse: () => GuideBlockKind.text);
}

class GuideBlock {
  const GuideBlock({required this.kind, this.heading, this.text, this.items = const []});

  final GuideBlockKind kind;
  final String? heading;
  final String? text;
  final List<String> items;

  factory GuideBlock.fromJson(Json json) => GuideBlock(
        kind: GuideBlockKind.fromKey(json['kind'] as String),
        heading: json['heading'] as String?,
        text: json['text'] as String?,
        items: parseStringList(json['items']),
      );
}

class GuideSource {
  const GuideSource({required this.title, this.url});

  final String title;
  final String? url;

  factory GuideSource.fromJson(Json json) =>
      GuideSource(title: json['title'] as String, url: json['url'] as String?);
}

class GuideCategory {
  const GuideCategory({required this.id, required this.title, this.icon});

  final String id;
  final String title;
  final String? icon;

  factory GuideCategory.fromJson(Json json) =>
      GuideCategory(id: json['id'] as String, title: json['title'] as String, icon: json['icon'] as String?);
}

class GuideCard {
  const GuideCard({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.blocks,
    this.keywords = const [],
    this.emergencyCall = false,
    this.sources = const [],
  });

  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final List<GuideBlock> blocks;
  final List<String> keywords;

  /// Rodyti mygtuką „Skambinti 112“.
  final bool emergencyCall;
  final List<GuideSource> sources;

  factory GuideCard.fromJson(Json json) => GuideCard(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        blocks: parseList(json['blocks'], GuideBlock.fromJson),
        keywords: parseStringList(json['keywords']),
        emergencyCall: json['emergencyCall'] as bool? ?? false,
        sources: parseList(json['sources'], GuideSource.fromJson),
      );

  /// Visi žodžiai turi būti kortelėje (be diakritikų ir didžiųjų raidžių).
  bool matches(String query) {
    final words = foldForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return true;
    final haystack = foldForSearch(
      [title, summary, ...keywords, for (final b in blocks) ...[?b.heading, ?b.text, ...b.items]].join(' '),
    );
    return words.every(haystack.contains);
  }
}

/// Visas gidas – vienas JSON paketas (įdiegtas `assets/guide/guide.json`,
/// atnaujinimai iš Supabase `guide_books`).
class GuideBook {
  const GuideBook({required this.version, required this.categories, required this.cards, this.locale = 'lt-LT'});

  final int version;
  final String locale;
  final List<GuideCategory> categories;
  final List<GuideCard> cards;

  GuideCard? card(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<GuideCard> search({String query = '', String? categoryId}) => [
        for (final c in cards)
          if ((categoryId == null || c.categoryId == categoryId) && c.matches(query)) c,
      ];

  /// Meta klaidą, jei paketas netinkamas – toks į kešą nepatenka.
  factory GuideBook.fromJson(Json json) {
    final book = GuideBook(
      version: json['version'] as int,
      locale: json['locale'] as String? ?? 'lt-LT',
      categories: parseList(json['categories'], GuideCategory.fromJson),
      cards: parseList(json['cards'], GuideCard.fromJson),
    );
    final categoryIds = {for (final c in book.categories) c.id};
    for (final card in book.cards) {
      if (!categoryIds.contains(card.categoryId)) {
        throw FormatException('Kortelės ${card.id} kategorija ${card.categoryId} nežinoma');
      }
    }
    if (book.cards.isEmpty) throw const FormatException('Gidas be kortelių');
    return book;
  }
}

const _fold = {
  'ą': 'a', 'č': 'c', 'ę': 'e', 'ė': 'e', 'į': 'i', 'š': 's', 'ų': 'u', 'ū': 'u', 'ž': 'z',
};

/// „Ąžuolas“ → „azuolas“: krizės metu rašoma ir be lietuviškos klaviatūros.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    buffer.write(_fold[ch] ?? ch);
  }
  return buffer.toString();
}
