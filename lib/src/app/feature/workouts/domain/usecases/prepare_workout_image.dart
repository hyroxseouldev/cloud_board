import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_optimizer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

Future<String> prepareWorkoutImage(
  Uint8List bytes, {
  String? contentType,
}) async {
  if (bytes.length > 40 * 1024 * 1024) {
    throw const FormatException('40MB 이하의 이미지를 선택해 주세요.');
  }
  // Detect from signature before processing; never trust a filename alone.
  final source = WorkoutImageSource.identify(bytes, contentType: contentType);
  final optimized = await optimizeWorkoutImage(source);
  return WorkoutImageSource.fromBytes(
    optimized.bytes,
    contentType: optimized.contentType,
  );
}
