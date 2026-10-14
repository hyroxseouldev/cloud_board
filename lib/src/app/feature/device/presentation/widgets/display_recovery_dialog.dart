import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_recovery_controller.dart';

Future<void> showDisplayRecovery(
  BuildContext context,
  WidgetRef ref,
  DisplayDevice device,
) async {
  final owner = ref.read(accountOwnerIdProvider);
  if (owner.isLoading || owner.hasError || owner.value == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('매장 계정을 확인한 뒤 다시 시도해 주세요.')));
    return;
  }
  final ownerAtOpen = owner.value!;
  await showDialog<void>(
    context: context,
    builder: (_) =>
        DisplayRecoveryDialog(deviceId: device.id, ownerId: ownerAtOpen),
  );
}

/// Identity is captured before opening; retained stream values never cross
/// an account change, even while the old request is still in flight.
class DisplayRecoveryDialog extends ConsumerWidget {
  const DisplayRecoveryDialog({
    super.key,
    required this.deviceId,
    required this.ownerId,
  });
  final String deviceId, ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountOwnerIdProvider);
    if (owner.isLoading || owner.hasError || owner.value != ownerId) {
      return _unavailable(context, '매장 계정이 변경되었습니다. 목록에서 다시 확인해 주세요.');
    }
    final devices = ref.watch(displayDevicesProvider);
    if (devices.isLoading || devices.hasError) {
      return _unavailable(context, '현재 TV 정보를 확인하지 못했습니다. 목록을 다시 불러와 주세요.');
    }
    final device = devices.value?.where((d) => d.id == deviceId).firstOrNull;
    if (device == null || !device.paired) {
      return _unavailable(context, '이 TV의 연결이 해제되었습니다. 최신 등록 목록을 확인해 주세요.');
    }
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final state = ref.watch(displayRecoveryControllerProvider(deviceId));
    final request = state.isLoading ? null : state.value;
    final pending = state.isLoading || request?.pending == true;
    final online = device.recentlySeen(nowMs);
    final health = device.preparationHealth;
    final status = request?.status;
    final error = state.hasError
        ? displayRecoveryErrorMessage(_errorCode(state.error))
        : status == DisplayRecoveryStatus.failed ||
              status == DisplayRecoveryStatus.expired
        ? displayRecoveryErrorMessage(
            status == DisplayRecoveryStatus.expired
                ? 'response_timeout'
                : request?.errorCode,
          )
        : null;
    return AppAlertDialog(
      title: const Text('연결 복구'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(device.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(device.zoneName),
              const SizedBox(height: 16),
              _Fact('서버 응답', online ? '최근 응답 수신' : '최근 응답 없음'),
              _Fact('마지막 응답', displayResponseTime(device.lastSeenAtMs)),
              _Fact(
                '연결 권한',
                device.connectionAuthenticated(nowMs)
                    ? '현재 연결에서 확인됨'
                    : '복구 시 다시 확인',
              ),
              _Fact(
                '자료 준비',
                device.playbackReady(nowMs)
                    ? '현재 연결의 준비 응답 저장됨'
                    : '다음 수업 시작 전에 별도 확인',
              ),
              if (health.checkedAtMs > 0 && health.code.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('최근 확인 · ${displayResponseTime(health.checkedAtMs)}'),
                Text('시도 횟수 · ${health.attempt}'),
                Text(
                  '${displayFailureStage(health.stage)}: '
                  '${displayRecoveryErrorMessage(health.code)}',
                ),
              ],
              const SizedBox(height: 16),
              const Text('이 TV의 연결 권한과 최신 수업 상태를 다시 확인합니다.'),
              if (!online) ...[
                const SizedBox(height: 8),
                const Text(
                  '전원이 꺼져 있거나 인터넷이 없는 TV는 원격 요청을 받을 수 없어요. TV 전원과 Wi-Fi를 확인해 주세요.',
                ),
              ],
              if (device.recoveryProtocol < 1) ...[
                const SizedBox(height: 8),
                const Text('원격 복구를 지원하려면 TV 앱을 최신 버전으로 업데이트해 주세요.'),
              ],
              if (state.isLoading) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('연결 정보 확인 및 복구 요청 중…'),
              ],
              if (request != null) ...[
                const SizedBox(height: 20),
                _RecoveryProgress(status: request.status),
                if (request.pending) ...[
                  const SizedBox(height: 8),
                  const Text('최대 1분 동안 TV 응답을 확인합니다. 요청 접수는 복구 완료가 아닙니다.'),
                ],
                if (status == DisplayRecoveryStatus.succeeded) ...[
                  const SizedBox(height: 8),
                  const Text('연결 복구가 확인되었습니다. TV가 현재 서버 수업 상태를 확인했습니다.'),
                ],
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('문의용 작업 정보'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText('작업 ID: ${request.operationId}'),
                    ),
                    if (request.errorId != null &&
                        request.errorId != request.operationId)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText('오류 ID: ${request.errorId}'),
                      ),
                  ],
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        FilledButton.icon(
          onPressed: pending
              ? null
              : () => ref
                    .read(displayRecoveryControllerProvider(deviceId).notifier)
                    .request(),
          icon: const Icon(Icons.sync),
          label: Text(
            pending
                ? '복구 확인 중…'
                : request == null
                ? '연결 복구 시작'
                : '다시 확인',
          ),
        ),
      ],
    );
  }

  Widget _unavailable(BuildContext context, String message) => AppAlertDialog(
    title: const Text('연결 복구'),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text('$label · $value'),
  );
}

