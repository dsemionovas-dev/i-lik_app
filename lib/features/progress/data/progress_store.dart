import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/storage/json_file.dart';
import '../../../core/utils/json.dart';
import '../domain/models/lesson_attempt.dart';
import '../domain/models/user_progress.dart';

/// Vietinė progreso kopija: kas rodoma UI + dar neišsiųsti bandymai.
class ProgressSnapshot {
  ProgressSnapshot({
    this.ownerId,
    Map<String, UserProgress>? progress,
    List<LessonAttempt>? outbox,
    Set<String>? activityDays,
  }) : progress = progress ?? {},
       outbox = outbox ?? [],
       activityDays = activityDays ?? {};

  /// Kieno tai duomenys; pasikeitus vartotojui vietinė kopija nebetinka.
  String? ownerId;
  final Map<String, UserProgress> progress;
  final List<LessonAttempt> outbox;

  /// Vietinės kalendorinės dienos (`YYYY-MM-DD`), kai užbaigta bent viena pamoka – serijai.
  final Set<String> activityDays;

  factory ProgressSnapshot.fromJson(Json json) => ProgressSnapshot(
    ownerId: json['ownerId'] as String?,
    progress: {for (final p in parseList(json['progress'], UserProgress.fromLocalJson)) p.lessonId: p},
    outbox: parseList(json['outbox'], LessonAttempt.fromJson),
    activityDays: {...parseStringList(json['activityDays'])},
  );

  Json toJson() => {
    'ownerId': ownerId,
    'progress': progress.values.map((p) => p.toLocalJson()).toList(),
    'outbox': outbox.map((a) => a.toJson()).toList(),
    'activityDays': (activityDays.toList()..sort()),
  };
}

abstract interface class ProgressStore {
  Future<ProgressSnapshot?> read();
  Future<void> write(ProgressSnapshot snapshot);
}

/// `progress.json` programėlės palaikymo kataloge (atominis įrašymas).
class FileProgressStore implements ProgressStore {
  FileProgressStore({Future<File> Function()? file}) : _file = file ?? _defaultFile;

  final Future<File> Function() _file;

  static Future<File> _defaultFile() async => File('${(await getApplicationSupportDirectory()).path}/progress.json');

  @override
  Future<ProgressSnapshot?> read() async {
    final json = await readJsonFile(await _file());
    if (json == null) return null;
    try {
      return ProgressSnapshot.fromJson(json);
    } on Object {
      return null; // senos / sugadintos schemos failas
    }
  }

  @override
  Future<void> write(ProgressSnapshot snapshot) async => writeJsonFile(await _file(), snapshot.toJson());
}
