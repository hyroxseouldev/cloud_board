import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';

part 'template_job.freezed.dart';

@freezed
abstract class TemplateJob with _$TemplateJob {
  const TemplateJob._();
  const factory TemplateJob({
    required String requestId,
    required String status,
    required String title,
    required String subtitle,
    required String rawWod,
    required String designId,
    required String designName,
    required int createdAtMs,
    required int updatedAtMs,
    String? sha256,
    String? message,
    @Default(false) bool retryable,
  }) = _TemplateJob;
  bool get complete => status == 'complete' && sha256 != null;
  bool get inProgress => status == 'pending' || status == 'processing';
}

@freezed
abstract class TemplateJobsState with _$TemplateJobsState {
  const factory TemplateJobsState({
    @Default([]) List<TemplateJob> jobs,
    @Default(true) bool loading,
    @Default(false) bool submitting,
    @Default(false) bool unresolved,
    @Default(false) bool opening,
    @Default(false) bool authorityDenied,
    StudioUsage? usage,
    String? nextCursor,
    @Default(false) bool loadingMore,
    StudioInput? acceptedInput,
    String? error,
    String? currentRequestId,
    Uint8List? currentPng,
    bool? currentAssetLoading,
    String? currentAssetError,
    bool? recoveryChecked,
  }) = _TemplateJobsState;
}

extension TemplateJobsSelection on TemplateJobsState {
  TemplateJob? get currentJob {
    for (final job in jobs) {
      if (job.requestId == currentRequestId) return job;
    }
    return null;
  }
}

class TemplateJobsReply {
  const TemplateJobsReply(this.jobs, this.usage, [this.nextCursor]);
  final List<TemplateJob> jobs;
  final StudioUsage usage;
  final String? nextCursor;
}
