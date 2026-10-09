import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';

import 'package:cloud_board/src/app/feature/ai_timer/data/datasources/ai_timer_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';

class AiSlideDesignDataSource {
  AiSlideDesignDataSource(
    this.firestore,
    this.auth,
    this.functions,
    this.preferences,
  );
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final SharedPreferencesAsync preferences;
  Future<void> _pending = Future.value();

  void requireOwner(String ownerId) {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous || user.uid != ownerId) {
      throw const AiSlidesFailure('계정이 변경되었습니다. 다시 열어 주세요.');
    }
  }

  Future<Map<String, dynamic>> call(
    String ownerId,
    Map<String, Object> input,
  ) async {
    requireOwner(ownerId);
    try {
      // Content and design generation share the aiSlides quota. Read it through
      // the existing content endpoint, independently of design API deployment.
      final response = await functions
          .httpsCallable(
            input['action'] == 'status'
                ? 'cloudboardAiSlides'
                : 'cloudboardAiSlideDesigns',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
          )
          .call<Map<String, dynamic>>(input);
      requireOwner(ownerId);
      return response.data;
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      throw AiSlidesFailure(
        error.code == 'not-found' && input['action'] == 'generate'
            ? '디자인 생성 기능을 준비 중이에요. 수업 메모와 템플릿은 이용할 수 있어요.'
            : error.message ?? '디자인을 추천받지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
        code: error.code,
        reason: details is Map ? details['reason'] as String? : null,
      );
    }
  }

  Future<String> prepareReference(Uint8List bytes) async {
    try {
      return base64Encode(await compute(prepareAiTimerImage, bytes));
    } on AiTimerFailure catch (error) {
      throw AiSlidesFailure(error.message);
    }
  }

  Stream<List<(String, AiSlideDesignModel)>> watchTemplates(
    String ownerId,
    String? storeId,
  ) {
    requireOwner(ownerId);
    return firestore.collection('users/$ownerId/aiSlideDesigns').snapshots().map(
      (snapshot) {
        requireOwner(ownerId);
        return snapshot.docs
            // Owner-scoped styles created before onboarding remain available
            // after this owner links a center. Other explicit centers stay out.
            .where(
              (doc) =>
                  doc.data()['storeId'] == null ||
                  doc.data()['storeId'] == storeId,
            )
            .map((doc) => (doc.id, AiSlideDesignModel.fromJson(doc.data())))
            .toList();
      },
    );
  }

  Future<void> saveTemplate(
    String ownerId,
    String id,
    AiSlideDesignModel model,
  ) async {
    requireOwner(ownerId);
    await firestore
        .doc('users/$ownerId/aiSlideDesigns/$id')
        .set({...model.toJson(), 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 15));
    requireOwner(ownerId);
  }

  String _key(String ownerId, String? storeId) =>
      'cloudboard.ai-slide-design.v1.${Uri.encodeComponent(ownerId)}.${Uri.encodeComponent(storeId ?? 'legacy')}';
  Future<(String, AiSlideDesignModel)?> loadSelected(
    String ownerId,
    String? storeId,
  ) async {
    requireOwner(ownerId);
    await _pending;
    var raw = await preferences.getString(_key(ownerId, storeId));
    requireOwner(ownerId);
    if (raw == null && storeId != null) {
      // Only the same owner's pre-onboarding selection is a valid fallback.
      // A center-specific selection always takes precedence when it exists.
      raw = await preferences.getString(_key(ownerId, null));
      requireOwner(ownerId);
    }
    if (raw == null) return null;
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final model = AiSlideDesignModel.fromJson(data);
    if (model.storeId != null && model.storeId != storeId) return null;
    return (data['id'] as String, model);
  }

  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    String id,
    AiSlideDesignModel model,
  ) {
    requireOwner(ownerId);
    // Capture the full account/center key before queuing. A late completion can
    // never write the next signed-in account's selection.
    final key = _key(ownerId, storeId);
    final raw = jsonEncode({...model.toJson(), 'id': id});
    final next = _pending.then((_) => preferences.setString(key, raw));
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
