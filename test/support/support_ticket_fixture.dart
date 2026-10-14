import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';

import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/support/data/datasources/support_screenshot_picker.dart';
import 'package:cloud_board/src/app/feature/support/data/repositories/support_repository_impl.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/domain/repositories/support_repository.dart';
import 'package:cloud_board/src/app/feature/support/presentation/controllers/support_controller.dart';
import 'package:cloud_board/src/app/feature/support/presentation/views/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

const supportUser = AuthUser(
  id: 'owner-a',
  email: 'coach@example.com',
  displayName: '코치',
  photoUrl: null,
);
const supportReceipt = SupportTicket(
  id: 'ticket-1',
  number: 'CB-20261014-TEST01',
  receivedAtMs: 1791986400000,
  notificationStatus: 'queued',
);
final supportPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aCXsAAAAASUVORK5CYII=',
);

class SupportFakeRepository implements SupportRepository {
  final drafts = <SupportDraft>[];
  final accounts = <String>[];
  Future<SupportTicket> Function(SupportDraft)? handler;
  @override
  Future<SupportTicket> submit(String accountId, SupportDraft draft) async {
    accounts.add(accountId);
    drafts.add(draft);
    return handler == null ? supportReceipt : handler!(draft);
  }
}

class SupportFakePicker implements SupportScreenshotPicker {
  SupportAttachment? value = SupportAttachment(
    bytes: supportPng,
    contentType: 'image/png',
    fileId: 'image-1',
  );
  Object? error;
  @override
  Future<SupportAttachment?> pick() async {
    if (error != null) throw error!;
    return value;
  }
}

class SupportFixture {
  SupportFixture({this.tv = false, Map<String, Object?>? diagnostics}) {
    available =
        diagnostics ??
        {
          'platform': 'android',
          'version': '1.1.1',
          'build': '3',
          'tvs': [
            {
              'deviceId': 'tv-studio-1',
              'appVersion': '1.1.1',
              'appBuild': '3',
              'appPlatform': 'android',
              'preparationStatus': 'failed',
              'checkedAtMs': 1791986300000,
            },
          ],
        };
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((_) => users.stream),
        androidTvProvider.overrideWith((_) async => tv),
        deviceModeControllerProvider.overrideWith(_Mode.new),
        supportRepositoryProvider.overrideWithValue(repository),
        supportScreenshotPickerProvider.overrideWithValue(picker),
        supportAvailableDiagnosticsProvider.overrideWith((_) => available),
      ],
    );
  }
  final bool tv;
  late Map<String, Object?> available;
  final users = StreamController<AuthUser?>.broadcast();
  final repository = SupportFakeRepository();
  final picker = SupportFakePicker();
  late final ProviderContainer container;
  GoRouter? router;
  bool _disposed = false;

  Widget app({
    Map<String, Object?> initialDiagnostics = const {},
    double scale = 1,
  }) {
    router ??= GoRouter(
      initialLocation: '/support',
      routes: [
        GoRoute(
          path: '/support',
          builder: (_, _) => SupportScreen(
            initialDiagnostics: initialDiagnostics,
            initialAccountId: supportUser.id,
          ),
        ),
        GoRoute(
          path: '/more',
          builder: (_, _) => const Scaffold(body: Text('더보기')),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('로그인')),
        ),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: XonTheme.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    router?.dispose();
    container.dispose();
    await users.close();
  }
}

class _Mode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}
