import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/repositories/device_pairing_repository.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_preparation_actions.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/preparation_shadcn.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';

import 'image_usage_test.dart' show admissionFixture;
import 'preparation_subset_commit_test.dart' show client;
import 'support/preparation_fixture.dart';
import 'workout_preflight_dialog_test.dart'
    show mount, workout, enabled, startButton;

void main() {
  testWidgets(
    'enrolled all incompatible never prepares empty broadcast targets',
    (tester) async {
      final fixture = PreparationFixture(count: 1);
      final source = _EnrolledSource(fixture);
      fixture.source = source;
      await mount(tester, fixture);
      expect(source.checks, 1);
      expect(source.prepared, isEmpty);
      expect(fixture.repository.requests, 0);
      expect(enabled(tester), isTrue);
      expect(find.text('TV 없이 수업을 시작할 수 있어요.'), findsOneWidget);
      final tile = tester.widget<PreparationDeviceTile>(
        find.byKey(const ValueKey('preparation-device-tv-0')),
      );
      expect(tile.selected, isFalse);
      expect(tile.onChanged, isNull);
      await tester.tap(find.text('전체 해제'));
      await tester.pumpAndSettle();
      expect(source.prepared, isEmpty);
      expect(enabled(tester), isTrue);
    },
  );
  for (final registered in [false, true]) {
    testWidgets(
      'enrolled zero selection cancels only own admission: registered=$registered',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = PreparationFixture(count: 0);
        final source = _EnrolledSource(fixture);
        fixture.source = source;
        if (registered) {
          fixture.devices.add(
            decodeDisplayDevice('ready', {
              'id': 'ready',
              'name': 'Ready TV',
              'paired': true,
              'online': true,
              'lastSeenAtMs': fixture.now,
              'playbackProtocol': 5,
              'preparationProtocol': 2,
              'imageUsageProtocol': 1,
            }),
          );
        }
        WorkoutPreflightSelection? result;
        await mount(tester, fixture, onResult: (value) => result = value);
        if (registered) {
          await tester.tap(find.text('전체 해제'));
          await tester.pumpAndSettle();
        }
        expect(enabled(tester), isTrue);
        expect(source.cancels, isEmpty);
        await tester.tap(startButton);
        await tester.pumpAndSettle();
        expect(result?.localOnly, isTrue);
        expect(result?.targetDeviceIds, isEmpty);
        expect(result?.preparation, isNull);
        expect(
          source.prepared,
          registered
              ? [
                  ['ready'],
                ]
              : isEmpty,
        );
        expect(
          source.cancels,
          registered ? [source.response['admissionId']] : isEmpty,
        );
        expect(fixture.repository.cancelled, isEmpty);
        expect(fixture.repository.requests, 0);
        expect(source.checks, 2);
      },
    );
  }

  testWidgets(
    'enrolled mixed protocols prepare once and start compatible TV only',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fixture = PreparationFixture(count: 0);
      final source = _EnrolledSource(fixture);
      fixture.source = source;
      fixture.devices.addAll([
        for (final compatible in [true, false])
          decodeDisplayDevice(compatible ? 'ready' : 'old', {
            'id': compatible ? 'ready' : 'old',
            'name': compatible ? 'Ready TV' : 'Old TV',
            'paired': true,
            'online': true,
            'lastSeenAtMs': fixture.now,
            'playbackProtocol': 5,
            'preparationProtocol': compatible ? 2 : 1,
            'imageUsageProtocol': compatible ? 1 : 0,
          }),
      ]);
      WorkoutPreflightSelection? selection;
      await mount(tester, fixture, onResult: (value) => selection = value);
      expect(fixture.devices.first.imageUsageProtocol, 1);
      expect(source.checks, 1);
      expect(source.prepared, [
        ['ready'],
      ]);
      expect(
        fixture.repository.requests,
        0,
      ); // Server-owned enrolled publication.
      expect(enabled(tester), isTrue);
      final old = find.byKey(const ValueKey('preparation-device-old'));
      expect(tester.widget<PreparationDeviceTile>(old).onChanged, isNull);
      expect(tester.widget<PreparationDeviceTile>(old).selected, isFalse);
      expect(find.text('TV 앱 업데이트 필요 · 준비 대상에서 제외됨'), findsOneWidget);
      await tester.tap(old);
      await tester.pumpAndSettle();
      expect(enabled(tester), isTrue);
      for (var i = 0; i < 2; i++) {
        final ready = find.byKey(const ValueKey('preparation-device-ready'));
        await tester.tap(ready);
        await tester.pumpAndSettle();
        expect(enabled(tester), isTrue);
        await tester.tap(ready);
        await tester.pumpAndSettle();
        await tester.tap(find.text('전체 해제'));
        await tester.pumpAndSettle();
        expect(enabled(tester), isTrue);
        await tester.tap(find.text('전체 선택'));
        await tester.pumpAndSettle();
        expect(enabled(tester), isTrue);
      }
      expect(source.checks, 1);
      expect(source.prepared, [
        ['ready'],
      ]);
      expect(fixture.deviceSubscriptions, 1);
      await tester.tap(startButton);
      await tester.pumpAndSettle();
      expect(selection!.targetDeviceIds, ['ready']);
      expect(selection!.preparation!.preparedTargetDeviceIds, ['ready']);
      await DisplayPreparationActions(
        fixture.repository,
        _Devices(fixture.devices),
      ).verifyStart(
        workout,
        selection!.targetDeviceIds,
        selection!.preparation,
        nowMs: fixture.now,
      );
      final committed = <Map<String, dynamic>>[];
      final session = await commitPreparedPlayback(
        client((_, input) async {
          committed.add(input);
          return {
            ...source.response,
            'status': 'active',
            'session': {'targetDeviceIds': input['selectedTargetDeviceIds']},
          };
        }),
        ClassAdmission.fromJson(source.response),
        PlaybackSessionModel.fromWorkout(
          id: 'candidate',
          ownerId: 'owner',
          zoneId: 'main',
          targetDeviceIds: selection!.targetDeviceIds,
          workout: workout,
          stepIndex: 0,
          durationMs: 1000,
          deviceId: 'controller',
        ),
        scheduled: false,
      );
      expect(committed.single['action'], 'commitSelected');
      expect(committed.single['selectedTargetDeviceIds'], ['ready']);
      expect(session['targetDeviceIds'], ['ready']);
      expect(source.prepared.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _EnrolledSource extends FixtureUsageSource {
  _EnrolledSource(this.fixture);
  final PreparationFixture fixture;
  final prepared = <List<String>>[];
  late Map<String, dynamic> response;
  final cancels = <String>[];
  @override
  Future<ClassAdmission> cancelAdmission(String id) async {
    cancels.add(id);
    fixture.repository.value = null;
    return ClassAdmission.fromJson({...response, 'status': 'cancelled'});
  }

  @override
  Future<bool> enrolled() async {
    checks++;
    return true;
  }

  @override
  Future<ClassAdmission> prepare({
    required Map<String, dynamic> workout,
    required List<String> targets,
    required String controllerDeviceId,
    required String clientFingerprint,
  }) async {
    prepared.add(List.of(targets));
    // Simulate the server publication without a client preparation write.
    final candidate = prepareDisplayCandidate(
      // Use the exact fixture workout/settings passed through the real page.
      fixtureWorkout,
      targets,
      sessionId: 'enrolled-preparation',
      revision: 1,
      nowMs: fixture.now,
    );
    fixture.repository.value = candidate;
    response = {
      ...admissionFixture(),
      'sessionId': candidate.sessionId,
      'manifestHash': candidate.manifestHash,
      'prepareExpiresAtMs': candidate.expiresAtMs,
      'clientFingerprint': clientFingerprint,
      'targetDeviceIds': targets,
      'supportsTargetSubset': true,
    };
    return ClassAdmission.fromJson(response);
  }
}

final fixtureWorkout = workout;

class _Devices implements DevicePairingRepository {
  _Devices(this.devices);
  final List<DisplayDevice> devices;
  @override
  Stream<List<DisplayDevice>> watchDevices() => Stream.value(devices);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
