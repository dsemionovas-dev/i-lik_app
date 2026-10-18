/// Konfigūracija per `--dart-define` (raktai nelaikomi repozitorijoje):
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Be raktų programėlė veikia su vietinėmis pamokomis iš `assets/`.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Gilioji nuoroda, į kurią grąžina Supabase laiškų nuorodos (turi būti
  /// Supabase → Authentication → URL Configuration → Redirect URLs sąraše).
  static const authRedirectUrl = 'lt.islik://auth-callback';
}
