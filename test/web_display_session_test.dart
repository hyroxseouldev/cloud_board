import 'dart:async';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/web_display_auth.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/device_mode_home_screen.dart';
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

final _owner = _User('owner-a');

class _DisplayMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.display;
}

void main() {
  testWidgets(
    'native account Display mode waits for isolated credentials',
    (tester) async {
      final controllerAuth = _Auth('owner-a');
      final identity = Completer<FirebaseAuth>();
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          deviceModeControllerProvider.overrideWith(_DisplayMode.new),
          androidTvProvider.overrideWith((_) => false),
          accountOwnerIdProvider.overrideWith((_) => Stream.value('owner-a')),
          firebaseClientAuthProvider.overrideWith((_) => controllerAuth),
          webDisplayAuthProvider('owner-a').overrideWith((_) {
            attempts++;
            return identity.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DeviceModeHomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(WebDisplaySession), findsOneWidget);
      expect(attempts, 1);
      expect(container.read(firebaseClientAuthProvider), same(controllerAuth));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('anonymous TV preserves its existing identity and device ID', (
    tester,
  ) async {
    final tvAuth = _Auth('native-tv', anonymous: true);
    var isolatedSessions = 0;
    final container = ProviderContainer(
      overrides: [
        androidTvProvider.overrideWith((_) => true),
        firebaseClientAuthProvider.overrideWith((_) => tvAuth),
        deviceIdProvider.overrideWith((_) async => 'existing-tv-device'),
        webDisplayAuthProvider('native-tv').overrideWith((_) async {
          isolatedSessions++;
          throw StateError('A native TV must retain its own identity.');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: WebDisplaySession(
            onReturnToControl: () {},
            child: Consumer(
              builder: (_, ref, _) => Text(
                '${ref.watch(firebaseClientAuthProvider).currentUser!.uid}/'
                '${ref.watch(deviceIdProvider).value}',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('native-tv/existing-tv-device'), findsOneWidget);
    expect(isolatedSessions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'signed-in TV starts its isolated display behind the recovery gate',
    (tester) async {
      final controllerAuth = _Auth('owner-a');
      final displayAuth = _Auth('display-tv', anonymous: true);
      final container = ProviderContainer(
        overrides: [
          androidTvProvider.overrideWith((_) => true),
          firebaseClientAuthProvider.overrideWith((_) => controllerAuth),
          // The controller's visibility must not leak into the isolated display.
          tvPlaybackVisibleProvider.overrideWith(() => TvPlaybackVisible()),
          webDisplayAuthProvider('owner-a')
              .overrideWith((_) async => displayAuth),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: WebDisplaySession(
              onReturnToControl: () {},
              child: Consumer(
                builder: (_, ref, _) => Text(
                  '${ref.watch(firebaseClientAuthProvider).currentUser!.uid}/'
                  '${ref.watch(androidTvProvider).requireValue}/'
                  '${ref.watch(tvPlaybackVisibleProvider)}',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('display-tv/true/false'), findsOneWidget);
      expect(container.read(firebaseClientAuthProvider), same(controllerAuth));
      expect(container.read(tvPlaybackVisibleProvider), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

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
          androidTvProvider.overrideWith((_) => false),
          deviceIdProvider.overrideWith((_) async => 'controller-device'),
          firebaseAccountUserProvider.overrideWith((_) => Stream.value(_owner)),
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
      final users = StreamController<User?>();
      final second = Completer<FirebaseAuth>();
      var disposed = 0;
      final marker = Provider((ref) {
        ref.onDispose(() => disposed++);
        return ref.watch(firebaseClientAuthProvider).currentUser!.uid;
      });
      final parent = ProviderContainer(
        overrides: [
          firebaseAccountUserProvider.overrideWith((_) => users.stream),
          androidTvProvider.overrideWith((_) => false),
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
      users.add(_User('owner-b'));
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
            androidTvProvider.overrideWith((_) => false),
            firebaseAccountUserProvider.overrideWith(
              (_) => Stream.value(_owner),
            ),
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
