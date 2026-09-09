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
      final reference = _workoutRoot(userId, workout.id).child(
        'modules/${module.id}/background-${DateTime.now().microsecondsSinceEpoch}',
      );
      final source = module.imageSource;
      if (source.isEmpty) {
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
    // URLs can be shared by duplicated slides and active playback snapshots.
    // Keep immutable assets until a reference-aware garbage collector can remove them.
    return workout.copyWith(modules: modules);
  }

  bool _isRemoteUrl(String value) =>
      value.startsWith('https://') || value.startsWith('http://');
}
