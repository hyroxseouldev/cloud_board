import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/image_usage/presentation/managed_image_provider.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

Map<String, dynamic> period() => {
  'key': '2026-11-14',
  'resetsAtMs': 1794668400000,
  'limitBytes': 50000000,
  'grantedBytes': 0,
  'usedBytes': 1,
  'reservedBytes': 2,
  'unknownBytes': 3,
  'remainingBytes': 49999994,
  'protectedOverageBytes': 0,
};
Map<String, dynamic> usageFixture() => {
  'schemaVersion': 1,
  'policyRevision': imageUsagePolicyRevision,
  'mode': 'enrolled',
  'policyPlan': 'free',
  'measuredAtMs': 1,
  'revision': 1,
  'storage': {
    'limitBytes': 100000000,
    'usedBytes': 1,
    'reservedBytes': 2,
    'unknownBytes': 3,
    'complete': true,
  },
  'uploadDay': period(),
  'downloadDay': period(),
  'downloadMonth': {...period(), 'key': '2026-11'},
  'attribution': 'gateway',
  'nextEligibleAtMs': null,
};
const source =
    'https://asia-northeast3-demo-usage.cloudfunctions.net/cloudboardMedia?assetId=asset-one&v=123';
Map<String, dynamic> asset() => {
  'assetId': 'asset-one',
  'source': source,
  'generation': '123',
  'sizeBytes': 4,
  'contentType': 'image/png',
  'sha256': 'a' * 64,
};
Map<String, dynamic> admissionFixture({String status = 'preparing'}) => {
  'schemaVersion': 1,
  'admissionId': 'admission-one',
  'sessionId': 'session-one',
  'epoch': 1,
  'manifestHash': 'a' * 64,
  'clientFingerprint': 'fingerprint',
  'policyRevision': imageUsagePolicyRevision,
  'status': status,
  'prepareExpiresAtMs': 90000,
  'targetDeviceIds': ['tv'],
  'reservedDownloadBytes': 8,
  'usage': usageFixture(),
  'session': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  ImageUsageDataSource client({
    required Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
    call,
    Future<http.Response> Function(http.Request)? send,
    Future<Object?> Function()? gate,
    String? Function()? actor,
  }) => ImageUsageDataSource(
    projectId: 'demo-usage',
    actorId: 'owner',
    currentActorId: actor ?? () => 'owner',
    token: () async => 'private-token',
    call: call,
    readGate: gate ?? () async => {'mode': 'enrolled'},
    send: send ?? (_) async => throw StateError('body must not be sent'),
    preferences: SharedPreferences.getInstance,
  );
  test(
    'decimal limits, complete DTO and quota/service copy remain distinct',
    () {
      expect(imageUsageLimits['free']!.storage, 100000000);
      expect(imageUsageLimits['premium']!.downloadMonth, 20000000000);
      expect(imageUsageWorkoutLimitBytes, 100000000);
      expect(decimalImageBytes(100000000), '100MB');
      expect(decimalImageBytes(1000000000), '1GB');
      final value = ImageUsage.fromJson(usageFixture());
      expect(value.downloadDay!.unknownBytes, 3);
      expect(value.nextEligibleAtMs, isNull);
      expect(const ImageUsageFailure('storage_limit').quotaDenied, isTrue);
      expect(
        const ImageUsageFailure('service_unavailable').quotaDenied,
        isFalse,
      );
      expect(
        const ImageUsageFailure('daily_upload_limit').message,
        contains('선택한 파일과 초안은 유지'),
      );
      expect(
        const ImageUsageFailure('daily_transfer_limit').message,
        contains('진행 중인 수업은 계속'),
      );
      expect(
        const ImageUsageFailure('service_unavailable').message,
        startsWith('사용량 확인 실패'),
      );
      expect(() => usageInt(1.5), throwsFormatException);
      expect(
        () => ImageUsage.fromJson({...usageFixture(), 'policyPlan': 'plus'}),
        throwsFormatException,
      );
    },
  );
  test('enrolled quota denies reservation before any upload body and retains draft', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final original = List<int>.from(bytes);
    var sent = 0;
    final source = client(
      call: (endpoint, input) async {
        expect(endpoint, 'cloudboardImageUpload');
        expect(input['action'], 'reserve');
        throw const ImageUsageFailure('daily_upload_limit');
      },
      send: (_) async {
        sent++;
        return http.Response('', 201);
      },
    );
    await expectLater(
      source.upload(
        bytes: bytes,
        contentType: 'image/png',
        purpose: 'workout',
        workoutId: 'w',
      ),
      throwsA(isA<ImageUsageFailure>()),
    );
    expect(sent, 0);
    expect(bytes, original);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().single, startsWith('image-usage.upload.owner'));
  });
  test(
    'lost upload response re-queries the same permit, never duplicates body',
    () async {
      final actions = <String>[];
      var sent = 0;
      final source = client(
        call: (_, input) async {
          actions.add(input['action'] as String);
          if (input['action'] == 'reserve') {
            return {
              'schemaVersion': 1,
              'uploadId': 'upload-one',
              'expiresAtMs': 90000,
              'status': 'reserved',
              'uploadUrl': 'https://asia-northeast3-demo-usage.cloudfunctions.net/cloudboardImageUploadBody',
              'asset': null,
            };
          }
          expect(input['uploadId'], 'upload-one');
          return {
            'schemaVersion': 1,
            'uploadId': 'upload-one',
            'expiresAtMs': 90000,
            'status': 'stored',
            'uploadUrl': null,
            'asset': asset(),
          };
        },
        send: (request) async {
          sent++;
          expect(request.headers['authorization'], 'Bearer private-token');
          expect(request.headers['x-cloudboard-upload-id'], 'upload-one');
          throw StateError('lost response');
        },
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await expectLater(
        source.upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: 'profile',
        ),
        throwsA(isA<ImageUsageFailure>()),
      );
      expect(
        await source.upload(
          bytes: bytes,
          contentType: 'image/png',
          purpose: 'profile',
        ),
        sourceIsManaged,
      );
      expect(actions, ['reserve', 'get']);
      expect(sent, 1);
    },
  );
  test('uncertain prepare retries the durable requestId; fingerprint conflicts cannot replace it', () async {
    final ids = <String>[];
    var calls = 0;
    final source = client(
      call: (_, input) async {
        if (input['action'] == 'get') return admissionFixture();
        ids.add(input['requestId'] as String);
        if (calls++ == 0) {
          throw StateError('lost response');
        }
        return admissionFixture();
      },
    );
    Future<ClassAdmission> prepare() => source.prepare(
      workout: {'id': 'w'},
      targets: ['tv'],
      controllerDeviceId: 'controller',
      clientFingerprint: 'fingerprint',
    );
    await expectLater(prepare(), throwsA(isA<ImageUsageFailure>()));
    await prepare();
    expect(ids[0], ids[1]);
    expect((await source.pendingAdmission()), isNotNull);
  });
  test('managed bytes require bound lease and bearer headers before HTTP; invalid host never gets token', () async {
    final order = <String>[];
    final sourceClient = client(
      gate: () async => {
        'mode': 'enrolled',
        'phase': 'active',
        'admissionId': 'admission-one',
        'sessionId': 'session-one',
      },
      call: (endpoint, input) async {
        order.add('lease');
        expect(endpoint, 'cloudboardMediaLease');
        expect(input['purpose'], 'playback');
        expect(input['sessionId'], 'session-one');
        return {
          'schemaVersion': 1,
          'leaseId': 'lease-one',
          'expiresAtMs': 90000,
          'assets': [asset()],
          'sessionId': 'session-one',
          'epoch': 1,
        };
      },
      send: (request) async {
        order.add('body');
        expect(request.headers['authorization'], 'Bearer private-token');
        expect(request.headers['x-cloudboard-media-lease'], 'lease-one');
        return http.Response.bytes([1, 2, 3, 4], 200);
      },
    );
    expect(await sourceClient.media(source), [1, 2, 3, 4]);
    expect(order, ['lease', 'body']);
    await expectLater(
      sourceClient.media(source.replaceFirst('demo-usage', 'foreign-project')),
      throwsA(isA<ImageUsageFailure>()),
    );
    expect(order.length, 2);
    sourceClient.dispose();
    await expectLater(
      sourceClient.media(source),
      throwsA(isA<ImageUsageFailure>()),
    );
  });
  testWidgets(
    'managed renderer decodes authenticated HTTP bytes with MemoryImage on native/web',
    (tester) async {
      var loaded = 0;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=',
      );
      final provider = ManagedImageProvider(
        source,
        load: (_) async {
          loaded++;
          return png;
        },
      );
      await tester.pumpWidget(MaterialApp(home: Image(image: provider)));
      await tester.pumpAndSettle();
      expect(loaded, 1);
      expect(tester.takeException(), isNull);
      expect(
        workoutImageProvider(source, (width: null, height: null)),
        isA<ManagedImageProvider>(),
      );
    },
  );
}

final sourceIsManaged = equals(source);
