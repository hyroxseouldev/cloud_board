import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/workout.dart';

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
        final bytes = base64Decode(source);
        await reference.putData(
          bytes,
          SettableMetadata(contentType: _contentType(bytes)),
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

  String _contentType(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    return 'image/webp';
  }
}
