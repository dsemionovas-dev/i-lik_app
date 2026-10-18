import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Konfigūracija, kurią lengva netyčia sugadinti ir kuri pastebima tik
/// testuotojų telefonuose – tikrinama kiekviename CI paleidime.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('Android', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final gradle = read('android/app/build.gradle.kts');

    test('INTERNET leidimas pagrindiniame manifeste (be jo release nepasiekia Supabase)', () {
      expect(manifest, contains('android.permission.INTERNET'));
    });

    test('pavadinimas, paketo ID, laiškų nuorodos, tel/https užklausos', () {
      expect(manifest, contains('android:label="Išlik"'));
      expect(gradle, contains('applicationId = "lt.islik.app"'));
      expect(manifest, contains('android:scheme="lt.islik"'));
      expect(manifest, contains('android:scheme="tel"'));
      expect(manifest, contains('android:scheme="https"'));
    });

    test('release pasirašomas iš key.properties, kuris ne git\'e', () {
      expect(gradle, contains('key.properties'));
      expect(read('.gitignore'), contains('android/key.properties'));
      expect(read('.gitignore'), contains('*.jks'));
    });

    test('adaptyvi piktograma ir užsklanda sugeneruotos', () {
      expect(File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(), isTrue);
      expect(File('android/app/src/main/res/drawable-xxxhdpi/splash.png').existsSync(), isTrue);
    });
  });

  group('iOS', () {
    final plist = read('ios/Runner/Info.plist');

    test('pavadinimas, paketo ID, laiškų nuorodos, tel užklausos', () {
      expect(plist, contains('<string>Išlik</string>'));
      expect(plist, contains('<string>lt.islik</string>'));
      expect(plist, contains('<string>tel</string>'));
      expect(read('ios/Runner.xcodeproj/project.pbxproj'), contains('PRODUCT_BUNDLE_IDENTIFIER = lt.islik.app;'));
    });

    test('App Store piktograma be skaidrumo (1024 px)', () {
      final icon = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
      expect(icon.existsSync(), isTrue);
      // PNG IHDR: spalvos tipas 2 = RGB (be alfa kanalo).
      expect(icon.readAsBytesSync()[25], 2);
    });
  });

  group('CI', () {
    test('Flutter versija CI ir beta build\'e sutampa', () {
      final version = RegExp(r"flutter-version: '([\d.]+)'").firstMatch(read('.github/workflows/ci.yml'))!.group(1);
      expect(read('.github/workflows/beta.yml'), contains("FLUTTER_VERSION: '$version'"));
    });

    test('beta build\'as gauna Supabase raktus ir versiją per --dart-define', () {
      final beta = read('.github/workflows/beta.yml');
      for (final define in ['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY', 'APP_VERSION']) {
        expect(beta, contains('--dart-define=$define='), reason: define);
      }
    });
  });
}
