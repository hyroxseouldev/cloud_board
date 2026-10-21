import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/slide_studio_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

class FakeStudioRepository implements SlideStudioRepository {
  int generations = 0,
      statuses = 0,
      validations = 0,
      prepares = 0,
      saves = 0,
      usageReads = 0;
  StudioUsage currentUsage = const StudioUsage(
    allowed: true,
    enabled: true,
    used: 2,
    remaining: 8,
    limit: 10,
    tokenContractAvailable: true,
  );
  Object? usageFailure, generationFailure, saveFailure, validationFailure;
  Completer<StudioOperation>? generation;
  Completer<WorkoutModule>? saving;
  String? lastId, lastStatusId;
  StudioInput? lastInput;
  Uint8List? lastReference;
  final saved = <String, WorkoutModule>{};
  @override
  Future<StudioUsage> usage({String? requestId, bool raster = false}) async {
    usageReads++;
    if (usageFailure != null) throw usageFailure!;
    return currentUsage;
  }

  @override
  Future<StudioOperation> generate(
    StudioInput input,
    String requestId,
    Uint8List? reference,
  ) async {
    generations++;
    lastId = requestId;
    lastInput = input;
    lastReference = reference;
    if (generationFailure != null) throw generationFailure!;
    return generation?.future ??
        Future.value(
          StudioOperation(
            requestId: requestId,
            status: 'completed',
            groups: [
              AiRasterGroup(heading: 'A', lines: rasterSourceLines(input.raw)),
            ],
          ),
        );
  }

  @override
  Future<StudioOperation> status(
    String requestId, {
    required bool reference,
  }) async {
    statuses++;
    lastStatusId = requestId;
    return StudioOperation(
      requestId: requestId,
      status: 'completed',
      groups: [
        AiRasterGroup(heading: 'A', lines: rasterSourceLines(lastInput!.raw)),
      ],
    );
  }

  @override
  Future<void> validate(AiSlideDraft draft) async {
    validations++;
    if (validationFailure != null) throw validationFailure!;
  }

  @override
  void validateArtwork(AiRasterDraft draft, AiRasterBrand brand) {
    if (validationFailure != null) throw validationFailure!;
  }

  @override
  Future<WorkoutModule> prepare(StudioResult result) async {
    prepares++;
    return previewAiSlide(
      result.draft!,
      result.id,
    ).copyWith(imageSource: 'https://local.invalid/result.png');
  }

  @override
  Future<WorkoutModule> save(WorkoutModule module) async {
    saves++;
    if (saveFailure != null) throw saveFailure!;
    if (saving != null) return saving!.future;
    return saved.putIfAbsent(module.id, () => module);
  }
}
