import 'dart:async';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/web_display_auth.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/web_display_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _User implements User {
  _User(this.uid, {this.isAnonymous = false});
  @override
  final String uid;
  @override
  final bool isAnonymous;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(String uid, {bool anonymous = false})
    : currentUser = _User(uid, isAnonymous: anonymous);
  @override
  final User currentUser;
  @override
  Stream<User?> userChanges() => Stream.value(currentUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _owner = AuthUser(
  id: 'owner-a',
  email: '',
  displayName: '',
  photoUrl: null,
);

void main() {
  testWidgets(
    'display has an isolated identity and returning preserves Google auth',
    (tester) async {
      final controllerAuth = _Auth('owner-a');
      final displayAuth = _Auth('display-a', anonymous: true);
      var disposed = 0;
      String? displayId;
      final marker = Provider((ref) {
        ref.onDispose(() => disposed++);
        return ref.watch(firebaseClientAuthProvider).currentUser!.uid;
      });
      final showing = ValueNotifier(true);
      addTearDown(showing.dispose);
      final parent = ProviderContainer(
        overrides: [
          firebaseClientAuthProvider.overrideWith((_) => controllerAuth),
          deviceIdProvider.overrideWith((_) async => 'controller-device'),
          authStateProvider.overrideWith((_) => Stream.value(_owner)),
          webDisplayAuthProvider('owner-a')
              .overrideWith((_) async => displayAuth),
        ],
      );
      addTearDown(parent.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: parent,
          child: MaterialApp(
            home: ValueListenableBuilder(
              valueListenable: showing,
              builder: (_, show, _) => show
                  ? WebDisplaySession(
                      onReturnToControl: () => showing.value = false,
                      child: Consumer(
                        builder: (_, ref, _) {
                          displayId = ref.watch(deviceIdProvider).value;
                          return Text(ref.watch(marker));
                        },
                      ),
                    )
                  : const Text('Control'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('display-a'), findsOneWidget);
      final firstDisplayId = displayId;
      expect(firstDisplayId, isNotNull);
      expect(firstDisplayId, isNot('controller-device'));
      expect(parent.read(firebaseClientAuthProvider), same(controllerAuth));
      expect(
        parent.read(firebaseClientAuthProvider).currentUser!.uid,
        'owner-a',
      );
      showing.value = false;
      await tester.pumpAndSettle();
      expect(disposed, 1);
      expect(find.text('Control'), findsOneWidget);
      expect(parent.read(firebaseClientAuthProvider), same(controllerAuth));
      showing.value = true;
      await tester.pumpAndSettle();
      expect(displayId, firstDisplayId);
    },
  );

  testWidgets(
    'an account change removes the previous display while the new identity loads',
    (tester) async {
      final users = StreamController<AuthUser?>();
      final second = Completer<FirebaseAuth>();
      var disposed = 0;
      final marker = Provider((ref) {
        ref.onDispose(() => disposed++);
        return ref.watch(firebaseClientAuthProvider).currentUser!.uid;
      });
      final parent = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((_) => users.stream),
          webDisplayAuthProvider('owner-a')
              .overrideWith((_) async => _Auth('display-a', anonymous: true)),
          webDisplayAuthProvider('owner-b').overrideWith((_) => second.future),
        ],
      );
      addTearDown(() async {
        parent.dispose();
        await users.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: parent,
          child: MaterialApp(
            home: WebDisplaySession(
              onReturnToControl: () {},
              child: Consumer(builder: (_, ref, _) => Text(ref.watch(marker))),
            ),
          ),
        ),
      );
      users.add(_owner);
      await tester.pumpAndSettle();
      expect(find.text('display-a'), findsOneWidget);
      users.add(_owner.copyWith(id: 'owner-b'));
      await tester.pump();
      await tester.pump();
      expect(find.text('display-a'), findsNothing);
      expect(disposed, 1);
      second.complete(_Auth('display-b', anonymous: true));
      await tester.pumpAndSettle();
      expect(find.text('display-b'), findsOneWidget);
    },
  );

  testWidgets(
    'failed device authentication allows retry and return to control',
    (tester) async {
      var attempts = 0, returned = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((_) => Stream.value(_owner)),
            webDisplayAuthProvider('owner-a').overrideWith((_) async {
              attempts++;
              throw FirebaseAuthException(code: 'network-request-failed');
            }),
          ],
          retry: (_, _) => null,
          child: MaterialApp(
            home: WebDisplaySession(
              onReturnToControl: () => returned = true,
              child: const Text('Display'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Display'), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      await tester.tap(find.text('컨트롤 화면으로 돌아가기'));
      expect(returned, isTrue);
    },
  );
}
