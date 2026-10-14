import 'dart:async';

import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

abstract interface class SupportDataSource {
  Future<String> upload(
    String accountId,
    String requestId,
    SupportAttachment attachment,
  );
  Future<Map<String, dynamic>> submit(
    String accountId,
    Map<String, Object?> input,
  );
}

class FirebaseSupportDataSource implements SupportDataSource {
  void _checkAccount(String accountId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || user.uid != accountId) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }
  }

  @override
  Future<String> upload(
    String accountId,
    String requestId,
    SupportAttachment attachment,
  ) async {
    _checkAccount(accountId);
    final digest = sha256.convert(attachment.bytes).toString();
    final path = 'users/$accountId/support/$requestId/${attachment.fileId}';
    final permit =
        await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable(
              'cloudboardPrepareSupportAttachment',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            )
            .call<Map<String, dynamic>>({
              'accountId': accountId,
              'requestId': requestId,
              'fileId': attachment.fileId,
              'contentType': attachment.contentType,
              'sizeBytes': attachment.bytes.length,
              'sha256': digest,
            });
    _checkAccount(accountId);
    if (permit.data['path'] != path) {
      throw const FormatException('첨부 업로드 경로를 확인하지 못했습니다. 다시 시도해 주세요.');
    }
    final reference = FirebaseStorage.instance.ref(path);
    // A lost upload response must not require overwriting an immutable object.
    try {
      final existing = await reference.getMetadata().timeout(
        const Duration(seconds: 8),
      );
      if (existing.size == attachment.bytes.length &&
          existing.contentType == attachment.contentType &&
          existing.customMetadata?['sha256'] == digest) {
        return path;
      }
      throw StateError('첨부 파일을 확인하지 못했습니다. 다시 선택해 주세요.');
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
    _checkAccount(accountId);
    final task = reference.putData(
      attachment.bytes,
      SettableMetadata(
        contentType: attachment.contentType,
        customMetadata: {'sha256': digest},
      ),
    );
    await task.timeout(
      const Duration(seconds: 25),
      onTimeout: () async {
        await task.cancel();
        throw TimeoutException('Support screenshot upload timed out');
      },
    );
    _checkAccount(accountId);
    return path;
  }

  @override
  Future<Map<String, dynamic>> submit(
    String accountId,
    Map<String, Object?> input,
  ) async {
    _checkAccount(accountId);
    final result =
        await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable(
              'cloudboardSubmitSupportTicket',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 25),
              ),
            )
            .call<Map<String, dynamic>>({...input, 'accountId': accountId});
    _checkAccount(accountId);
    return result.data;
  }
}
