import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slide_design_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slide_design_repository.dart';

part 'ai_slide_design_actions.g.dart';

@riverpod
AiSlideDesignActions aiSlideDesignActions(Ref ref) =>
    AiSlideDesignActions(ref.watch(aiSlideDesignRepositoryProvider));

class AiSlideDesignActions {
  const AiSlideDesignActions(this.repository);
  final AiSlideDesignRepository repository;
  Future<AiSlidesAccess> access(String ownerId) => repository.access(ownerId);
  Future<AiSlideDesignResult> generate(
    String ownerId,
    String prompt, {
    Uint8List? reference,
  }) async {
    final brief = prompt.trim();
    if ((brief.isEmpty && reference == null) || brief.length > 1500) {
      throw const AiSlidesFailure('원하는 디자인을 1~1,500자로 입력해 주세요.');
    }
    if (reference != null &&
        (reference.isEmpty || reference.length > 10 * 1024 * 1024)) {
      throw const AiSlidesFailure('10MB 이하의 참고 이미지를 선택해 주세요.');
    }
    final access = await repository.access(ownerId);
    if (!access.premium) {
      throw const AiSlidesFailure(
        '디자인 추천과 이미지 스타일 가져오기는 프리미엄 기능이에요. 기본 디자인은 바로 이용할 수 있어요.',
      );
    }
    if (!access.enabled) {
      throw const AiSlidesFailure('디자인 추천을 준비 중이에요. 기본 디자인으로 시작해 주세요.');
    }
    return repository.generate(
      ownerId,
      brief.isEmpty ? '참고 이미지의 색상, 글씨 분위기와 배치를 반영해 주세요.' : brief,
      reference: reference,
    );
  }

  Stream<List<AiSlideDesign>> watchTemplates(String ownerId, String? storeId) =>
      repository.watchTemplates(ownerId, storeId);
  Future<void> saveTemplate(String ownerId, AiSlideDesign design) {
    if (design.name.trim().isEmpty || design.name.length > 60) {
      throw const AiSlidesFailure('클래스 이름을 1~60자로 입력해 주세요.');
    }
    return repository.saveTemplate(
      ownerId,
      design.copyWith(name: design.name.trim()),
    );
  }

  Future<AiSlideDesign?> loadSelected(String ownerId, String? storeId) =>
      repository.loadSelected(ownerId, storeId);
  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    AiSlideDesign design,
  ) => repository.saveSelected(ownerId, storeId, design);
}
