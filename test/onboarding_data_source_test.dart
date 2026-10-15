import 'dart:async';

import 'package:cloud_board/src/app/core/config/firebase_environment.dart';
import 'package:cloud_board/src/app/feature/onboarding/data/datasources/onboarding_data_source.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends Fake implements User {
  _User(this.events);
  final List<String> events;
  Completer<void>? refresh;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    expect(forceRefresh, isTrue);
    events.add('refresh');
    await refresh?.future;
    return 'refreshed-token';
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  final User? currentUser;
}

class _Result<T> extends Fake implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.events);
  final List<String> events;
  Object? failure;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    events.add(parameters['action'] as String);
    if (failure != null) throw failure!;
    return _Result({'ok': true} as T);
  }
}

class _Functions extends Fake implements FirebaseFunctions {
  _Functions(this.callable);
  final _Callable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'cloudboardAppOnboarding');
    return callable;
  }
}

void main() {
  for (final action in ['sendCode', 'verifyCode', 'load', 'save']) {
    test(
      '$action refreshes claims only for development phone requests',
      () async {
        final events = <String>[];
        final user = _User(events)..refresh = Completer<void>();
        final source = OnboardingDataSource(
          auth: _Auth(user),
          functions: _Functions(_Callable(events)),
        );
        final needsRefresh =
            !FirebaseEnvironment.isProduction &&
            const ['sendCode', 'verifyCode'].contains(action);
        final request = source.call({'action': action});
        await Future<void>.delayed(Duration.zero);
        expect(events, needsRefresh ? ['refresh'] : [action]);
        user.refresh!.complete();
        expect(await request, {'ok': true});
        expect(events, [if (needsRefresh) 'refresh', action]);
      },
    );
  }

  test('an unregistered tester still receives the server denial', () async {
    final events = <String>[];
    final callable = _Callable(events)
      ..failure = FirebaseFunctionsException(
        code: 'permission-denied',
        message: '개발 테스트 계정 등록이 필요합니다.',
      );
    final source = OnboardingDataSource(
      auth: _Auth(_User(events)),
      functions: _Functions(callable),
    );

    await expectLater(
      source.call({'action': 'sendCode'}),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '개발 테스트 계정 등록이 필요합니다.',
        ),
      ),
    );
    expect(events.where((event) => event == 'sendCode'), hasLength(1));
  });

  test('a failed claim refresh does not send a development code', () async {
    if (FirebaseEnvironment.isProduction) return;
    final events = <String>[];
    final user = _User(events)..refresh = Completer<void>();
    final source = OnboardingDataSource(
      auth: _Auth(user),
      functions: _Functions(_Callable(events)),
    );
    final request = source.call({'action': 'sendCode'});
    final assertion = expectLater(
      request,
      throwsA(isA<FirebaseAuthException>()),
    );
    user.refresh!.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await assertion;
    expect(events, ['refresh']);
  });
}
