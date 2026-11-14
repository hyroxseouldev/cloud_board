import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'image_usage_test.dart' show admissionFixture;

final workout = Workout.empty(
  'w',
  const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
);
PlaybackSessionModel model(List<String> targets) =>
    PlaybackSessionModel.fromWorkout(
      id: 'candidate',
      ownerId: 'owner',
      zoneId: 'main',
      targetDeviceIds: targets,
      workout: workout,
      stepIndex: 0,
      durationMs: 1000,
      deviceId: 'controller',
    );
Map<String, dynamic> admission({
  bool capable = true,
  String status = 'preparing',
}) => {
  ...admissionFixture(status: status),
  'targetDeviceIds': ['a', 'b'],
  'clientFingerprint': preparationFingerprint(workout, ['a', 'b']),
  if (capable) 'supportsTargetSubset': true,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final targets in [
    <String>['a'],
    <String>['b', 'a'],
  ]) {
    test(
      'supported commit sends exact selected IDs with original cohort binding $targets',
      () async {
        final calls = <Map<String, dynamic>>[];
        final source = client((_, input) async {
          calls.add(input);
          return {
            ...admission(status: 'active'),
            'session': {'targetDeviceIds': targets},
          };
        });
        final result = await commitPreparedPlayback(
          source,
          ClassAdmission.fromJson(admission()),
          model(targets),
          scheduled: false,
        );
        expect(result['targetDeviceIds'], targets);
        expect(calls.single['schemaVersion'], 1);
        expect(calls.single['action'], 'commitSelected');
        expect(
          calls.single['selectedTargetDeviceIds'],
          targets.toList()..sort(),
        );
        expect(calls.single['manifestHash'], admission()['manifestHash']);
        expect(calls.single['requestId'], 'commit_admission-one');
        expect(calls.single['start'], containsPair('durationMs', 1000));
      },
    );
  }
  for (final ids in [
    <String>[],
    ['outside'],
    ['a', 'a'],
  ]) {
    test(
      'empty/foreign/duplicate selected set fails before commit $ids',
      () async {
        var calls = 0;
        await expectLater(
          commitPreparedPlayback(
            client((_, _) async {
              calls++;
              return {};
            }),
            ClassAdmission.fromJson(admission()),
            model(ids),
            scheduled: false,
          ),
          throwsA(isA<ImageUsageFailure>()),
        );
        expect(calls, 0);
      },
    );
  }
  test('old server cannot silently publish entire cohort for subset', () async {
    final calls = <Map<String, dynamic>>[];
    final source = client((_, input) async {
      calls.add(input);
      return {
        ...admission(capable: false, status: 'active'),
        'session': {
          'targetDeviceIds': ['a', 'b'],
        },
      };
    });
    final old = ClassAdmission.fromJson(admission(capable: false));
    expect(old.supportsTargetSubset, isFalse);
    await expectLater(
      commitPreparedPlayback(source, old, model(['a']), scheduled: false),
      throwsA(isA<ImageUsageFailure>()),
    );
    expect(calls, isEmpty);
    await commitPreparedPlayback(
      source,
      old,
      model(['a', 'b']),
      scheduled: false,
    );
    expect(calls.single['action'], 'commit');
    expect(calls.single.containsKey('selectedTargetDeviceIds'), isFalse);
  });
  test('new action refusal never falls back to legacy commit', () async {
    final actions = <String>[];
    final source = client((_, input) async {
      actions.add(input['action'] as String);
      throw const ImageUsageFailure('policy_or_client_upgrade_required');
    });
    await expectLater(
      commitPreparedPlayback(
        source,
        ClassAdmission.fromJson(admission()),
        model(['a']),
        scheduled: false,
      ),
      throwsA(isA<ImageUsageFailure>()),
    );
    expect(actions, ['commitSelected']);
  });
  test(
    'revision/settings change and owner switch fail before publication',
    () async {
      var calls = 0;
      final source = client((_, _) async {
        calls++;
        return {};
      }, actor: () => 'other');
      await expectLater(
        commitPreparedPlayback(
          source,
          ClassAdmission.fromJson(admission()),
          model(['a']),
          scheduled: false,
        ),
        throwsA(isA<ImageUsageFailure>()),
      );
      await expectLater(
        commitPreparedPlayback(
          source,
          ClassAdmission.fromJson({
            ...admission(),
            'clientFingerprint': 'different-revision',
          }),
          model(['a']),
          scheduled: false,
        ),
        throwsA(isA<ImageUsageFailure>()),
      );
      expect(calls, 0);
    },
  );
  for (final status in ['preparing', 'committing', 'active']) {
    test(
      'each supported start/recovery rebinds selection on server: $status',
      () async {
        final calls = <Map<String, dynamic>>[];
        final source = client((_, input) async {
          calls.add(input);
          throw const ImageUsageFailure('idempotency_conflict');
        });
        await expectLater(
          commitPreparedPlayback(
            source,
            ClassAdmission.fromJson(admission(status: status)),
            model(['b']),
            scheduled: false,
          ),
          throwsA(isA<ImageUsageFailure>()),
        );
        expect(calls.single['action'], 'commitSelected');
      },
    );
  }
  test(
    'unexpected returned target set is never accepted as selected session',
    () async {
      final source = client(
        (_, _) async => {
          ...admission(status: 'active'),
          'session': {
            'targetDeviceIds': ['a', 'b'],
          },
        },
      );
      await expectLater(
        commitPreparedPlayback(
          source,
          ClassAdmission.fromJson(admission()),
          model(['a']),
          scheduled: false,
        ),
        throwsA(isA<ImageUsageFailure>()),
      );
    },
  );
}

ImageUsageDataSource client(
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) call, {
  String? Function()? actor,
}) => ImageUsageDataSource(
  projectId: 'demo-precheck',
  actorId: 'owner',
  currentActorId: actor ?? () => 'owner',
  token: () async => '',
  call: call,
  readGate: () async => {'mode': 'enrolled'},
  send: (_) async => throw StateError('no media'),
  preferences: SharedPreferences.getInstance,
);
