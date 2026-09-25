import 'package:cloud_functions/cloud_functions.dart';

class OnboardingDataSource {
  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable(
                'cloudboardAppOnboarding',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 60),
                ),
              )
              .call<Map<String, dynamic>>(input);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? '연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }
}
