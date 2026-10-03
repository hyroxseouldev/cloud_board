import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';

import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
import 'package:cloud_board/src/app/feature/ai_timer/data/models/ai_timer_response_model.dart';

class AiTimerDataSource {
  Future<AiTimerResponseModel> call(Map<String, Object> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AiTimerFailure('로그인 후 이용해 주세요.', code: 'signed-out');
    }
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable(
                'cloudboardAiTimer',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 60),
                ),
              )
              .call<Map<String, dynamic>>(payload);
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw const AiTimerFailure(
          '계정이 변경되었습니다. 다시 열어 주세요.',
          code: 'account-changed',
        );
      }
      return AiTimerResponseModel.fromJson(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw AiTimerFailure(
        e.message ?? 'AI에 연결하지 못했습니다. 연결을 확인해 주세요.',
        code: e.code,
      );
    }
  }

  Future<String> imagePayload(String source) async {
    if (source.isEmpty) throw const AiTimerFailure('배경 이미지를 먼저 선택해 주세요.');
    Uint8List bytes;
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      final client = http.Client();
      try {
        final response = await client
            .send(http.Request('GET', uri))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 10 * 1024 * 1024) {
          throw const AiTimerFailure('이미지를 불러오지 못했습니다. 다시 선택해 주세요.');
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 15),
        )) {
          buffer.add(chunk);
          if (buffer.length > 10 * 1024 * 1024) {
            throw const AiTimerFailure('10MB 이하의 이미지를 선택해 주세요.');
          }
        }
        bytes = buffer.takeBytes();
      } finally {
        client.close();
      }
    } else {
      if (source.length > 14 * 1024 * 1024) {
        throw const AiTimerFailure('10MB 이하의 이미지를 선택해 주세요.');
      }
      bytes = WorkoutImageSource.decode(source).bytes;
    }
    return base64Encode(await compute(prepareAiTimerImage, bytes));
  }
}

/// Analysis gets its own bounded copy. The original slide image is unchanged.
Uint8List prepareAiTimerImage(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width * info.height > 20000000 ||
      bytes.length > 10 * 1024 * 1024) {
    throw const AiTimerFailure('이미지가 너무 크거나 읽을 수 없습니다. 작은 이미지로 다시 선택해 주세요.');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const AiTimerFailure('이미지 파일을 읽을 수 없습니다.');
  var image = img.bakeOrientation(decoded);
  if (image.width > 2048 || image.height > 2048) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 2048 : null,
      height: image.height > image.width ? 2048 : null,
      interpolation: img.Interpolation.average,
    );
  }
  final background = img.Image(width: image.width, height: image.height);
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(background, image);
  final encoded = Uint8List.fromList(img.encodeJpg(background, quality: 90));
  if (encoded.length > 4 * 1024 * 1024) {
    throw const AiTimerFailure('분석할 이미지가 너무 큽니다. 크기를 줄여 주세요.');
  }
  return encoded;
}
