import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/observability/preparation_diagnostics.dart';
import 'package:cloud_board/src/app/core/services/realtime_server_reader.dart';
import 'package:http/http.dart' as http;

/// Reads only the current ephemeral request ID. No class state is written.
/// Authenticated URLs, tokens and response contents never enter diagnostics.
Future<Map<String, Object>> probePreparationRequest({
  required String requestId,
  required String ownerId,
  required String databaseUrl,
  required String projectId,
  required bool Function() isCurrentAccount,
  required Future<String?> Function() readToken,
  http.Client Function() clientFactory = http.Client.new,
}) async {
  var stage = 'auth';
  http.Client? client;
  try {
    if (!isCurrentAccount()) {
      throw const PreparationProbeFailure('cancelled', {});
    }
    final token = await readToken().timeout(const Duration(seconds: 2));
    if (!isCurrentAccount()) {
      throw const PreparationProbeFailure('cancelled', {});
    }
    if (token == null) {
      throw const PreparationProbeFailure('unauthenticated', {
        'probeStage': 'auth',
      });
    }
    stage = 'http';
    client = clientFactory();
    final response = await client
        .get(
          realtimeRestUri(
            databaseUrl,
            projectId,
            'users/$ownerId/displayPreparation/request/sessionId',
            token,
          ),
        )
        .timeout(const Duration(seconds: 3));
    if (!isCurrentAccount()) {
      throw const PreparationProbeFailure('cancelled', {});
    }
    final trace = <String, Object>{
      'probeStage': stage,
      'httpStatus': response.statusCode,
    };
    if (response.statusCode != 200) {
      throw PreparationProbeFailure(
        response.statusCode == 401 || response.statusCode == 403
            ? 'permission-denied'
            : 'unavailable',
        trace,
      );
    }
    final value = jsonDecode(response.body);
    return {
      ...trace,
      'requestMatch': value == null
          ? 'absent'
          : value == requestId
          ? 'same'
          : 'different',
    };
  } on PreparationProbeFailure {
    rethrow;
  } catch (error) {
    throw PreparationProbeFailure(
      error is http.ClientException
          ? 'unavailable'
          : operationFailureCode(error),
      {'probeStage': stage},
    );
  } finally {
    client?.close();
  }
}
