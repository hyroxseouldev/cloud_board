import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

class WorkoutPreferencesDataSource {
  WorkoutPreferencesDataSource(this.firestore, this.storage, this.auth);
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  void checkOwner(String ownerId) {
    if (ownerId.isEmpty ||
        auth.currentUser?.uid != ownerId ||
        auth.currentUser!.isAnonymous) {
      throw StateError('로그인 계정이 변경됐습니다. 다시 열어 주세요.');
    }
  }

  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) async {
    checkOwner(ownerId);
    final doc = await firestore
        .collection('users')
        .doc(ownerId)
        .get(GetOptions(source: fresh ? Source.server : Source.serverAndCache))
        .timeout(const Duration(seconds: 8));
    checkOwner(ownerId);
    final data = doc.data()?['workoutSettings'];
    return data is Map
        ? WorkoutPreferences.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  Future<void> save(String ownerId, WorkoutPreferences value) async {
    checkOwner(ownerId);
    var source = value.countdown.imageSource;
    if (source.isNotEmpty &&
        !source.startsWith('https://') &&
        !source.startsWith('http://')) {
      final image = WorkoutImageSource.decode(source);
      if (!WorkoutImageSource.supportedContentTypes.contains(
        image.contentType,
      )) {
        throw const FormatException('지원하지 않는 이미지 형식입니다.');
      }
      final file = storage.ref(
        'users/$ownerId/brand/workout-settings/${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      source = await file.getDownloadURL();
    }
    checkOwner(ownerId);
    final normalized = value.copyWith(
      countdown: value.countdown.copyWith(imageSource: source),
    );
    // Merge only this preference field. Never overwrite entitlement/profile data.
    await firestore.collection('users').doc(ownerId).set({
      'uid': ownerId,
      'workoutSettings': normalized.toJson(),
    }, SetOptions(merge: true));
    checkOwner(ownerId);
  }
}
