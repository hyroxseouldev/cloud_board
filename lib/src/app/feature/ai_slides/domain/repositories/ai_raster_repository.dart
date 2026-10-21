import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

typedef AiRasterContext = ({
  AiRasterBrand brand,
  AiRasterJob? recent,
  AiRasterJob? previous,
  bool allowed,
  bool enabled,
  int remaining,
  int limit,
});
typedef AiRasterReply = ({AiRasterJob job, int remaining, int limit});
typedef AiRasterGroups = ({
  List<AiRasterGroup> groups,
  int remaining,
  int limit,
});

abstract interface class AiRasterRepository {
  Future<AiRasterContext> context();
  Future<AiRasterGroups> organize(AiRasterDraft draft);
  Future<AiRasterReply> generate(
    AiRasterDraft draft,
    AiRasterBrand brand,
    String requestId,
    String? previousRequestId,
  );
  Future<AiRasterReply> status(String requestId);
  Future<AiRasterJob> confirm(AiRasterJob job, AiRasterBrand brand);
  Future<Uint8List> asset(AiRasterBrand brand, AiRasterJob? job, String kind);
  Future<WorkoutModule> createModule(AiRasterJob job, AiRasterBrand brand);
  void dispose();
}