class _RecoveryProgress extends StatelessWidget {
  const _RecoveryProgress({required this.status});
  final DisplayRecoveryStatus status;
  @override
  Widget build(BuildContext context) {
    final completed = switch (status) {
      DisplayRecoveryStatus.requested => 1,
      DisplayRecoveryStatus.received => 2,
      DisplayRecoveryStatus.recovering => 2,
      DisplayRecoveryStatus.succeeded => 4,
      DisplayRecoveryStatus.failed || DisplayRecoveryStatus.expired => 0,
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, label) in const [
            '서버 요청 접수',
            'TV 요청 수신',
            '최신 수업 다시 확인',
            'TV 최신 상태 확인',
          ].indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i < completed
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _errorCode(Object? error) {
  if (error is TimeoutException) return 'response_timeout';
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    if (details is Map && details['code'] is String) {
      return details['code'] as String;
    }
    return error.code;
  }
  return 'recovery_failed';
}

String displayRecoveryErrorMessage(String? code) => switch (code) {
  'connection_conflict' =>
    '연결 정보가 서로 일치하지 않습니다. 등록을 지우지 말고 작업 ID와 함께 고객지원에 문의해 주세요.',
  'connection_missing' ||
  'device_unpaired' => '유효한 TV 연결 정보를 찾지 못했습니다. 매장 계정과 등록 목록을 확인해 주세요.',
  'account_unavailable' ||
  'permission_denied' ||
  'permission-denied' ||
  'unauthenticated' => 'TV 연결 권한을 확인하지 못했습니다. 매장 계정과 TV 연결 정보를 확인해 주세요.',
  'update_required' => '이 TV 앱은 원격 복구를 지원하지 않습니다. TV 앱을 최신 버전으로 업데이트해 주세요.',
  'request_expired' ||
  'response_timeout' ||
  'device_offline' ||
  'deadline-exceeded' =>
    '제한시간 안에 TV 복구 응답을 받지 못했습니다. TV 전원과 Wi-Fi를 확인한 뒤 다시 시도해 주세요.',
  'request_superseded' => '새 복구 요청으로 변경되었습니다. 최신 결과를 확인해 주세요.',
  'latest_session_changed' => '확인 중 수업 상태가 변경되었습니다. 현재 수업을 다시 확인해 주세요.',
  'subscription_recovery_failed' || 'recovery_verification_failed' =>
    'TV가 최신 서버 상태를 확인하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.',
  'unavailable' ||
  'network-request-failed' ||
  'disconnected' => '서버와 연결하지 못했습니다. 인터넷 연결 후 다시 시도해 주세요.',
  'media_failed' => 'TV 자료를 준비하지 못했습니다. 인터넷과 자료를 확인한 뒤 다시 시도해 주세요.',
  _ => '복구를 확인하지 못했습니다. 다시 시도하거나 작업 ID와 함께 고객지원에 문의해 주세요.',
};

String displayFailureStage(String stage) => switch (stage) {
  'request' || 'request_read' || 'subscribe' => '준비 요청 수신',
  'media' || 'media_prepare' => '자료 준비',
  'response' || 'response_write' => '준비 응답 저장',
  'heartbeat' => '서버 응답 전송',
  _ => 'TV 연결 확인',
};

String displayResponseTime(int timestamp) {
  if (timestamp <= 0) return '기록 없음';
  final time = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).add(const Duration(hours: 9));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.month)}.${two(time.day)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)} (한국 시간)';
}
