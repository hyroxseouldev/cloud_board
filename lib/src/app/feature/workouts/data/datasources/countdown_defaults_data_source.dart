import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

class CountdownDefaultsDataSource {
  CountdownDefaultsDataSource(this.firestore, this.storage, this.auth);
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth auth;

  void _checkOwner(String ownerId) {
    if (ownerId.isEmpty ||
        auth.currentUser?.uid != ownerId ||
        auth.currentUser!.isAnonymous) {
      throw StateError('로그인 계정이 변경됐습니다. 다시 열어 주세요.');
    }
  }

  Future<CountdownPreferences> load(String ownerId) async {
    _checkOwner(ownerId);
    final doc = await firestore
        .collection('users')
        .doc(ownerId)
        .get()
        .timeout(const Duration(seconds: 8));
    _checkOwner(ownerId);
    final json = doc.data()?['countdownDefaults'];
    return json is Map
        ? CountdownPreferences.fromJson(Map<String, dynamic>.from(json))
        : const CountdownPreferences();
  }

  Future<void> save(String ownerId, CountdownPreferences value) async {
    _checkOwner(ownerId);
    var source = value.imageSource;
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
        'users/$ownerId/brand/countdown-defaults/${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      source = await file.getDownloadURL();
    }
    _checkOwner(ownerId);
    final json = value.copyWith(imageSource: source).toJson();
    // An acknowledged write is required before reporting success. Assets are
    // immutable because existing workouts may reference a prior default image.
    await firestore.collection('users').doc(ownerId).set({
      'uid': ownerId,
      'countdownDefaults': json,
    }, SetOptions(merge: true));
    _checkOwner(ownerId);
  }
}
