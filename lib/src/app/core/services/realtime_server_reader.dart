import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// A successful REST response is server evidence; unlike SDK get(), this never
/// falls back to persisted RTDB data. Authenticated URLs never escape errors.
class RealtimeServerReader {
  RealtimeServerReader(
    this.auth,
    this.databaseUrl, {
    this.clientFactory = http.Client.new,
  });
  final FirebaseAuth auth;
  final String databaseUrl;
  final http.Client Function() clientFactory;

  Future<Object?> read(String path) async {
    final user = auth.currentUser;
    if (user == null) {
      throw FirebaseException(plugin: 'database', code: 'unauthenticated');
    }
    final token = await user.getIdToken().timeout(const Duration(seconds: 6));
    if (token == null) {
      throw FirebaseException(plugin: 'database', code: 'unauthenticated');
    }
    final client = clientFactory();
    try {
      final response = await client
          .get(
            realtimeRestUri(
              databaseUrl,
              auth.app.options.projectId,
              path,
              token,
            ),
          )
          .timeout(const Duration(seconds: 6));
      if (auth.currentUser?.uid != user.uid) {
        throw StateError('로그인 계정이 변경되었습니다.');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw FirebaseException(plugin: 'database', code: 'permission-denied');
      }
      if (response.statusCode != 200) {
        throw StateError('서버 상태를 확인하지 못했습니다. 다시 시도해 주세요.');
      }
      return jsonDecode(response.body);
    } on http.ClientException {
      throw StateError('네트워크 연결을 확인하고 다시 시도해 주세요.');
    } finally {
      client.close();
    }
  }
}

// The existing debug preview connects SDK clients to this isolated demo. REST
// reads must use the same namespace; SDK emulator redirection does not affect HTTP.
Uri realtimeRestUri(
  String databaseUrl,
  String projectId,
  String path,
  String token,
) {
  if (kDebugMode && projectId == 'demo-cloudboard-studio') {
    return Uri.http('127.0.0.1:9000', '/$path.json', {
      'ns': '$projectId-default-rtdb',
      'auth': token,
    });
  }
  final base = Uri.parse(databaseUrl);
  return base.replace(
    path: '/$path.json',
    queryParameters: {...base.queryParameters, 'auth': token},
  );
}
