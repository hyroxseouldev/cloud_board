// Deliberately baseline-compatible: runs on develop 7f8e2b3 and STA-122.
// The renderer/PNG/Base64 path is real; only remote Storage I/O is replaced.
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

class _ProfileFirebase implements FirebaseStorage {
  @override
  String get bucket => 'sta122-profile.appspot.com';
  final objects = <String>{};
  @override
  Reference refFromURL(String url) => _ProfileReference(
    this,
    Uri.decodeComponent(Uri.parse(url).path.split('/o/').last),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileReference implements Reference {
  _ProfileReference(this.storage, this.fullPath);
  @override
  final _ProfileFirebase storage;
  @override
  final String fullPath;
  @override
  String get bucket => storage.bucket;
  @override
  String get name => fullPath.split('/').last;
  @override
  Future<String> getDownloadURL() async {
    if (!storage.objects.contains(fullPath)) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
      );
    }
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(fullPath)}?alt=media';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileStorage extends WorkoutStorageDataSource {
  _ProfileStorage(this.firebase) : super(firebase);
  final _ProfileFirebase firebase;
  final preparationWatch = Stopwatch();
  int? firstUploadMicros;
  void beginSave() {
    preparationWatch.reset();
    preparationWatch.start();
    firstUploadMicros = null;
  }

  int preparedImages = 0;
  int newObjects = 0;
  @override
  Future<String> uploadImage(
    String userId,
    String workoutId,
    String source,
  ) async {
    firstUploadMicros ??= preparationWatch.elapsedMicroseconds;
    preparedImages++;
    final bytes = base64Decode(source.split(',').last);
    final key =
        'users/$userId/workouts/$workoutId/images/${sha256.convert(bytes)}';
    if (firebase.objects.add(key)) newObjects++;
    return _ProfileReference(firebase, key).getDownloadURL();
  }
}

Future<Map<String, Object>> profileDesignSaves() async {
  final firebase = _ProfileFirebase();
  final storage = _ProfileStorage(firebase);
  final workout =
      Workout.empty(
        'sta122-profile',
        const WorkoutAuthor(
          id: 'sta122',
          displayName: 'Profile',
          photoUrl: null,
        ),
      ).copyWith(
        modules: List.generate(
          30,
          (i) => WorkoutModule.empty('slide-$i').copyWith(
            name: 'STATION ${i + 1}',
            text: 'Run ${(i + 1) * 100}m\nSquat ${i + 8} reps',
            designTemplate: 'stationd-v2-list',
            showTimer: false,
            showSets: false,
          ),
        ),
      );
  storage.beginSave();
  final timer = Stopwatch()..start();
  final saved = await storage.syncImages('sta122', workout);
  final firstMicros = timer.elapsedMicroseconds;
  final firstPrepareMicros = storage.firstUploadMicros ?? 0;
  storage.preparedImages = 0;
  storage.newObjects = 0;
  timer.reset();
  storage.beginSave();
  await storage.syncImages('sta122', saved.copyWith(folder: 'Moved folder'));
  final repeatedMicros = timer.elapsedMicroseconds;
  timer.stop();
  return {
    'slideCount': 30,
    'firstSaveMicros': firstMicros,
    'unchangedSaveMicros': repeatedMicros,
    'firstPngPreparationMicros': firstPrepareMicros,
    'unchangedPngPreparationMicros': storage.firstUploadMicros ?? 0,
    'unchangedPreparedImages': storage.preparedImages,
    'unchangedNewObjects': storage.newObjects,
    'storage':
        'in-memory immutable objects; real production rendering and encoding',
  };
}
