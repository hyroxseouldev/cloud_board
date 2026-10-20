import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

abstract interface class SlideStudioRepository {
  Future<StudioUsage> usage({String? requestId, bool raster = false});
  Future<StudioOperation> generate(
    StudioInput input,
    String requestId,
    Uint8List? reference,
  );
  Future<StudioOperation> status(String requestId, {required bool reference});
  Future<void> validate(AiSlideDraft draft);
  void validateArtwork(AiRasterDraft draft, AiRasterBrand brand);
  Future<WorkoutModule> prepare(StudioResult result);
  Future<WorkoutModule> save(WorkoutModule module);
}
