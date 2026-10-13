import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

/// Preview-only policy. Stored custom content is never overwritten locally.
BrandTemplate brandPreviewForPlan(
  BrandTemplate saved,
  StoreEntitlement? access,
) {
  if (access?.policyKnown != true) return saved;
  if (access!.idleScreenCustomization == 'basic') {
    return BrandTemplate.initial().copyWith(
      storeName: AppBrand.name,
      primaryColorValue: 0xFF526B60,
      standbyFullscreen: false,
      standbyTextColor: 0xFF2B332E,
      standbyBackgroundColor: 0xFFF7F5EF,
      showCloudBoardLogo: true,
    );
  }
  return saved.copyWith(
    logoUrl: access.canUseCenterLogo ? saved.logoUrl : null,
    showCloudBoardLogo:
        !access.canHideCloudBoardLogo || saved.showCloudBoardLogo,
  );
}

bool brandingLocked(StoreEntitlement? access) =>
    access?.policyKnown == true && access!.idleScreenCustomization != 'custom';
