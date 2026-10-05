import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_editor_repository.dart';

part 'ai_slides_editor_actions.g.dart';

@riverpod
AiSlidesEditorActions aiSlidesEditorActions(Ref ref) =>
    AiSlidesEditorActions(ref.watch(aiSlidesEditorRepositoryProvider));

class AiSlidesEditorActions {
  const AiSlidesEditorActions(this.repository);
  final AiSlidesEditorRepository repository;
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId) =>
      repository.loadDraft(ownerId);
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft) =>
      repository.saveDraft(ownerId, draft);
  Stream<AiSlideTheme?> watchTheme(String ownerId) =>
      repository.watchTheme(ownerId);
  Future<void> saveTheme(String ownerId, AiSlideTheme theme) =>
      repository.saveTheme(ownerId, theme);
}
