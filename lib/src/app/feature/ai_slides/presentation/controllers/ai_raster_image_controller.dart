import 'dart:async';
import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_raster_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/private_slide_image_cache.dart';
part 'ai_raster_image_controller.g.dart';

String rasterImageKey(AiRasterBrand brand, AiRasterJob? job, String kind) =>
    '${brand.key}/${job?.requestId}/$kind';

@riverpod
PrivateSlideImageCache aiRasterImageCache(Ref ref) {
  ref.watch(aiRasterRepositoryProvider);
  final cache = PrivateSlideImageCache();
  ref.listen(aiRasterControllerProvider, (_, state) {
    final brand = state.brand;
    cache.retainKeys(
      brand == null
          ? {}
          : {
              rasterImageKey(brand, null, 'logo'),
              rasterImageKey(brand, null, 'reference'),
              for (final job in [
                if (state.result != null) state.result!,
                ...state.history,
              ])
                rasterImageKey(brand, job, 'artwork'),
            },
    );
  }, fireImmediately: true);
  final retention = ref.keepAlive();
  Timer? release;
  ref.onCancel(() {
    release = Timer(const Duration(minutes: 2), retention.close);
  });
  ref.onResume(() {
    release?.cancel();
  });
  ref.onDispose(() {
    release?.cancel();
    cache.dispose();
  });
  return cache;
}

@riverpod
FutureOr<ui.Image?> aiRasterImage(
  Ref ref,
  AiRasterBrand brand,
  AiRasterJob? job,
  String kind,
) {
  final repository = ref.watch(aiRasterRepositoryProvider);
  final current = ref.watch(
    aiRasterControllerProvider.select((state) => state.brand?.key),
  );
  if (repository == null || current != brand.key)
    throw const AiSlidesFailure('현재 센터 이미지를 다시 확인해 주세요.');
  final cache = ref.watch(aiRasterImageCacheProvider);
  // Visible decoded images must also re-authorize; retaining a widget is not
  // permission to retain private pixels forever after its encoded TTL expires.
  final expiry = Timer(const Duration(minutes: 2), ref.invalidateSelf);
  ref.onDispose(expiry.cancel);
  final key = rasterImageKey(brand, job, kind);
  ui.Image? retain(ui.Image? image) {
    if (!ref.mounted) {
      image?.dispose();
      return null;
    }
    if (image != null) ref.onDispose(image.dispose);
    return image;
  }

  final cached = cache.peek(key);
  if (cached != null) return retain(cached);
  return cache.load(key, () => repository.asset(brand, job, kind)).then(retain);
}
