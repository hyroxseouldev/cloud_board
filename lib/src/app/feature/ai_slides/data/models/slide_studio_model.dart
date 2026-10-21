import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';

StudioUsage readStudioUsage(Map<String, dynamic> data) {
  final used = data['used'],
      remaining = data['remaining'],
      limit = data['limit'];
  final unlimited = data['unlimited'] == true;
  if (used is! int ||
      used < 0 ||
      (!unlimited &&
          (remaining is! int || remaining < 0 || limit is! int || limit < 0))) {
    throw const AiSlidesFailure('사용량 응답을 확인하지 못했어요.');
  }
  final tokens = data['lastOperationTokens'];
  final validTokens =
      tokens is Map &&
      tokens['input'] is int &&
      tokens['output'] is int &&
      tokens['input'] >= 0 &&
      tokens['output'] >= 0;
  return StudioUsage(
    allowed: data['allowed'] == true,
    enabled: data['enabled'] == true,
    used: used,
    remaining: remaining as int?,
    limit: limit as int?,
    unlimited: unlimited,
    tokenContractAvailable:
        data['tokenAllowance'] is Map &&
        data['tokenAllowance']['kind'] == 'not-metered',
    lastInputTokens: validTokens ? tokens['input'] as int : null,
    lastOutputTokens: validTokens ? tokens['output'] as int : null,
    lastRequestId: validTokens ? tokens['requestId'] as String? : null,
    resetsAt: data['resetsAtMs'] is int
        ? DateTime.fromMillisecondsSinceEpoch(data['resetsAtMs'] as int)
        : null,
    availabilityReason: data['availabilityReason'] as String?,
  );
}

StudioOperation readStudioOperation(
  Map<String, dynamic> data, {
  required bool reference,
}) {
  final job = Map<String, dynamic>.from(data['job'] as Map);
  final result = job['result'];
  final designs = job['operation'] == 'style' && result != null
      ? parseAiSlideDesignResult({
          ...data,
          'result': result,
        }, reference: reference)
      : null;
  return StudioOperation(
    requestId: job['requestId'] as String,
    status: job['status'] as String,
    message: job['message'] as String?,
    designs: designs?.designs ?? [],
    warnings: designs?.warnings ?? [],
    groups: result is Map && result['groups'] is List
        ? (result['groups'] as List)
              .map(
                (v) =>
                    AiRasterGroup.fromJson(Map<String, dynamic>.from(v as Map)),
              )
              .toList()
        : [],
  );
}
