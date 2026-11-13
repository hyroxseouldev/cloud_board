import 'package:firebase_storage/firebase_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_usage_data_source.dart';

/// Lazily constructed for non-empty images, so opening an empty draft does not
/// start Firebase work. Auto-disposal and owner identity isolate account caches.
final workoutImageUsageLoaderProvider = Provider.autoDispose
    .family<WorkoutImageUsageDataSource Function(), String>((ref, ownerId) {
      WorkoutImageUsageDataSource? loader;
      return () => loader ??= WorkoutImageUsageDataSource.firebase(
        FirebaseStorage.instance,
        ownerId,
      );
    });
