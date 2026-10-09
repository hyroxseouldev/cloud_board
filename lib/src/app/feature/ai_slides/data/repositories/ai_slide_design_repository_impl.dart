import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slide_design_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_slide_design_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';

part 'ai_slide_design_repository_impl.g.dart';

@Riverpod(keepAlive: true)
AiSlideDesignRepository aiSlideDesignRepository(Ref ref) =>
    AiSlideDesignRepositoryImpl(
      AiSlideDesignDataSource(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
        FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        SharedPreferencesAsync(),
      ),
    );

class AiSlideDesignRepositoryImpl implements AiSlideDesignRepository {
  const AiSlideDesignRepositoryImpl(this.source);
  final AiSlideDesignDataSource source;
  @override
  Future<AiSlidesAccess> access(String ownerId) async {
    final data = await source.call(ownerId, {'action': 'status'});
    return AiSlidesAccess(
      premium: data['premium'] == true,
      enabled: data['enabled'] == true,
      remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      limit: (data['limit'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<AiSlideDesignResult> generate(
    String ownerId,
    String prompt, {
    Uint8List? reference,
  }) async {
    final data = await source.call(ownerId, {
      'action': 'generate',
      'prompt': prompt,
      if (reference != null) ...{
        'imageBase64': await source.prepareReference(reference),
        'mimeType': 'image/jpeg',
      },
    });
    return parseAiSlideDesignResult(data, reference: reference != null);
  }

  @override
  Stream<List<AiSlideDesign>> watchTemplates(String ownerId, String? storeId) =>
      source
          .watchTemplates(ownerId, storeId)
          .map(
            (values) =>
                values.map((value) => value.$2.toEntity(value.$1)).toList()
                  ..sort((a, b) => a.name.compareTo(b.name)),
          );
  @override
  Future<void> saveTemplate(String ownerId, AiSlideDesign design) => source
      .saveTemplate(ownerId, design.id, AiSlideDesignModel.fromEntity(design));
  @override
  Future<AiSlideDesign?> loadSelected(String ownerId, String? storeId) async {
    final value = await source.loadSelected(ownerId, storeId);
    return value?.$2.toEntity(value.$1);
  }

  @override
  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    AiSlideDesign design,
  ) => source.saveSelected(
    ownerId,
    storeId,
    design.id,
    AiSlideDesignModel.fromEntity(design),
  );
}
