import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/profile/data/repositories/account_deletion_repository_impl.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/account_deletion_controller.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/widgets/account_management_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    Future<bool> Function(Uri) launch, {
    bool tv = false,
    AccountDeletionRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          androidTvProvider.overrideWith((ref) async => tv),
          if (repository != null)
            accountDeletionRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(labelText: '편집 중인 이름'),
                  ),
                  AccountManagementSection(openLink: launch),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(390, 844), const Size(834, 1194)]) {
    testWidgets('links preserve the current screen and draft at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final links = <Uri>[];
      await mount(tester, (uri) async {
        links.add(uri);
        return true;
      });
      await tester.enterText(find.byType(TextField), '변경 중인 이름');
      await tester.tap(find.text('계정 삭제 안내 및 문의'));
      await tester.pumpAndSettle();
      expect(links.single.path, '/apps/cloudboard/delete-account');
      expect(links.single.hasQuery, isFalse);
      expect(find.text('변경 중인 이름'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      expect(links.last.path, '/apps/cloudboard/privacy');
      expect(tester.takeException(), isNull);
    });
  }
  for (final throws in [false, true]) {
    testWidgets('failed launch ($throws) offers working email copy', (
      tester,
    ) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(tester, (_) async {
        if (throws) throw PlatformException(code: 'unavailable');
        return false;
      });
      await tester.tap(find.text('계정 삭제 안내 및 문의'));
      await tester.pumpAndSettle();
      expect(find.textContaining('vividxxxxx@gmail.com으로 문의'), findsOneWidget);
      await tester.tap(find.text('이메일 주소 복사'));
      await tester.pumpAndSettle();
      expect(clipboard, 'vividxxxxx@gmail.com');
      expect(find.text('이메일 주소를 복사했습니다.'), findsOneWidget);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('계정 삭제 안내 및 문의'), findsOneWidget);
    });
  }
  testWidgets('repeated taps launch once while the platform is responding', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    await mount(tester, (_) {
      calls++;
      return pending.future;
    });
    await tester.tap(find.text('계정 삭제 안내 및 문의'));
    await tester.pump();
    await tester.tap(find.text('계정 삭제 안내 및 문의'));
    expect(calls, 1);
    pending.complete(true);
    await tester.pumpAndSettle();
  });
  testWidgets('TV does not expose mobile browser actions', (tester) async {
    await mount(
      tester,
      (_) async => throw StateError('Must not launch'),
      tv: true,
    );
    expect(find.text('계정 삭제 안내 및 문의'), findsNothing);
    expect(find.text('개인정보처리방침'), findsNothing);
  });
  testWidgets(
    'actual deletion requires confirmation and prevents duplicate execution',
    (tester) async {
      final repository = _DeletionRepository();
      await mount(tester, (_) async => true, repository: repository);
      await tester.tap(find.text('계정 삭제'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google 계정 자체는 삭제되지 않습니다'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.tap(find.text('계정 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('본인 확인 후 삭제'));
      await tester.pump();
      expect(repository.calls, 1);
      expect(find.text('본인 확인 및 삭제 처리 중…'), findsOneWidget);
      repository.pending.complete(AccountDeletionResult.completed);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountManagementSection)),
      );
      expect(
        container.read(accountDeletionControllerProvider).value,
        AccountDeletionResult.completed,
      );
    },
  );
  testWidgets('partial deletion is never presented as completed', (
    tester,
  ) async {
    final repository = _DeletionRepository();
    await mount(tester, (_) async => true, repository: repository);
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('본인 확인 후 삭제'));
    await tester.pump();
    repository.pending.complete(AccountDeletionResult.processing);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountManagementSection)),
    );
    expect(
      container.read(accountDeletionControllerProvider).value,
      AccountDeletionResult.processing,
    );
    expect(
      container.read(accountDeletionControllerProvider).value,
      isNot(AccountDeletionResult.completed),
    );
  });
}

class _DeletionRepository implements AccountDeletionRepository {
  final pending = Completer<AccountDeletionResult>();
  int calls = 0;
  @override
  Future<AccountDeletionResult> deleteAccount() {
    calls++;
    return pending.future;
  }
}
