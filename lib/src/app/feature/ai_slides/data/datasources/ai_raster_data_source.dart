import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

class AiRasterDataSource {
  AiRasterDataSource(this.functions, this.centerId, this.isCurrent);
  final FirebaseFunctions functions;
  final String centerId;
  final bool Function() isCurrent;

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!isCurrent()) {
      throw const AiSlidesFailure('계정 또는 센터가 변경되었어요. 다시 열어 주세요.');
    }
    try {
      final result = await functions
          .httpsCallable(
            'cloudboardAiSlideRaster',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 220),
            ),
          )
          .call<Map<String, dynamic>>({
            'action': action,
            'centerId': centerId,
            ...data,
          });
      if (!isCurrent()) {
        throw const AiSlidesFailure('계정 또는 센터가 변경되었어요. 다시 열어 주세요.');
      }
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AiSlidesFailure(
        (error.code == 'not-found' && error.details is! Map) ||
                error.code == 'unimplemented'
            ? '센터 AI 이미지 기능이 아직 연결되지 않았어요. 기존 템플릿은 계속 사용할 수 있어요.'
            : error.message ?? '연결을 확인해 주세요. 입력과 이전 결과는 유지돼요.',
        code: error.code,
        reason: error.details is Map
            ? error.details['reason'] as String?
            : null,
      );
    } on TimeoutException {
      throw const AiSlidesFailure(
        '생성 결과가 아직 도착하지 않았어요. 상태 확인은 추가 차감되지 않아요.',
        code: 'deadline-exceeded',
      );
    }
  }
}
