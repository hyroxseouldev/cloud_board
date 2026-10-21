import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';

abstract interface class TemplateJobsRepository {
  Stream<List<TemplateJob>> watch();
  Future<TemplateJobsReply> list({String? before});

  /// Persists the request before sending. An unresolved request must be recovered
  /// before any new request can be submitted, even after reopening the app.
  Future<TemplateJobsReply> enqueue(StudioInput input, String requestId);
  Future<TemplateJobsReply> retry(TemplateJob job, String requestId);
  Future<TemplateJobsReply?> recover();
  Future<bool> hasUnresolved();
  Future<Uint8List> asset(TemplateJob job);
}
