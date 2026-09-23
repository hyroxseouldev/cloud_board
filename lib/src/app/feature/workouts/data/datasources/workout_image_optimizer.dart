import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

Future<void> _optimizationQueue = Future.value();

Future<WorkoutImageSource> optimizeWorkoutImage(WorkoutImageSource image) {
  // Network transfers can overlap, but decoding several camera originals at
  // once would multiply peak memory on tablets. Keep only one decoder active.
  final work = _optimizationQueue.then(
    (_) => compute(optimizeWorkoutImageBytes, image),
  );
  _optimizationQueue = work.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return work;
}

/// Only large still images are resampled. PNG stays lossless with alpha;
/// animated formats and already small files keep their original bytes.
WorkoutImageSource optimizeWorkoutImageBytes(WorkoutImageSource input) {
  if (input.contentType != 'image/jpeg' && input.contentType != 'image/png') {
    return input;
  }
  final decoder = input.contentType == 'image/jpeg'
      ? img.JpegDecoder()
      : img.PngDecoder();
  final info = decoder.startDecode(input.bytes);
  if (info == null || info.numFrames > 1) return input;
  // Avoid allocating enormous decoded buffers from a malformed/compressed file.
  if (info.width * info.height > 50000000) {
    throw const FormatException('이미지는 5,000만 화소 이하로 선택해 주세요.');
  }
  final maxEdge = input.contentType == 'image/jpeg' ? 2560 : 3840;
  if (info.width <= maxEdge && info.height <= maxEdge) return input;
  final decoded = decoder.decode(input.bytes);
  if (decoded == null) throw const FormatException('이미지 파일을 읽을 수 없습니다.');
  final upright = img.bakeOrientation(decoded);
  final resized = img.copyResize(
    upright,
    width: upright.width >= upright.height ? maxEdge : null,
    height: upright.height > upright.width ? maxEdge : null,
    interpolation: img.Interpolation.average,
  );
  final bytes = Uint8List.fromList(
    input.contentType == 'image/jpeg'
        ? img.encodeJpg(resized, quality: 90)
        : img.encodePng(resized),
  );
  return bytes.length < input.bytes.length
      ? WorkoutImageSource(bytes: bytes, contentType: input.contentType)
      : input;
}
