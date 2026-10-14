import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

const storageGrant = <String, dynamic>{
  'policyVersion': 'plan-entitlements-v2',
  'status': 'active',
  'plan': 'premium',
  'validUntilMs': 1000,
  'maxWorkouts': null,
  'workoutsUnlimited': true,
  'maxSavedSlides': null,
  'savedSlidesUnlimited': true,
};

StoreEntitlement access(Map<String, dynamic> data, {int now = 999}) =>
    StoreEntitlementModel.fromJson(data).toEntity('owner', true, now);

void main() {
  for (final version in ['plan-entitlements-v1', 'plan-entitlements-v2']) {
    for (final plan in [
      'free',
      'plus',
      'premium',
      'legacy',
      'cloudboard_pro',
    ]) {
      test(
        '$version $plan uses explicit storage values without AI/branding',
        () {
          final legacy = version == 'plan-entitlements-v1';
          final int? workouts = plan == 'free' && !legacy ? 7 : null;
          final int? slides = plan == 'free'
              ? 3
              : plan == 'plus'
              ? legacy
                    ? 3
                    : 30
              : null;
          final grant = access({
            ...storageGrant,
            'policyVersion': version,
            'plan': plan,
            'maxWorkouts': workouts,
            'workoutsUnlimited': workouts == null,
            'maxSavedSlides': slides,
            'savedSlidesUnlimited': slides == null,
          });
          expect(grant.limitFor('workouts').known, isTrue);
          expect(grant.limitFor('workouts').isUnlimited, workouts == null);
          expect(grant.limitFor('savedSlides').known, isTrue);
          expect(grant.limitFor('savedSlides').isUnlimited, slides == null);
          // The broader permissions have deliberately not become known.
          expect(grant.policyKnown, isFalse);
        },
      );
    }
  }

  test('finite Free 7/3 and Plus 30 storage caps remain exact', () {
    final free = access({
      ...storageGrant,
      'plan': 'free',
      'maxWorkouts': 7,
      'workoutsUnlimited': false,
      'maxSavedSlides': 3,
      'savedSlidesUnlimited': false,
    });
    expect(free.limitFor('workouts').known, isTrue);
    expect(free.limitFor('workouts').limit, 7);
    expect(free.limitFor('savedSlides').limit, 3);
    final plus = access({
      ...storageGrant,
      'plan': 'plus',
      'maxSavedSlides': 30,
      'savedSlidesUnlimited': false,
    });
    expect(plus.limitFor('workouts').isUnlimited, isTrue);
    expect(plus.limitFor('savedSlides').limit, 30);
  });

  for (final change in <Map<String, dynamic>>[
    {'policyVersion': ''},
    {'policyVersion': 'plan-entitlements-v3'},
    {'plan': 'unknown'},
    {'status': 'revoked'},
    {'status': 'expired'},
    {'status': 'pending_connection'},
    {'validUntilMs': 0},
  ]) {
    test('invalid access stays unknown: $change', () {
      final grant = access({...storageGrant, ...change});
      expect(grant.limitFor('workouts').known, isFalse);
      expect(grant.limitFor('savedSlides').known, isFalse);
    });
  }

  test('storage access expires at the exact server-clock boundary', () {
    expect(access(storageGrant).limitFor('workouts').isUnlimited, isTrue);
    expect(access(storageGrant, now: 1000).limitFor('workouts').known, isFalse);
  });

  for (final change in <Map<String, dynamic>>[
    {'maxWorkouts': null, 'workoutsUnlimited': false},
    {'maxWorkouts': 7, 'workoutsUnlimited': true},
    {'maxWorkouts': -1, 'workoutsUnlimited': false},
    {'maxWorkouts': 7.5, 'workoutsUnlimited': false},
    {'maxWorkouts': 'unlimited', 'workoutsUnlimited': true},
    {'maxWorkouts': double.infinity, 'workoutsUnlimited': true},
    {'maxWorkouts': 9007199254740992, 'workoutsUnlimited': false},
  ]) {
    test('ambiguous or invalid resource values stay unknown: $change', () {
      final grant = access({...storageGrant, ...change});
      expect(grant.limitFor('workouts').known, isFalse);
      expect(grant.limitFor('savedSlides').isUnlimited, isTrue);
    });
  }

  test('missing marker never means unlimited, even for Premium', () {
    final data = {...storageGrant}..remove('workoutsUnlimited');
    expect(access(data).limitFor('workouts').known, isFalse);
    expect(access(storageGrant).limitFor('unknown-resource').known, isFalse);
  });

  test('legacy saved-slide aliases require explicit matching values', () {
    final legacy = {...storageGrant, 'plan': 'cloudboard_pro'}
      ..remove('maxSavedSlides')
      ..remove('savedSlidesUnlimited');
    expect(
      access({...legacy, 'maxFavorites': null, 'favoritesUnlimited': true})
          .limitFor('savedSlides')
          .isUnlimited,
      isTrue,
    );
    expect(
      access({...legacy, 'maxFavorites': 3, 'favoritesUnlimited': false})
          .limitFor('savedSlides')
          .limit,
      3,
    );
    expect(
      access({...legacy, 'maxFavorites': null}).limitFor('savedSlides').known,
      isFalse,
    );
    expect(
      access({...storageGrant, 'maxFavorites': 3, 'favoritesUnlimited': false})
          .limitFor('savedSlides')
          .known,
      isFalse,
    );
  });

  test('named-plan contradictions do not change the server contract', () {
    expect(
      access({...storageGrant, 'plan': 'free'}).limitFor('workouts').known,
      isFalse,
    );
    expect(
      access({...storageGrant, 'plan': 'plus'}).limitFor('savedSlides').known,
      isFalse,
    );
    expect(
      access({
        ...storageGrant,
        'plan': 'free',
        'maxWorkouts': 8,
        'workoutsUnlimited': false,
      }).limitFor('workouts').known,
      isFalse,
    );
    expect(
      access({
        ...storageGrant,
        'plan': 'legacy',
        'maxWorkouts': 8,
        'workoutsUnlimited': false,
      }).limitFor('workouts').limit,
      8,
    );
  });

  test(
    'cached grants can display limits without confirming storage permission',
    () {
      final cached = StoreEntitlementModel.fromJson(storageGrant)
          .toEntity('owner', false, 999);
      expect(cached.limitFor('workouts').isUnlimited, isTrue);
      expect(cached.serverConfirmed, isFalse);
    },
  );
}
