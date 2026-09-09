import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

void main() {
  test('signed-in account switches its database owner scope immediately', () {
    expect(
      accountOwnerIdForUser(uid: 'first-account', isAnonymous: false),
      'first-account',
    );
    expect(
      accountOwnerIdForUser(uid: 'second-account', isAnonymous: false),
      'second-account',
    );
  });

  test('anonymous display waits for its paired owner mapping', () {
    expect(
      accountOwnerIdForUser(uid: 'display-account', isAnonymous: true),
      isNull,
    );
  });
}
