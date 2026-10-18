/// Prisijungęs vartotojas. Svečias (`isAnonymous`) turi tikrą ID, todėl jo
/// progresas sinchronizuojamas ir išlieka susiejus paskyrą su el. paštu.
class AppUser {
  const AppUser({required this.id, this.email, this.isAnonymous = false});

  final String id;
  final String? email;
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.email == email && other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(id, email, isAnonymous);

  @override
  String toString() => 'AppUser($id, ${isAnonymous ? 'svečias' : email})';
}

/// Autentifikacijos klaida su vartotojui rodomu tekstu.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
