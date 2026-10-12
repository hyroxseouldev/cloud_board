import 'package:crypto/crypto.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_board/src/app/core/utils/bounded_map.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_optimizer.dart';

class WorkoutStorageDataSource {
  WorkoutStorageDataSource(
    this._storage, {
    this.prepareDesign = prepareSlideDesign,
  });
  final Future<WorkoutModule> Function(WorkoutModule) prepareDesign;
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

  /// A persisted fingerprint is only a hint. Verify that its immutable asset
  /// still exists inside the current account/workout and configured bucket.
  /// Authorization/network failures must abort saving instead of being hidden.
  Future<String?> reusableDesignImage(
    String userId,
    String workoutId,
    WorkoutModule module,
  ) async {
    final visual = slideDesignFingerprint(module);
    if (!(module.designFingerprint?.startsWith('$visual:') ?? false) ||
        !module.imageSource.startsWith('https://')) {
      return null;
    }
    final uri = Uri.tryParse(module.imageSource);
    if (uri == null ||
        uri.host != 'firebasestorage.googleapis.com' ||
        uri.pathSegments.length != 5 ||
        uri.pathSegments[0] != 'v0' ||
        uri.pathSegments[1] != 'b' ||
        uri.pathSegments[3] != 'o') {
      return null;
    }
    Reference reference;
    try {
      reference = _storage.refFromURL(module.imageSource);
    } on ArgumentError {
      return null;
    } on AssertionError {
      return null;
    }
    final prefix = 'users/$userId/workouts/$workoutId/images/';
    if (module.designFingerprint != '$visual:${reference.name}' ||
        reference.bucket != _storage.bucket ||
        !reference.fullPath.startsWith(prefix) ||
        !RegExp(r'^[a-f0-9]{64}$')
            .hasMatch(reference.fullPath.substring(prefix.length))) {
      return null;
    }
    try {
      return await reference.getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        _completed.removeWhere((_, url) => url == module.imageSource);
        return null;
      }
      rethrow;
    }
  }

  Future<Workout> syncImages(
    String userId,
    Workout workout, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final reusable = await boundedMap(
      workout.modules,
      (module) async => hasSlideDesign(module)
          ? await reusableDesignImage(userId, workout.id, module)
          : null,
    );
    final designed = <WorkoutModule>[];
    for (final (index, module) in workout.modules.indexed) {
      if (reusable[index] != null) {
        designed.add(
          module.copyWith(
            imageSource: reusable[index]!,
            appearance: module.appearance.copyWith(
              showTitle: false,
              showBody: false,
            ),
          ),
        );
      } else {
        designed.add(await prepareDesign(module));
      }
    }
    workout = workout.copyWith(modules: designed);
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
      modules: workout.modules.map((module) {
        final url = urls[module.imageSource] ?? module.imageSource;
        return module.copyWith(
          imageSource: url,
          // Bind the visual/version key to the exact immutable object.
          // Replacing an image URL cannot accidentally retain a valid hint.
          designFingerprint: hasSlideDesign(module)
              ? '${slideDesignFingerprint(module)}:${_storage.refFromURL(url).name}'
              : module.designFingerprint,
        );
      }).toList(),
      countdownImageSource:
          urls[workout.countdownImageSource] ?? workout.countdownImageSource,
    );
  }
}
