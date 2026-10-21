import 'dart:convert';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/template_jobs_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/template_jobs_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'template_jobs_actions.g.dart';

@riverpod
TemplateJobsActions templateJobsActions(Ref ref) =>
    TemplateJobsActions(ref.watch(templateJobsRepositoryProvider));

class TemplateJobsActions {
  const TemplateJobsActions(this.repository);
  final TemplateJobsRepository? repository;
  TemplateJobsRepository get _repo =>
      repository ??
      (throw const AiSlidesFailure(
        '센터 연결을 확인한 뒤 다시 열어 주세요.',
        code: 'permission-denied',
      ));
  Stream<List<TemplateJob>> watch() => _repo.watch();
  Future<TemplateJobsReply> list({String? before}) =>
      _repo.list(before: before);
  Future<bool> hasUnresolved() => _repo.hasUnresolved();
  Future<TemplateJobsReply?> recover() => _repo.recover();
  Future<TemplateJobsReply> enqueue(StudioInput input, String id) {
    if (input.design.theme.centerRecipe == null) {
      throw const AiSlidesFailure('기본 템플릿은 AI 없이 무료로 생성해 주세요.');
    }
    if (input.raw.trim().isEmpty ||
        input.raw.length > 6000 ||
        input.title.trim().isEmpty ||
        input.title.length > 60 ||
        input.subtitle.length > 120) {
      throw const AiSlidesFailure(
        '제목(1~60자), 운동 안내(120자 이내), 수업 내용(1~6,000자)을 확인해 주세요.',
      );
    }
    // No raw layout preflight: Luna replaces and arranges the selected recipe.
    return _repo.enqueue(input, id);
  }

  Future<TemplateJobsReply> retry(TemplateJob job, String id) =>
      _repo.retry(job, id);
  Future<Uint8List> asset(TemplateJob job) => _repo.asset(job);
  Future<WorkoutModule> prepare(TemplateJob job) async {
    final bytes = await _repo.asset(
      job,
    ); // Fresh authority + immutable version check.
    final base = WorkoutModule.empty('template-${job.requestId}');
    return base.copyWith(
      name: job.title,
      text: job.rawWod,
      imageSource: 'data:image/png;base64,${base64Encode(bytes)}',
      showTimer: false,
      showSets: false,
      appearance: base.appearance.copyWith(
        showTitle: false,
        showBody: false,
        showBrand: false,
        timerX: .84,
        timerY: .5,
      ),
    );
  }
}
