/// Prisijungęs vartotojas. Svečias (`isAnonymous`) turi tikrą ID, todėl jo
/// progresas sinchronizuojamas ir išlieka susiejus paskyrą su el. paštu.
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.isAnonymous = false,
    this.pendingEmail,
    this.needsPassword = false,
  });

  final String id;
  final String? email;
  final bool isAnonymous;

  /// Susiejimui nurodytas, bet dar nepatvirtintas el. paštas.
  final String? pendingEmail;

  /// Paskyra su patvirtintu el. paštu, bet be slaptažodžio (susietas svečias) –
  /// kituose įrenginiuose prisijungti dar negalėtų.
  final bool needsPassword;

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.isAnonymous == isAnonymous &&
      other.pendingEmail == pendingEmail &&
      other.needsPassword == needsPassword;

  @override
  int get hashCode => Object.hash(id, email, isAnonymous, pendingEmail, needsPassword);

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
