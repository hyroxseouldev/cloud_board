import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/config/app_links.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: AppBrand.name,
      packageName: 'com.sunmkim.cloudboard',
      version: '1.2.3',
      buildNumber: '529',
      buildSignature: 'test',
    ),
  );

  Future<void> mount(
    WidgetTester tester,
    Future<bool> Function(Uri) launch, {
    bool tv = false,
    bool hasPassword = false,
    double scale = 1,
    AccountDeletionRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              AuthUser(
                id: 'u',
                email: 'coach@example.com',
                displayName: 'Coach',
                photoUrl: null,
                hasPassword: hasPassword,
              ),
            ),
          ),
          androidTvProvider.overrideWith((ref) async => tv),
          if (repository != null)
            accountDeletionRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
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

  testWidgets('installed version and build appear below privacy policy', (
    tester,
  ) async {
    await mount(tester, (_) async => true);
    expect(find.text('버전 1.2.3 · 빌드 529'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('앱 버전')).dy,
      greaterThan(tester.getTopLeft(find.text('개인정보처리방침')).dy),
    );
  });

  testWidgets('version copy uses the configured display brand', (tester) async {
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
    await mount(tester, (_) async => true);
    await tester.ensureVisible(find.byTooltip('버전 정보 복사'));
    await tester.tap(find.byTooltip('버전 정보 복사'));
    await tester.pumpAndSettle();
    expect(clipboard, startsWith('${AppBrand.name} · '));
    expect(clipboard, endsWith(' · 버전 1.2.3 · 빌드 529'));
    expect(find.text('버전 정보를 복사했습니다.'), findsOneWidget);
  });

  testWidgets('configured account copy fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _DeletionRepository();
    await mount(tester, (_) async => true, scale: 1.5, repository: repository);
    expect(find.text('${AppBrand.nameKo} 계정과 관련 데이터를 삭제합니다.'), findsOneWidget);
    await tester.ensureVisible(find.text('계정 삭제'));
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('${AppBrand.nameKo} 계정을 삭제할까요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('${AppBrand.nameKo} 계정을 삭제할까요?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
      expect(links.single, Uri.parse(AppLinks.accountDeletion));
      expect(find.text('변경 중인 이름'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('개인정보처리방침'));
      await tester.pumpAndSettle();
      expect(links.last, Uri.parse(AppLinks.privacy));
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
      expect(
        find.textContaining('${AppLinks.supportEmail}으로 문의'),
        findsOneWidget,
      );
      await tester.tap(find.text('이메일 주소 복사'));
      await tester.pumpAndSettle();
      expect(clipboard, AppLinks.supportEmail);
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
      expect(
        find.textContaining('Google 또는 Apple 계정 자체는 삭제되지 않습니다'),
        findsOneWidget,
      );
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
  testWidgets(
    'email account deletion requires password and cancellation is non-destructive',
    (tester) async {
      final repository = _DeletionRepository();
      await mount(
        tester,
        (_) async => true,
        repository: repository,
        hasPassword: true,
      );
      await tester.tap(find.text('계정 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('본인 확인 후 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호로 본인 확인'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
      await tester.tap(find.text('계정 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('본인 확인 후 삭제'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, '현재 비밀번호'),
        'test-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '계정 삭제'));
      await tester.pump();
      expect(repository.calls, 1);
      expect(repository.password, 'test-password');
      repository.pending.complete(AccountDeletionResult.processing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
  String? password;
  @override
  Future<AccountDeletionResult> deleteAccount({String? password}) {
    calls++;
    this.password = password;
    return pending.future;
  }
}
