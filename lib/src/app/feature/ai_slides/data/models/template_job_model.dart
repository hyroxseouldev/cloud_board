import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_editor_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/slide_studio_model.dart';

Map<String, dynamic> templateJobInput(StudioInput input, String id) {
  final recipe = input.design.theme.centerRecipe;
  return {
    'requestId': id,
    'title': input.title,
    'subtitle': input.subtitle,
    'rawWod': input.raw,
    'design': {
      'id': input.design.id,
      'name': input.design.name,
      'theme': {
        ...AiSlideThemeModel.fromEntity(
          input.design.theme.copyWith(centerRecipe: null),
        ).toJson(),
        // The server loads the authoritative recipe; no client URL is trusted.
        if (recipe != null)
          'centerRecipe': {
            'templateId': recipe.templateId,
            'revision': recipe.revision,
          },
      },
      if (recipe == null && input.design.sample != null)
        'sample': AiSlideDraftModel.fromEntity(input.design.sample!).toJson(),
    },
  };
}

TemplateJob readTemplateJob(Map<String, dynamic> data) {
  String text(String key, int max) {
    final value = data[key];
    if (value is! String || value.length > max) {
      throw const FormatException('생성 작업 응답을 확인하지 못했어요.');
    }
    return value;
  }

  final id = text('requestId', 120), status = text('status', 20);
  final created = data['createdAtMs'], updated = data['updatedAtMs'];
  final artifact = data['artifact'];
  if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(id) ||
      !['pending', 'processing', 'complete', 'failed'].contains(status) ||
      created is! int ||
      updated is! int ||
      created < 0 ||
      updated < 0 ||
      (status == 'complete' &&
          (artifact is! Map ||
              artifact['width'] != 1920 ||
              artifact['height'] != 1080 ||
              artifact['sha256'] is! String ||
              !RegExp(r'^[a-f0-9]{64}$')
                  .hasMatch(artifact['sha256'] as String)))) {
    throw const FormatException('생성 작업 응답을 확인하지 못했어요.');
  }
  return TemplateJob(
    requestId: id,
    status: status,
    title: text('title', 60),
    subtitle: text('subtitle', 120),
    rawWod: text('rawWod', 6000),
    designId: text('designId', 160),
    designName: text('designName', 200),
    createdAtMs: created,
    updatedAtMs: updated,
    sha256: status == 'complete' ? artifact['sha256'] as String : null,
    message: data['message'] as String?,
    retryable: data['retryable'] == true,
  );
}

TemplateJobsReply readTemplateJobsReply(Map<String, dynamic> data) =>
    TemplateJobsReply(
      (data['jobs'] is List ? data['jobs'] as List : [data['job']])
          .take(20)
          .map((v) => readTemplateJob(Map<String, dynamic>.from(v as Map)))
          .toList(),
      readStudioUsage(Map<String, dynamic>.from(data['usage'] as Map)),
      data['nextCursor'] as String?,
    );

Uint8List readTemplateJobPng(Map<String, dynamic> data, TemplateJob job) {
  final encoded = data['base64'];
  if (!job.complete ||
      data['sha256'] != job.sha256 ||
      data['width'] != 1920 ||
      data['height'] != 1080 ||
      encoded is! String ||
      encoded.length > 28 * 1024 * 1024) {
    throw const AiSlidesFailure('완성 이미지 정보를 확인하지 못했어요.');
  }
  final bytes = base64Decode(encoded);
  if (bytes.length < 24) throw const AiSlidesFailure('이미지 데이터가 올바르지 않아요.');
  final header = ByteData.sublistView(bytes);
  if (bytes.length < 24 ||
      bytes.length > 20 * 1024 * 1024 ||
      header.getUint32(0) != 0x89504e47 ||
      header.getUint32(4) != 0x0d0a1a0a ||
      header.getUint32(12) != 0x49484452 ||
      header.getUint32(16) != 1920 ||
      header.getUint32(20) != 1080 ||
      sha256.convert(bytes).toString() != job.sha256) {
    throw const AiSlidesFailure('완성 이미지가 변경되었거나 손상되었어요. 다시 불러와 주세요.');
  }
  return bytes;
}
