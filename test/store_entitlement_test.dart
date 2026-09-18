import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/entities/store_entitlement.dart';
import 'package:cloud_board/src/app/feature/entitlement/data/models/store_entitlement_model.dart';

void main() {
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
