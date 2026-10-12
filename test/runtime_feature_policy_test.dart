import 'dart:convert';

import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy.dart';
import 'package:cloud_board/src/app/core/runtime_policy/runtime_feature_policy_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> policy(
  int revision, {
  bool enabled = false,
  int percent = 100,
}) => {
  'schemaVersion': 1,
  'revision': revision,
  'features': {
    'splitPlayback': {'enabled': enabled, 'rolloutPercent': percent},
  },
};

void main() {
  test('missing policy keeps every shipped capability available', () async {
    final service = RuntimeFeaturePolicyService(
      fetch: () async => null,
      readCache: () async => null,
      writeCache: (_) async {},
    );
    for (final feature in RuntimeFeature.values) {
      expect(await service.allows(feature, ownerId: 'account'), isTrue);
    }
  });

  test(
    'malformed and offline reads preserve last good policy across restart',
    () async {
      String? cache;
      Map<String, dynamic>? remote = policy(4);
      var offline = false;
      RuntimeFeaturePolicyService reopen() => RuntimeFeaturePolicyService(
        fetch: () async {
          if (offline) throw StateError('network');
          return remote;
        },
        readCache: () async => cache,
        writeCache: (value) async {
          cache = value;
        },
      );
      final service = reopen();
      expect(
        await service.allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isFalse,
      );
      expect(
        await service.allows(RuntimeFeature.aiSlideGeneration, ownerId: 'u'),
        isTrue,
      );
      remote = policy(5, enabled: true, percent: 101);
      expect(
        await service.allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isFalse,
      );
      expect(jsonDecode(cache!)['revision'], 4);
      offline = true;
      expect(
        await reopen().allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isFalse,
      );
      offline = false;
      remote = policy(3, enabled: true);
      expect(
        await service.allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isFalse,
      );
      remote = policy(6, enabled: true);
      expect(
        await service.allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isTrue,
      );
    },
  );

  test(
    'percentage cohorts are stable and enabling is separate from rollout',
    () {
      final half = RuntimeFeaturePolicy.fromJson(
        policy(1, enabled: true, percent: 50),
      );
      final restored = RuntimeFeaturePolicy.fromJson(half.toJson());
      final users = List.generate(1000, (i) => 'account-$i');
      final eligible = users
          .where(
            (uid) => half.allows(RuntimeFeature.splitPlayback, ownerId: uid),
          )
          .toList();
      expect(eligible.length, inInclusiveRange(450, 550));
      for (final uid in users) {
        expect(
          half.allows(RuntimeFeature.splitPlayback, ownerId: uid),
          restored.allows(RuntimeFeature.splitPlayback, ownerId: uid),
        );
      }
      expect(
        RuntimeFeaturePolicy.fromJson(policy(2, percent: 100))
            .allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
        isFalse,
      );
    },
  );

  test('disk failure does not discard valid in-memory stop switch', () async {
    final service = RuntimeFeaturePolicyService(
      fetch: () async => policy(2),
      readCache: () async => throw StateError('disk'),
      writeCache: (_) async => throw StateError('disk'),
    );
    expect(
      await service.allows(RuntimeFeature.splitPlayback, ownerId: 'u'),
      isFalse,
    );
  });
}
