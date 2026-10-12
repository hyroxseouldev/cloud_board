import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/config/app_links.dart';

enum AccountDeletionResult { completed, processing }

extension AccountDeletionResultMessage on AccountDeletionResult {
  String get message => this == AccountDeletionResult.completed
      ? '${AppBrand.nameKo} 계정과 서비스 데이터를 삭제했습니다. 백업과 처리 기록은 개인정보처리방침의 보관 기간을 따릅니다.'
      : '계정 삭제를 처리 중입니다. 계정 이용은 제한되며 서버에서 정리를 계속합니다. 문의: ${AppLinks.supportEmail}';
}

abstract interface class AccountDeletionRepository {
  Future<AccountDeletionResult> deleteAccount({String? password});
}
