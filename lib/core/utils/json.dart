typedef Json = Map<String, dynamic>;

/// Saugiai paverčia JSON masyvą į objektų sąrašą; trūkstamas laukas = tuščias sąrašas.
List<T> parseList<T>(Object? raw, T Function(Json json) fromJson) {
  if (raw == null) return List<T>.empty();
  return (raw as List<dynamic>)
      .map((e) => fromJson(e as Json))
      .toList(growable: false);
}

List<String> parseStringList(Object? raw) {
  if (raw == null) return const [];
  return (raw as List<dynamic>).cast<String>().toList(growable: false);
}

DateTime? parseDate(Object? raw) =>
    raw == null ? null : DateTime.parse(raw as String);
