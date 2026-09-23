import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_board/src/app/core/utils/bounded_map.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_optimizer.dart';

class WorkoutStorageDataSource {
  WorkoutStorageDataSource(this._storage);
  final FirebaseStorage _storage;
  final _pending = <String, Future<String>>{};
  final _completed = <String, String>{};

  static bool needsUpload(String value) =>
      value.isNotEmpty &&
      !value.startsWith('https://') &&
      !value.startsWith('http://');

  Future<String> uploadImage(
    String userId,
    String workoutId,
    String source,
  ) async {
    if (!needsUpload(source)) return source;
    final original = WorkoutImageSource.decode(source);
    if (!WorkoutImageSource.supportedContentTypes.contains(
      original.contentType,
    )) {
      throw const FormatException('지원하지 않는 이미지 형식입니다.');
    }
    // Content-addressed immutable paths make retries and duplicate slides reuse
    // the same upload. Cache keys include owner and workout to prevent leakage.
    final key =
        'users/$userId/workouts/$workoutId/images/${sha256.convert(original.bytes)}';
    if (_completed.containsKey(key)) return _completed[key]!;
    final existing = _pending[key];
    if (existing != null) return existing;
    final upload = _upload(key, original);
    _pending[key] = upload;
    try {
      final url = await upload;
      if (_completed.length >= 128) _completed.remove(_completed.keys.first);
      _completed[key] = url;
      return url;
    } finally {
      _pending.remove(key);
    }
  }

  Future<String> _upload(String key, WorkoutImageSource original) async {
    final reference = _storage.ref(key);
    try {
      return await reference.getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
    final image = await optimizeWorkoutImage(original);
    if (image.bytes.length >= 10 * 1024 * 1024) {
      throw const FormatException('이미지는 10MB 미만으로 선택해 주세요.');
    }
    await reference.putData(
      image.bytes,
      SettableMetadata(contentType: image.contentType),
    );
    return reference.getDownloadURL();
  }

  Future<Workout> syncImages(
    String userId,
    Workout workout, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final sources = [
      ...workout.modules.map((module) => module.imageSource),
      workout.countdownImageSource,
    ].where(needsUpload).toSet().toList();
    var completed = 0;
    onProgress?.call(0, sources.length);
    final uploaded = await boundedMap(sources, (source) async {
      final url = await uploadImage(userId, workout.id, source);
      onProgress?.call(++completed, sources.length);
      return url;
    });
    final urls = Map.fromIterables(sources, uploaded);
    // Shared assets survive deletion until reference-aware garbage collection.
    return workout.copyWith(
      modules: workout.modules
          .map(
            (m) =>
                m.copyWith(imageSource: urls[m.imageSource] ?? m.imageSource),
          )
          .toList(),
      countdownImageSource:
          urls[workout.countdownImageSource] ?? workout.countdownImageSource,
    );
  }
}
