/// Visi maršrutų keliai vienoje vietoje – jokių „magiškų“ eilučių ekranuose.
abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const tree = '/tree';
  static const guide = '/guide';
  static const profile = '/profile';
  static const settings = '/profile/settings';

  static String guideCard(String cardId) => '$guide/$cardId';
  static String lesson(String lessonId) => '/lesson/$lessonId';
  static String lessonResult(String lessonId) => '/lesson/$lessonId/result';
}
