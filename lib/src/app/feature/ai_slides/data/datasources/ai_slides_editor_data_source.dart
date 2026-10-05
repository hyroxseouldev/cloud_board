import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_editor_model.dart';

/// One queue survives account switches; every queued write keeps its original key.
class AiSlidesDraftLocalDataSource {
  AiSlidesDraftLocalDataSource({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  Future<void> _pending = Future.value();

  String _key(String ownerId) {
    if (ownerId.isEmpty) throw const AiSlidesFailure('로그인 후 이용해 주세요.');
    return 'cloudboard.ai-slide-draft.v1.${Uri.encodeComponent(ownerId)}';
  }

  Future<AiSlidesSavedDraftModel?> read(String ownerId) async {
    final key = _key(ownerId);
    await _pending;
    final raw = await _preferences.getString(key);
    if (raw == null) return null;
    return AiSlidesSavedDraftModel.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> write(String ownerId, AiSlidesSavedDraftModel? draft) {
    final key = _key(ownerId);
    final raw = draft == null ? null : jsonEncode(draft.toJson());
    final next = _pending.then((_) async {
      if (raw == null) {
        await _preferences.remove(key);
      } else {
        await _preferences.setString(key, raw);
      }
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}

class AiSlidesThemeFirestoreDataSource {
  AiSlidesThemeFirestoreDataSource(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  void _requireOwner(String ownerId) {
    final user = _auth.currentUser;
    if (ownerId.isEmpty ||
        user == null ||
        user.isAnonymous ||
        user.uid != ownerId) {
      throw const AiSlidesFailure('계정이 변경되었습니다. 다시 열어 주세요.');
    }
  }

  DocumentReference<Map<String, dynamic>> _document(String ownerId) =>
      _firestore.doc('users/$ownerId/settings/aiSlidesTheme');

  Stream<AiSlideThemeModel?> watch(String ownerId) {
    _requireOwner(ownerId);
    return _document(ownerId)
        .snapshots(includeMetadataChanges: true)
        // A missing local cache is not proof that the account has no preset.
        // Existing cached presets remain usable offline; otherwise await the
        // first server confirmation (bounded by the editor's loading timeout).
        .where((snapshot) => snapshot.exists || !snapshot.metadata.isFromCache)
        .map((snapshot) {
          _requireOwner(ownerId);
          final data = snapshot.data();
          return data == null ? null : AiSlideThemeModel.fromJson(data);
        });
  }

  Future<void> save(String ownerId, AiSlideThemeModel theme) async {
    _requireOwner(ownerId);
    await _document(ownerId)
        .set({...theme.toJson(), 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 15));
    _requireOwner(ownerId);
  }
}
