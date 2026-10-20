import 'package:cloud_functions/cloud_functions.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

class SlideStudioDataSource {
  const SlideStudioDataSource(this.functions, this.centerId, this.isCurrent);
  final FirebaseFunctions functions;
  final String centerId;
  final bool Function() isCurrent;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    if (!isCurrent()) {
      throw const AiSlidesFailure(
        '로그인한 센터에서 다시 열어 주세요.',
        code: 'permission-denied',
      );
    }
    try {
      final result = await functions
          .httpsCallable(
            'cloudboardSlideStudio',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 100),
            ),
          )
          .call<Map<String, dynamic>>({
            'action': action,
            'centerId': centerId,
            ...input,
          });
      if (!isCurrent()) {
        throw const AiSlidesFailure(
          '계정 또는 센터가 변경되었어요.',
          code: 'permission-denied',
        );
      }
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AiSlidesFailure(
        error.code == 'not-found'
            ? '새 AI 생성 기능을 준비 중이에요. 템플릿은 차감 없이 사용할 수 있어요.'
            : error.message ?? '연결을 확인해 주세요. 입력과 이전 결과는 유지됩니다.',
        code: error.code,
      );
    }
  }
}
