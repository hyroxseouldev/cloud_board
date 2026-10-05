import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_editor_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_slides_editor_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_editor_model.dart';

part 'ai_slides_editor_repository_impl.g.dart';

@Riverpod(keepAlive: true)
AiSlidesDraftLocalDataSource aiSlidesDraftLocalDataSource(Ref ref) =>
    AiSlidesDraftLocalDataSource();

@Riverpod(keepAlive: true)
AiSlidesEditorRepository aiSlidesEditorRepository(Ref ref) =>
    AiSlidesEditorRepositoryImpl(
      ref.watch(aiSlidesDraftLocalDataSourceProvider),
      AiSlidesThemeFirestoreDataSource(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      ),
    );

class AiSlidesEditorRepositoryImpl implements AiSlidesEditorRepository {
  const AiSlidesEditorRepositoryImpl(this.local, this.remote);
  final AiSlidesDraftLocalDataSource local;
  final AiSlidesThemeFirestoreDataSource remote;
  @override
  Future<AiSlidesSavedDraft?> loadDraft(String ownerId) async =>
      (await local.read(ownerId))?.toEntity();
  @override
  Future<void> saveDraft(String ownerId, AiSlidesSavedDraft? draft) =>
      local.write(
        ownerId,
        draft == null ? null : AiSlidesSavedDraftModel.fromEntity(draft),
      );
  @override
  Stream<AiSlideTheme?> watchTheme(String ownerId) =>
      remote.watch(ownerId).map((model) => model?.toEntity());
  @override
  Future<void> saveTheme(String ownerId, AiSlideTheme theme) =>
      remote.save(ownerId, AiSlideThemeModel.fromEntity(theme));
}
