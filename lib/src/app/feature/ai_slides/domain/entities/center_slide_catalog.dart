import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';

part 'center_slide_catalog.freezed.dart';

@freezed
abstract class CenterSlideCatalog with _$CenterSlideCatalog {
  const factory CenterSlideCatalog({
    required int revision,
    required String centerId,
    required String centerName,
    required List<AiSlideDesign> templates,
  }) = _CenterSlideCatalog;
}

@freezed
abstract class CenterSlideCatalogScope with _$CenterSlideCatalogScope {
  const factory CenterSlideCatalogScope({
    required String ownerId,
    required String centerId,
  }) = _CenterSlideCatalogScope;
}

CenterSlideCatalog emptyCenterSlideCatalog([String centerId = '']) =>
    CenterSlideCatalog(
      revision: 0,
      centerId: centerId,
      centerName: '',
      templates: const [],
    );
