import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
part 'ai_raster_actions.g.dart';

@riverpod
AiRasterActions aiRasterActions(Ref ref) =>
    AiRasterActions(ref.watch(aiRasterRepositoryProvider));

class AiRasterActions {
  const AiRasterActions(this.repository);
  final AiRasterRepository? repository;
  AiRasterRepository get _repository =>
      repository ?? (throw const AiSlidesFailure('로그인한 센터에서 다시 열어 주세요.'));
  Future<AiRasterContext> context() => _repository.context();
  Future<AiRasterGroups> organize(AiRasterDraft draft) =>
      _repository.organize(draft);
  Future<AiRasterReply> generate(
    AiRasterDraft draft,
    AiRasterBrand brand,
    String requestId,
    String? previous,
  ) {
    final error = rasterDraftError(draft);
    if (error != null) throw AiSlidesFailure(error, code: 'invalid-argument');
    return _repository.generate(draft, brand, requestId, previous);
  }

  Future<AiRasterReply> status(String requestId) =>
      _repository.status(requestId);
  Future<WorkoutModule> add(AiRasterJob job, AiRasterBrand brand) =>
      _repository.createModule(job, brand);
}
