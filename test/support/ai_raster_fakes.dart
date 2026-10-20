import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_raster_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

const rasterTestBrand = AiRasterBrand(
  key: 'brand-1',
  revision: 1,
  catalogRevision: 1,
  recipeRevision: 1,
  templateId: 'approved',
  name: '로컬 센터',
  reference: AiRasterAsset(sha256: 'reference', width: 1672, height: 941),
  logo: AiRasterAsset(
    sha256: 'logo',
    width: 1672,
    height: 941,
    sourceRect: [535, 300, 615, 265],
  ),
  backgroundColor: '#fff8ee',
  textColor: '#202020',
  accentColor: '#d45a30',
);
const rasterTestDraft = AiRasterDraft(
  rawWod: 'Row 1,000 m\nSquat 22.5 kg × 12\n휴식 60초',
  groups: [
    AiRasterGroup(
      heading: 'A',
      lines: ['Row 1,000 m', 'Squat 22.5 kg × 12', '휴식 60초'],
    ),
  ],
);
AiRasterJob rasterTestJob(String id, [AiRasterDraft draft = rasterTestDraft]) =>
    AiRasterJob(
      requestId: id,
      status: 'completed',
      brandKey: rasterTestBrand.key,
      draft: draft,
      artifact: const AiRasterAsset(
        sha256: 'artwork',
        width: 1536,
        height: 864,
      ),
    );

class FakeRasterRepository implements AiRasterRepository {
  int generations = 0,
      organizations = 0,
      statuses = 0,
      additions = 0,
      assets = 0;
  String? lastRequestId, lastStatusId;
  AiRasterJob? recent, previous, added;
  AiRasterBrand brand = rasterTestBrand;
  Completer<AiRasterReply>? generation;
  Completer<AiRasterGroups>? grouping;
  Object? generateFailure, statusFailure, contextFailure;
  Uint8List? image;
  @override
  Future<AiRasterContext> context() async {
    if (contextFailure != null) throw contextFailure!;
    return (
      brand: brand,
      recent: recent,
      previous: previous,
      allowed: true,
      enabled: true,
      remaining: 30,
      limit: 30,
    );
  }

  @override
  Future<AiRasterGroups> organize(AiRasterDraft draft) async {
    organizations++;
    return grouping != null
        ? await grouping!.future
        : (groups: draft.groups, remaining: 29, limit: 30);
  }

  @override
  Future<AiRasterReply> generate(
    AiRasterDraft draft,
    AiRasterBrand brand,
    String requestId,
    String? previousRequestId,
  ) async {
    generations++;
    lastRequestId = requestId;
    if (generateFailure != null) throw generateFailure!;
    return generation != null
        ? await generation!.future
        : (job: rasterTestJob(requestId, draft), remaining: 29, limit: 30);
  }

  @override
  Future<AiRasterReply> status(String requestId) async {
    statuses++;
    lastStatusId = requestId;
    if (statusFailure != null) throw statusFailure!;
    return (job: rasterTestJob(requestId), remaining: 29, limit: 30);
  }

  @override
  Future<AiRasterJob> confirm(AiRasterJob job, AiRasterBrand brand) async =>
      job;
  @override
  Future<Uint8List> asset(
    AiRasterBrand brand,
    AiRasterJob? job,
    String kind,
  ) async {
    assets++;
    return image ?? (throw StateError('No private test image loaded'));
  }

  @override
  Future<WorkoutModule> createModule(
    AiRasterJob job,
    AiRasterBrand brand,
  ) async {
    additions++;
    added = job;
    return WorkoutModule.empty('raster-${job.requestId}')
        .copyWith(name: job.draft.title, text: job.draft.rawWod);
  }

  @override
  void dispose() {}
}
