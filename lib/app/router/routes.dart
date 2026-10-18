/// Visi maršrutų keliai vienoje vietoje – jokių „magiškų“ eilučių ekranuose.
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const tree = '/tree';
  static const guide = '/guide';
  static const profile = '/profile';
  static const settings = '/profile/settings';
  static const league = '/profile/league';
  static const editProfile = '/profile/edit';

  static const resetPasswordPath = '/reset-password';
  static const newPassword = '$resetPasswordPath?step=new';

  static String guideCard(String cardId) => '$guide/$cardId';
  static String resetPassword({String? email}) =>
      Uri(path: resetPasswordPath, queryParameters: email == null || email.isEmpty ? null : {'email': email})
          .toString();

  /// Pasiekiama be onboardingo ir paskyros (PRD: gidas krizės metu; slaptažodžio atstatymas).
  static bool isPublic(String location) =>
      location == guide || location.startsWith('$guide/') || location == resetPasswordPath;
  static String lesson(String lessonId) => '/lesson/$lessonId';
  static String lessonResult(String lessonId) => '/lesson/$lessonId/result';
}
