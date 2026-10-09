import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

abstract interface class AiSlideDesignRepository {
  Future<AiSlidesAccess> access(String ownerId);
  Future<AiSlideDesignResult> generate(
    String ownerId,
    String prompt, {
    Uint8List? reference,
  });
  Stream<List<AiSlideDesign>> watchTemplates(String ownerId, String? storeId);
  Future<void> saveTemplate(String ownerId, AiSlideDesign design);
  Future<AiSlideDesign?> loadSelected(String ownerId, String? storeId);
  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    AiSlideDesign design,
  );
}
