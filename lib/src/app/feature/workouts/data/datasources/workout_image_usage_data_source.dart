import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_board/src/app/core/utils/bounded_map.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_optimizer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_image_budget.dart';

typedef StoredImageBytes = Future<int?> Function(String bucket, String path);

/// Editor-scoped, bounded cache. Tokens are not asset identities; owner and
/// bucket checks happen before metadata access. No arbitrary HTTP requests.
class WorkoutImageUsageDataSource {
  WorkoutImageUsageDataSource({
    required this.ownerId,
    required this.bucket,
    required this.readBytes,
    this.prepareDesign = prepareSlideDesign,
    this.optimize = optimizeWorkoutImage,
    this.allowEmulatorUrls = false,
  });

  factory WorkoutImageUsageDataSource.firebase(
    FirebaseStorage storage,
    String ownerId,
  ) => WorkoutImageUsageDataSource(
    ownerId: ownerId,
    bucket: storage.bucket,
    allowEmulatorUrls: storage.app.options.projectId.startsWith('demo-'),
    readBytes: (_, path) async =>
        (await storage
                .ref(path)
                .getMetadata()
                .timeout(const Duration(seconds: 10)))
            .size,
  );

  final String ownerId, bucket;
  final bool allowEmulatorUrls;
  final StoredImageBytes readBytes;
  final Future<WorkoutModule> Function(WorkoutModule) prepareDesign;
  final Future<WorkoutImageSource> Function(WorkoutImageSource) optimize;
  final _cache = <String, Future<int?>>{};

  void retry() => _cache.clear();

  Future<int?> _cached(String key, Future<int?> Function() load) async {
    final previous = _cache[key];
    if (previous != null) return previous;
    final pending = load();
    if (_cache.length >= 256) _cache.remove(_cache.keys.first);
    _cache[key] = pending;
    try {
      return await pending;
    } catch (_) {
      _cache.remove(key);
      rethrow;
    }
  }

  Future<({String identity, int? bytes})> _source(
    String source,
    String workoutId,
  ) async {
    if (source.isEmpty) return (identity: '', bytes: 0);
    final uri = Uri.tryParse(source);
    if (uri?.scheme == 'http' ||
        uri?.scheme == 'https' ||
        uri?.scheme == 'gs') {
      final parts = uri!.pathSegments;
      final firebase =
          ((uri.scheme == 'https' &&
                  uri.host == 'firebasestorage.googleapis.com') ||
              (allowEmulatorUrls &&
                  uri.scheme == 'http' &&
                  (uri.host == '127.0.0.1' || uri.host == 'localhost'))) &&
          parts.length == 5 &&
          parts[0] == 'v0' &&
          parts[1] == 'b' &&
          parts[3] == 'o';
      final sourceBucket = firebase
          ? parts[2]
          : uri.scheme == 'gs'
          ? uri.host
          : '';
      final path = firebase
          ? parts[4]
          : uri.scheme == 'gs'
          ? parts.join('/')
          : '';
      if (sourceBucket != bucket ||
          !path.startsWith('users/$ownerId/workouts/')) {
        return (identity: source, bytes: null);
      }
      final identity = 'gs://$bucket/$path';
      final bytes = await _cached(identity, () async {
        final size = await readBytes(bucket, path);
        if (size == null || size < 0) {
          throw StateError('Invalid image metadata');
        }
        return size;
      });
      return (identity: identity, bytes: bytes);
    }
    final original = WorkoutImageSource.decode(source);
    final identity =
        'gs://$bucket/users/$ownerId/workouts/$workoutId/images/${sha256.convert(original.bytes)}';
    final size = await _cached(
      identity,
      () async => (await optimize(original)).bytes.length,
    );
    return (identity: identity, bytes: size);
  }

  Future<WorkoutImageUsage> measure(Workout workout) async {
    final sources = <({String id, String source})>[];
    var failed = false;
    // Designs are normally already prepared by the slide editor. Regenerate
    // only a changed design; the existing renderer owns its own render cache.
    for (final module in workout.modules) {
      var source = module.imageSource;
      if (hasSlideDesign(module)) {
        final visual = slideDesignFingerprint(module);
        if (module.designFingerprint != visual &&
            !(module.designFingerprint?.startsWith('$visual:') ?? false)) {
          try {
            source = (await prepareDesign(module)).imageSource;
          } catch (_) {
            failed = true;
            source = 'https://unmeasured.invalid/${module.id}';
          }
        }
      }
      sources.add((id: module.id, source: source));
    }
    sources.add((id: '\u0000countdown', source: workout.countdownImageSource));
    final results = await boundedMap(sources, (item) async {
      try {
        return await _source(item.source, workout.id);
      } catch (_) {
        failed = true;
        return (identity: item.source, bytes: null);
      }
    });
    final unique = <String, int?>{};
    final modules = <String, int?>{};
    for (var i = 0; i < sources.length; i++) {
      unique[results[i].identity] = results[i].bytes;
      modules[sources[i].id] = results[i].bytes;
    }
    return WorkoutImageUsage(
      moduleBytes: modules..remove('\u0000countdown'),
      countdownBytes: results.last.bytes,
      knownBytes: unique.values.fold(0, (sum, bytes) => sum + (bytes ?? 0)),
      unknownCount: unique.values.where((bytes) => bytes == null).length,
      failed: failed,
    );
  }
}
