import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/template_jobs_repository.dart';

final templateTestDesign = aiSlideDesignCatalog.first.copyWith(
  id: 'center-original',
  name: '센터 승인 원본',
  theme: aiSlideDesignCatalog.first.theme.copyWith(
    centerRecipe: const CenterSlideRecipe(
      schemaVersion: 2,
      templateId: 'original',
      revision: 2,
      centerId: 'local-center',
      width: 1920,
      height: 1080,
      backgroundColor: 0xffeeeeee,
      fields: [
        CenterSlideField(
          binding: 'title',
          x: .05,
          y: .05,
          width: .6,
          height: .15,
          fontSize: 48,
          color: 0xff222222,
          fontFamily: 'Pretendard',
          fontWeight: 600,
        ),
      ],
      body: CenterSlideBody(
        x: .05,
        y: .3,
        width: .6,
        height: .6,
        fontSize: 40,
        color: 0xff222222,
        headingColor: 0xff222222,
        fontFamily: 'Pretendard',
      ),
    ),
  ),
);
final templateTestPng = Uint8List.fromList(
  img.encodePng(img.Image(width: 1920, height: 1080)),
);
const templateTestUsage = StudioUsage(
  allowed: true,
  enabled: true,
  used: 2,
  remaining: 8,
  limit: 10,
);
TemplateJob templateTestJob(
  String id, {
  String status = 'pending',
  bool retryable = false,
  int time = 1,
}) => TemplateJob(
  requestId: id,
  status: status,
  title: '센터 결과',
  subtitle: '안내',
  rawWod: 'Row 1,000m\nSquat 22.5kg × 12',
  designId: templateTestDesign.id,
  designName: templateTestDesign.name,
  createdAtMs: time,
  updatedAtMs: time,
  retryable: retryable,
  sha256: status == 'complete'
      ? sha256.convert(templateTestPng).toString()
      : null,
);

class FakeTemplateJobsRepository implements TemplateJobsRepository {
  final events = StreamController<List<TemplateJob>>.broadcast();
  List<TemplateJob> jobs = [];
  List<TemplateJob> older = [];
  int enqueues = 0, assets = 0, retries = 0, recoveries = 0, lists = 0;
  StudioInput? lastInput;
  String? lastId, before, nextCursor;
  bool unresolved = false;
  Object? failure, assetFailure;
  Completer<TemplateJobsReply>? enqueueWait;
  Completer<Uint8List>? assetWait;
  @override
  Stream<List<TemplateJob>> watch() => events.stream;
  @override
  Future<TemplateJobsReply> list({String? before}) async {
    lists++;
    this.before = before;
    if (failure != null) throw failure!;
    return TemplateJobsReply(
      before == null ? jobs : older,
      templateTestUsage,
      before == null ? nextCursor : null,
    );
  }

  @override
  Future<TemplateJobsReply> enqueue(StudioInput input, String requestId) async {
    enqueues++;
    lastInput = input;
    lastId = requestId;
    if (failure != null) {
      unresolved = true;
      throw failure!;
    }
    if (enqueueWait != null) return enqueueWait!.future;
    final job = templateTestJob(
      requestId,
    ).copyWith(title: input.title, subtitle: input.subtitle, rawWod: input.raw);
    jobs = [job, ...jobs];
    return TemplateJobsReply([
      job,
    ], templateTestUsage.copyWith(remaining: 7, used: 3));
  }

  @override
  Future<TemplateJobsReply> retry(TemplateJob job, String requestId) async {
    retries++;
    lastId = requestId;
    return TemplateJobsReply([
      job.copyWith(requestId: requestId, status: 'pending'),
    ], templateTestUsage);
  }

  @override
  Future<bool> hasUnresolved() async => unresolved;
  @override
  Future<TemplateJobsReply?> recover() async {
    recoveries++;
    unresolved = false;
    return TemplateJobsReply(jobs, templateTestUsage);
  }

  @override
  Future<Uint8List> asset(TemplateJob job) async {
    assets++;
    if (assetFailure != null) throw assetFailure!;
    return assetWait != null ? assetWait!.future : templateTestPng;
  }
}
