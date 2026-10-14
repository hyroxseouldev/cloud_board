import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';

bool audienceClassBrandingAvailable(AudienceBranding? policy, {int? nowMs}) =>
    policy?.classScreensAvailableAt(
      nowMs ?? DateTime.now().millisecondsSinceEpoch,
    ) ==
    true;

String audienceLogoBenefit({
  required bool canHideLogo,
  required bool classScreensAvailable,
}) {
  final scope = classScreensAvailable ? '대기·수업 화면' : '대기 화면';
  return '$scope ${AppBrand.name} 로고 ${canHideLogo ? '숨김 가능' : '고정 표시'}';
}

String audienceLogoSettingDescription(bool classScreensAvailable) =>
    classScreensAvailable
    ? '대기·시작 카운트다운·수업 화면에 함께 적용됩니다. Plus부터 숨길 수 있어요.'
    : '대기 화면에 적용됩니다. Plus부터 숨길 수 있어요.';
