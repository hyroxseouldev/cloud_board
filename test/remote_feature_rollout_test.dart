import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy.dart';
import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> policy(bool enabled, int revision) => {
  'schemaVersion': 1,
  'revision': revision,
  'features': {
    'splitPlayback': {'enabled': enabled, 'rolloutPercent': 100},
  },
};
RuntimeFeaturePolicyService service(
  Future<Map<String, dynamic>?> Function() fetch, {
  RuntimeFeaturePolicyService? additional,
}) => RuntimeFeaturePolicyService(
  fetch: fetch,
  readCache: () async => null,
  writeCache: (_) async {},
  additionalAllows: additional == null
      ? null
      : (feature, owner) => additional.allows(feature, ownerId: owner),
);

void main() {
  test(
    'rollout cannot enable a feature disabled by compatibility policy',
    () async {
      final rollout = service(() async => policy(true, 1));
      final control = service(
        () async => policy(false, 3),
        additional: rollout,
      );
      expect(
        await control.allows(RuntimeFeature.splitPlayback, ownerId: 'center'),
        false,
      );
    },
  );
  test(
    'rollout can limit an enabled feature while basic operations have no gate',
    () async {
      final rollout = service(() async => policy(false, 1));
      final control = service(() async => policy(true, 1), additional: rollout);
      expect(
        await control.allows(RuntimeFeature.splitPlayback, ownerId: 'center'),
        false,
      );
      expect(
        await control.allows(
          RuntimeFeature.aiSlideGeneration,
          ownerId: 'center',
        ),
        true,
      );
    },
  );
  test(
    'rollout outage retains validated policy and is not a global lockout',
    () async {
      var online = true;
      final rollout = service(() async {
        if (!online) throw StateError('offline');
        return policy(false, 1);
      });
      final control = service(() async => null, additional: rollout);
      expect(
        await control.allows(RuntimeFeature.splitPlayback, ownerId: 'center'),
        false,
      );
      online = false;
      expect(
        await control.allows(RuntimeFeature.splitPlayback, ownerId: 'center'),
        false,
      );
      expect(
        await control.allows(
          RuntimeFeature.aiSlideGeneration,
          ownerId: 'center',
        ),
        true,
      );
    },
  );
  test('a selected session decision stays unchanged; next start reads new revision', () async {
    var next = policy(true, 1);
    final rollout = service(() async => next);
    final control = service(() async => null, additional: rollout);
    final sessionUsesSplit = await control.allows(
      RuntimeFeature.splitPlayback,
      ownerId: 'center',
    );
    next = policy(false, 2);
    expect(sessionUsesSplit, true);
    expect(
      await control.allows(RuntimeFeature.splitPlayback, ownerId: 'center'),
      false,
    );
    expect(sessionUsesSplit, true);
  });
}
