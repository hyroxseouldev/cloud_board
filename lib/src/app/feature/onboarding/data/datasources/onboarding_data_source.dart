import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_board/src/app/core/config/firebase_environment.dart';

class OnboardingDataSource {
  OnboardingDataSource({this.functions, this.auth});

  final FirebaseFunctions? functions;
  final FirebaseAuth? auth;

  Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    try {
      if (!FirebaseEnvironment.isProduction &&
          const ['sendCode', 'verifyCode'].contains(input['action'])) {
        // Pick up an operator-granted developmentTester claim without requiring
        // the tester to sign out and lose the current onboarding form.
        await (auth ?? FirebaseAuth.instance).currentUser?.getIdToken(true);
      }
      final response =
          await (functions ??
                  FirebaseFunctions.instanceFor(region: 'asia-northeast3'))
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
