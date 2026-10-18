import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/utils/json.dart';

/// Avatarai – Lietuvos miško gyvūnai (be nuotraukų: nereikia moderuoti, saugu vaikams).
const avatars = <String, ({String emoji, String label})>{
  'fox': (emoji: '🦊', label: 'Lapė'),
  'bear': (emoji: '🐻', label: 'Lokys'),
  'wolf': (emoji: '🐺', label: 'Vilkas'),
  'owl': (emoji: '🦉', label: 'Pelėda'),
  'deer': (emoji: '🦌', label: 'Elnias'),
  'hedgehog': (emoji: '🦔', label: 'Ežys'),
  'boar': (emoji: '🐗', label: 'Šernas'),
  'eagle': (emoji: '🦅', label: 'Erelis'),
  'beaver': (emoji: '🦫', label: 'Bebras'),
  'stork': (emoji: '🐦', label: 'Gandras'),
};

const defaultAvatar = 'fox';

class Profile {
  const Profile({this.displayName, this.avatar});

  /// `null` – vartotojas vardo nepasirinko (rodomas [defaultDisplayName]).
  final String? displayName;
  final String? avatar;

  String nameFor(String userId) => displayName ?? defaultDisplayName(userId);
  String get avatarEmoji => (avatars[avatar] ?? avatars[defaultAvatar]!).emoji;

  factory Profile.fromJson(Json json) =>
      Profile(displayName: json['display_name'] as String?, avatar: json['avatar'] as String?);

  Json toJson() => {'display_name': displayName, 'avatar': avatar};

  @override
  bool operator ==(Object other) => other is Profile && other.displayName == displayName && other.avatar == avatar;

  @override
  int get hashCode => Object.hash(displayName, avatar);
}

/// Toks pat kaip serverio lygose: „Žygeivis “ + md5(user_id) pirmi 5 simboliai.
String defaultDisplayName(String userId) =>
    'Žygeivis ${md5.convert(utf8.encode(userId)).toString().substring(0, 5).toUpperCase()}';

/// Ta pati taisyklė kaip SQL `profiles_display_name_check`. `null` – tinka.
String? validateDisplayName(String raw) {
  final name = raw.trim();
  if (name.length < 3) return 'Vardas per trumpas – bent 3 simboliai.';
  if (name.length > 24) return 'Vardas per ilgas – daugiausia 24 simboliai.';
  if (!RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} _.'-]*$", unicode: true).hasMatch(name)) {
    return 'Naudokite raides, skaičius, tarpus ir ženklus . _ - \'';
  }
  if (name.contains(RegExp(r'\s{2,}'))) return 'Vardas negali turėti kelių tarpų iš eilės.';
  return null;
}
