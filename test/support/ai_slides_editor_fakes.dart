import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_editor_repository.dart';

class MemoryAiSlidesEditorRepository implements AiSlidesEditorRepository {
  final drafts = <String, AiSlidesSavedDraft>{};
  final themes = <String, AiSlideTheme>{};
  @override
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId) async =>
      drafts[ownerId];
  @override
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft) async {
    if (draft == null) {
      drafts.remove(ownerId);
    } else {
      drafts[ownerId] = draft;
    }
  }

  @override
  Stream<AiSlideTheme?> watchTheme(String ownerId) =>
      Stream.value(themes[ownerId]);
  @override
  Future<void> saveTheme(String ownerId, AiSlideTheme theme) async =>
      themes[ownerId] = theme;
}
