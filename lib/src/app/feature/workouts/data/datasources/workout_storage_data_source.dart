import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

class WorkoutStorageDataSource {
  WorkoutStorageDataSource(this._storage);

  final FirebaseStorage _storage;

  Reference _workoutRoot(String userId, String workoutId) =>
      _storage.ref('users/$userId/workouts/$workoutId');

  Future<Workout> syncImages(String userId, Workout workout) async {
    final modules = <WorkoutModule>[];
    for (final module in workout.modules) {
      final reference = _workoutRoot(
        userId,
        workout.id,
      ).child('modules/${module.id}/background');
      final source = module.imageSource;
      if (source.isEmpty) {
        await _deleteIfExists(reference);
        modules.add(module);
      } else if (_isRemoteUrl(source)) {
        modules.add(module);
      } else {
        final image = WorkoutImageSource.decode(source);
        if (!WorkoutImageSource.supportedContentTypes.contains(
          image.contentType,
        )) {
          throw const FormatException(
            '지원하지 않는 이미지 형식입니다. JPG, PNG, WebP 또는 GIF 파일을 선택해 주세요.',
          );
        }
        await reference.putData(
          image.bytes,
          SettableMetadata(contentType: image.contentType),
        );
        modules.add(
          module.copyWith(imageSource: await reference.getDownloadURL()),
        );
      }
    }
    await _deleteRemovedModules(
      userId,
      workout.id,
      modules.map((module) => module.id).toSet(),
    );
    return workout.copyWith(modules: modules);
  }

  Future<void> deleteWorkout(String userId, String workoutId) =>
      _deleteTree(_workoutRoot(userId, workoutId));

  Future<void> _deleteRemovedModules(
    String userId,
    String workoutId,
    Set<String> activeModuleIds,
  ) async {
    final ListResult result;
    try {
      result = await _workoutRoot(userId, workoutId).child('modules').listAll();
    } on FirebaseException catch (error) {
      if (_isMissingStorage(error)) return;
      rethrow;
    }
    for (final prefix in result.prefixes) {
      if (!activeModuleIds.contains(prefix.name)) await _deleteTree(prefix);
    }
  }

  Future<void> _deleteTree(Reference reference) async {
    final ListResult result;
    try {
      result = await reference.listAll();
    } on FirebaseException catch (error) {
      if (_isMissingStorage(error)) return;
      rethrow;
    }
    for (final item in result.items) {
      await _deleteIfExists(item);
    }
    for (final prefix in result.prefixes) {
      await _deleteTree(prefix);
    }
  }

  Future<void> _deleteIfExists(Reference reference) async {
    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (!_isMissingStorage(error)) rethrow;
    }
  }

  bool _isMissingStorage(FirebaseException error) =>
      error.code == 'object-not-found' || error.code == 'bucket-not-found';

  bool _isRemoteUrl(String value) =>
      value.startsWith('https://') || value.startsWith('http://');
}
