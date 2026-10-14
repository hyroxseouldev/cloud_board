import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/support/data/datasources/support_screenshot_picker.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/domain/usecases/support_actions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'support_controller.g.dart';

@riverpod
SupportScreenshotPicker supportScreenshotPicker(Ref ref) =>
    ImagePickerSupportScreenshot();

@riverpod
Future<Map<String, Object?>> supportAppDiagnostics(Ref ref) async {
  final defaults = ref.watch(errorReporterProvider).defaults;
  final data = <String, Object?>{
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    ...defaults,
  };
  try {
    final info = await PackageInfo.fromPlatform().timeout(
      const Duration(seconds: 2),
    );
    data.addAll({'version': info.version, 'build': info.buildNumber});
  } catch (_) {
    // Missing metadata is shown as unknown, never invented.
  }
  return filterSupportDiagnostics(data);
}

@riverpod
Stream<Map<String, DisplayPreparationReceipt>> supportPreparationReceipts(
  Ref ref,
) => ref.watch(displayPreparationRepositoryProvider).watchReceipts();

@riverpod
Map<String, Object?> supportAvailableDiagnostics(Ref ref) {
  final app =
      ref.watch(supportAppDiagnosticsProvider).value ??
      const <String, Object?>{};
  final userId = ref.watch(
    authStateProvider.select((value) => value.value?.id),
  );
  final owner = ref.watch(accountOwnerIdProvider);
  if (owner.isLoading ||
      owner.hasError ||
      owner.value != userId ||
      userId == null) {
    return app;
  }
  final deviceState = ref.watch(displayDevicesProvider);
  final devices = deviceState.isLoading || deviceState.hasError
      ? null
      : deviceState.value;
  final receiptState = ref.watch(supportPreparationReceiptsProvider);
  final receipts = receiptState.isLoading || receiptState.hasError
      ? null
      : receiptState.value;
  return filterSupportDiagnostics({
    ...app,
    if (devices != null)
      'tvs': [
        for (final device in devices.take(10))
          {
            'deviceId': device.id,
            'appVersion': device.appVersion,
            'appBuild': device.appBuild,
            'appPlatform': device.appPlatform,
            'online': device.online,
            'paired': device.paired,
            if (receipts?[device.id] case final receipt?) ...{
              // This is a timestamped receipt, not a claim that the TV is ready now.
              'preparationStatus': receipt.status,
              'preparationRevision': receipt.revision,
              'checkedAtMs': receipt.checkedAtMs,
              'imageCount': receipt.imageCount,
              'audioReady': receipt.audioReady,
            },
          },
      ],
  });
}

String supportFailureMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'unauthenticated' => '로그인 상태를 확인한 뒤 다시 시도해 주세요. 작성한 내용은 유지됩니다.',
      'resource-exhausted' => '문의 접수 횟수 제한에 도달했어요. 잠시 후 다시 시도해 주세요.',
      'permission-denied' => '문의 접수 권한을 확인하지 못했어요. 로그인 상태를 확인해 주세요.',
      'already-exists' ||
      'failed-precondition' => '접수 요청을 확인하지 못했어요. 같은 내용으로 다시 확인해 주세요.',
      _ => '접수 결과를 확인하지 못했어요. 작성한 내용은 유지됩니다. 같은 내용으로 다시 확인해 주세요.',
    };
  }
  return '접수 결과를 확인하지 못했어요. 작성한 내용은 유지됩니다. 같은 내용으로 다시 확인해 주세요.';
}

@Riverpod(keepAlive: true)
class SupportController extends _$SupportController {
  @override
  SupportDraft build() {
    _epoch++;
    ref.watch(authStateProvider.select((value) => value.value?.id));
    return SupportDraft(
      requestId: _newId(),
      replyEmail: ref.read(authStateProvider).value?.email ?? '',
    );
  }

  int _epoch = 0;

  String _newId() => 'support-${createEventId()}';

  void _edit(SupportDraft next) {
    if (state.submitting || state.ticket != null) return;
    state = next.copyWith(requestId: _newId(), frozen: false, error: null);
  }

  void message(String value) => _edit(state.copyWith(message: value));
  void replyEmail(String value) => _edit(state.copyWith(replyEmail: value));
  void attachment(SupportAttachment? value) =>
      _edit(state.copyWith(attachment: value));
  void attachDiagnostics(Map<String, Object?> values) {
    if (values.isEmpty || state.submitting) return;
    final clean = filterSupportDiagnostics(values);
    if (clean['errorId'] == state.diagnostics['errorId']) return;
    if (state.ticket != null) reset();
    _edit(state.copyWith(diagnostics: clean));
  }

  void localError(Object error) {
    if (!state.submitting) {
      state = state.copyWith(error: supportFailureMessage(error));
    }
  }

  void reset() {
    if (state.submitting) return;
    state = SupportDraft(
      requestId: _newId(),
      replyEmail: ref.read(authStateProvider).value?.email ?? '',
    );
  }

  Future<bool> submit(Map<String, Object?> available) async {
    if (state.submitting) return false;
    final epoch = _epoch;
    final owner = ref.read(authStateProvider).value?.id;
    if (owner == null) {
      state = state.copyWith(error: '로그인 후 문의를 접수해 주세요.');
      return false;
    }
    final frozen = state.frozen
        ? state
        : state.copyWith(
            diagnostics: filterSupportDiagnostics({
              ...available,
              ...state.diagnostics,
            }),
            frozen: true,
          );
    state = frozen.copyWith(submitting: true, error: null);
    final result = await AsyncValue.guard(
      () => ref.read(supportActionsProvider).submit(owner, frozen),
    );
    if (!ref.mounted ||
        epoch != _epoch ||
        ref.read(authStateProvider).value?.id != owner) {
      return false;
    }
    state = state.copyWith(
      submitting: false,
      ticket: result.value ?? state.ticket,
      error: result.hasError ? supportFailureMessage(result.error!) : null,
    );
    return !result.hasError;
  }
}
