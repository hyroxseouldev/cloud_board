import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

abstract interface class TemplateJobsDataSource {
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> fields);
  Stream<List<Map<String, dynamic>>> watch();
}

class FirebaseTemplateJobsDataSource implements TemplateJobsDataSource {
  const FirebaseTemplateJobsDataSource({
    required this.functions,
    required this.firestore,
    required this.ownerId,
    required this.centerId,
  });
  final FirebaseFunctions functions;
  final FirebaseFirestore firestore;
  final String ownerId, centerId;
  @override
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> fields,
  ) async {
    try {
      final reply = await functions
          .httpsCallable(
            'cloudboardTemplateJobs',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Map<String, dynamic>>({
            ...fields,
            'action': action,
            'centerId': centerId,
          });
      return reply.data;
    } on FirebaseFunctionsException catch (error) {
      throw AiSlidesFailure(
        error.code == 'not-found'
            ? '새 슬라이드 생성 서버를 사용할 수 없어요. 입력과 이전 결과는 유지됩니다.'
            : error.message ?? '연결을 확인해 주세요. 접수 여부를 같은 요청으로 다시 확인할 수 있어요.',
        code: error.code,
      );
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watch() => firestore
      .collection('users')
      .doc(ownerId)
      .collection('templateGenerationCenters')
      .doc(centerId)
      .collection('jobs')
      .orderBy('createdAtMs', descending: true)
      .limit(20)
      .snapshots()
      .map((event) => event.docs.map((doc) => doc.data()).toList());
}
