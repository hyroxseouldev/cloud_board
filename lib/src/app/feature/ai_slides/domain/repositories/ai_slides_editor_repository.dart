import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';

abstract interface class AiSlidesEditorRepository {
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId);
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft);
  Stream<AiSlideTheme?> watchTheme(String ownerId);
  Future<void> saveTheme(String ownerId, AiSlideTheme theme);
}
