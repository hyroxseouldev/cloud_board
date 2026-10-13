import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';

void main() {
  test('unknown and expired policy never become Free or unlimited', () {
    final base = <String, dynamic>{
      'policyVersion': 'plan-entitlements-v2',
      'status': 'active',
      'plan': 'free',
      'validUntilMs': 1000,
      'maxWorkouts': 7,
      'workoutsUnlimited': false,
      'maxSavedSlides': 3,
      'savedSlidesUnlimited': false,
      'idleScreenCustomization': 'basic',
      'aiSlidesMonthlyLimit': 0,
      'aiTimerMonthlyLimit': 0,
    };
    expect(
      StoreEntitlementModel.fromJson({}).toEntity('a', true, 0).policyKnown,
      isFalse,
    );
    expect(
      StoreEntitlementModel.fromJson(base).toEntity('a', true, 999).policyKnown,
      isTrue,
    );
    expect(
      StoreEntitlementModel.fromJson(base)
          .toEntity('a', true, 1000)
          .policyKnown,
      isFalse,
    );
    final cached = StoreEntitlementModel.fromJson(base)
        .toEntity('a', false, 999);
    expect(cached.policyKnown, isTrue);
    expect(cached.serverConfirmed, isFalse);
    expect(
      StoreEntitlementModel.fromJson({...base, 'status': 'revoked'})
          .toEntity('a', true, 999)
          .policyKnown,
      isFalse,
    );
    expect(
      StoreEntitlementModel.fromJson({...base, 'maxWorkouts': null})
          .toEntity('a', true, 999)
          .policyKnown,
      isFalse,
    );
    expect(
      StoreEntitlementModel.fromJson({
        ...base,
        'plan': 'premium',
        'maxWorkouts': null,
        'workoutsUnlimited': true,
        'maxSavedSlides': null,
        'savedSlidesUnlimited': true,
      }).toEntity('a', true, 999).policyKnown,
      isTrue,
    );
  });

  test(
    'access is bound to the current account and expires at the exact boundary',
    () {
      const access = StoreEntitlement(
        ownerId: 'a',
        validUntilMs: 1000,
        canStartClass: true,
        serverConfirmed: true,
      );
      expect(access.allowsNewClass('a', 999), isTrue);
      expect(access.allowsNewClass('b', 999), isFalse);
      expect(access.allowsNewClass(null, 999), isFalse);
      expect(access.allowsNewClass('a', 1000), isFalse);
      expect(
        access.copyWith(serverConfirmed: false).allowsNewClass('a', 999),
        isFalse,
      );
    },
  );
  test('missing data is free preparation and expired trial cannot start another class', () {
    final empty = StoreEntitlementModel.fromJson({}).toEntity('a', true, 0);
    expect(empty.canStartClass, isFalse);
    final trial = StoreEntitlementModel.fromJson({
      'status': 'trialing',
      'validUntilMs': 1000,
      'canPairDisplay': true,
      'canStartClass': true,
    });
    expect(trial.toEntity('a', true, 1000).canStartClass, isFalse);
    expect(trial.toEntity('a', true, 1000).canPairDisplay, isFalse);
    expect(
      const StoreEntitlementModel(
        status: 'pending_connection',
        canPairDisplay: true,
      ).toEntity('a', true, 1000).canPairDisplay,
      isTrue,
    );
  });
}
