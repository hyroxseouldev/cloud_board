import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

class AiSlidesDataSource {
  Future<AiSlidesModel> call(Map<String, Object> input) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AiSlidesFailure('로그인 후 이용해 주세요.');
    }
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable(
                'cloudboardAiSlides',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 60),
                ),
              )
              .call<Map<String, dynamic>>(input);
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw const AiSlidesFailure('계정이 변경되었습니다. 다시 열어 주세요.');
      }
      return AiSlidesModel.fromJson(response.data);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      throw AiSlidesFailure(
        error.message ?? 'AI에 연결하지 못했습니다. 연결을 확인해 주세요.',
        code: error.code,
        reason: details is Map ? details['reason'] as String? : null,
      );
    }
  }
}
