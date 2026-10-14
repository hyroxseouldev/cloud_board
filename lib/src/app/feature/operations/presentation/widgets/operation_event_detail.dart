import 'package:cloud_board/src/app/core/config/app_links.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

String operationTypeLabel(String type) => switch (type) {
  'playback_started' => '수업 시작 기록',
  'playback_completed' => '수업 종료 기록',
  'device_online' => 'TV 서버 연결',
  'device_offline' => 'TV 서버 접속 끊김',
  'device_shutdown' => '앱 종료 신호',
  'controller_offline' => '컨트롤러 서버 접속 끊김',
  'controller_online' => '컨트롤러 서버 연결',
  'connection_failed' => '서버 연결 이상',
  'connection_recovered' => '서버 연결 복구',
  'preparation_failed' => 'TV 자료 준비 실패',
  'preparation_ready' => 'TV 자료 준비 완료',
  'preparation_succeeded' => 'TV 자료 준비 완료',
  'command_failed' => '수업 명령 처리 실패',
  'command_receipt_failed' => 'TV 명령 수신 확인 실패',
  'command_accepted' => '서버 명령 승인',
  'command_approved' => '서버 명령 승인',
  'command_received' => 'TV 명령 수신',
  'playback_interrupted' => '재생 중단 확인',
  'playback_restored' => '재생 복구 확인',
  _ => '운영 기록',
};

String operationPhaseLabel(String? phase) => switch (phase) {
  'preparation' || 'tv_preparation' => 'TV 자료 준비',
  'preparation_request' => 'TV 준비 요청',
  'command' || 'command_delivery' || 'command_send' => '명령 전달',
  'server_accepted' || 'server_acceptance' || 'server_approval' => '서버 명령 승인',
  'tv_received' || 'tv_receipt' => 'TV 명령 수신',
  'connection' || 'presence' || 'server_connection' => '서버 연결',
  'controller_connection' => '휴대폰·웹 서버 연결',
  'app_lifecycle' => '앱 실행 상태',
  'playback' => '수업 재생',
  _ => '단계 기록 없음',
};

String operationRoleLabel(OperationEvent event) => switch (event.deviceRole) {
  'controller' => '휴대폰·웹 컨트롤러',
  'display' || 'tv' => 'TV',
  _ => '기기 역할 기록 없음',
};

String operationDateLabel(int timestamp, {bool seconds = false}) {
  final date = centerDateTime(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}.${two(date.month)}.${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}${seconds ? ':${two(date.second)}' : ''}';
}

String operationDurationLabel(Duration duration) {
  if (duration.inMinutes == 0) return '${duration.inSeconds}초';
  if (duration.inHours == 0) return '${duration.inMinutes}분';
  return '${duration.inHours}시간 ${duration.inMinutes.remainder(60)}분';
}

Future<void> showOperationEventDetail(
  BuildContext context, {
  required OperationEvent event,
  required List<OperationEvent> events,
}) {
  final ownerAtOpen = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(authStateProvider).value?.id;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 800),
    builder: (_) => FractionallySizedBox(
      heightFactor: .9,
      child: OperationEventDetail(
        event: event,
        events: events,
        ownerAtOpen: ownerAtOpen,
      ),
    ),
  );
}

class OperationEventDetail extends ConsumerWidget {
  const OperationEventDetail({
    super.key,
    required this.event,
    required this.events,
    required this.ownerAtOpen,
  });
  final OperationEvent event;
  final List<OperationEvent> events;
  final String? ownerAtOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final owner = auth.value?.id;
    if (auth.isLoading ||
        auth.hasError ||
        owner == null ||
        owner != ownerAtOpen) {
      return const Center(child: Text('로그인한 계정에서 기록을 다시 열어 주세요.'));
    }
    final incident = buildOperationIncidents(events)
        .where(
          (item) => item.event.id == event.id || item.recovery?.id == event.id,
        )
        .firstOrNull;
    final session = event.sessionId;
    final related = session == null
        ? <OperationEvent>[]
        : uniqueOperationEvents(
            events.where((item) => item.sessionId == session),
          ).reversed.toList();
    final router = GoRouter.maybeOf(context);
    // STA-171 owns the support form and notifications. This handoff works when
    // that route is installed, and keeps this independently reviewable branch
    // usable before the support feature has been integrated.
    final supportAvailable =
        router != null &&
        !router.configuration.findMatch(Uri(path: '/support')).isError;
    final details = <String>[
      operationTypeLabel(event.type),
      '발생: ${operationDateLabel(event.occurredAtMs, seconds: true)} ($centerTimeZone)',
      '기기: ${event.deviceName ?? '이름 기록 없음'} · ${operationRoleLabel(event)}',
      '공간: ${event.zoneName ?? '기록 없음'}',
      '수업: ${event.workoutName ?? '기록 없음'}',
      '기록 ID: ${event.eventId ?? event.id}',
      if (session != null) '수업 실행 ID: $session',
      if (event.errorId != null) '오류 ID: ${event.errorId}',
      if (event.errorCode != null) '오류 코드: ${event.errorCode}',
      if (incident != null)
        '${incident.recoveryLabel} · ${incident.impactLabel}',
    ].join('\n');

    Future<void> copyDetails() async {
      try {
        await Clipboard.setData(ClipboardData(text: details));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('문의에 필요한 기록 정보를 복사했습니다.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('복사하지 못했습니다. 상세 정보를 길게 눌러 복사해 주세요.')),
          );
        }
      }
    }

    Widget field(String label, String? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 3),
          SelectableText(value?.isNotEmpty == true ? value! : '기록 없음'),
        ],
      ),
    );
    return ListView(
      key: const ValueKey('operation-event-detail'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                operationTypeLabel(event.type),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(
          '${operationDateLabel(event.occurredAtMs, seconds: true)} · $centerTimeZone',
        ),
        const SizedBox(height: 16),
        if (incident != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incident.recoveryLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(incident.impactLabel),
                  const SizedBox(height: 6),
                  const Text('원인 확인 필요. 서버 접속이 끊겨도 TV에서 수업이 계속 재생될 수 있습니다.'),
                  if (incident.recovery != null)
                    field(
                      '복구 시각',
                      operationDateLabel(
                        incident.recovery!.occurredAtMs,
                        seconds: true,
                      ),
                    ),
                  field(
                    '확인된 지속 시간',
                    incident.duration == null
                        ? '확인 불가 · 복구 기록 없음'
                        : operationDurationLabel(incident.duration!),
                  ),
                ],
              ),
            ),
          ),
        field(
          '기기 · 역할',
          '${event.deviceName ?? '이름 기록 없음'} · ${operationRoleLabel(event)}',
        ),
        field('당시 공간', event.zoneName),
        field('수업', event.workoutName),
        field('당시 앱·TV 버전', event.appVersion),
        field('처리 단계', operationPhaseLabel(event.phase)),
        if (event.type == 'device_shutdown')
          const Text(
            '앱 실행이 종료·분리되는 신호를 기록했습니다. 사용자가 종료했는지, 전원이 꺼졌는지는 확인할 수 없습니다. 서버 접속 끊김과 별도로 표시합니다.',
          ),
        if (event.targetDeviceIds.isNotEmpty) ...[
          const Divider(height: 24),
          Text('대상 TV', style: Theme.of(context).textTheme.titleMedium),
          for (final id in event.targetDeviceIds)
            field(
              event.targetDeviceNames[id] ?? '기기 이름 기록 없음',
              event.targetDeviceVersions[id] ?? '버전 기록 없음',
            ),
        ],
        const Divider(height: 24),
        Text('대응 안내', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'TV에서 수업이 계속 재생되는지 먼저 확인해 주세요. 휴대폰과 TV의 인터넷 연결을 확인하고, 수업 제어 화면에서 현재 상태를 다시 확인해 주세요. 문제가 반복되면 아래 기록 정보로 문의할 수 있어요.',
        ),
        if (related.isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            '같은 수업의 기록 ${related.length}건',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('선택한 조회 기간 안의 기록입니다. 단계의 선후 관계만으로 장애 원인을 판단하지 않습니다.'),
          for (final item in related)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(operationTypeLabel(item.type)),
              subtitle: Text(
                '${operationDateLabel(item.occurredAtMs)}\n${item.deviceName ?? '이름 기록 없음'} · ${operationRoleLabel(item)}',
              ),
            ),
        ] else if (session == null) ...[
          const SizedBox(height: 16),
          const Text('수업 실행 ID가 수집되지 않아 다른 기록과 연결할 수 없습니다.'),
        ],
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('기술 정보 · 오류 ID'),
          children: [
            field('기록 ID', event.eventId ?? event.id),
            field('수업 실행 ID', session),
            field('기기 ID', event.deviceId),
            field('오류 ID', event.errorId),
            field('오류 코드', event.errorCode),
            field('이벤트 유형', event.type),
            field('처리 단계 코드', event.phase),
            field('사건 ID', event.incidentId),
            if (event.schemaVersion < 2)
              const Text('이전 버전에서 수집한 기록입니다. 당시 기기·공간·버전·복구 정보는 없을 수 있습니다.'),
          ],
        ),
        const SizedBox(height: 16),
        if (supportAvailable)
          FilledButton.icon(
            key: const ValueKey('operation-contact-support'),
            icon: const Icon(Icons.support_agent),
            label: const Text('이 기록으로 문의하기'),
            onPressed: () => router.push(
              '/support',
              extra: <String, Object?>{
                '_supportOwnerId': owner,
                'operationId': event.eventId ?? event.id,
                'occurredAtMs': event.occurredAtMs,
                'action': event.type,
                'sessionId': ?session,
                if (event.workoutId != null) 'workoutId': event.workoutId,
                if (event.errorId != null) 'errorId': event.errorId,
                if (event.errorCode != null) 'code': event.errorCode,
                if (event.phase != null) 'startStage': event.phase,
                if (event.deviceRole != null) 'role': event.deviceRole,
                if (event.appVersion != null) 'version': event.appVersion,
                'tvs': [
                  for (final id in event.targetDeviceIds)
                    <String, Object?>{
                      'deviceId': id,
                      if (event.targetDeviceVersions[id] != null)
                        'appVersion': event.targetDeviceVersions[id],
                    },
                  if (event.deviceRole == 'display' &&
                      event.deviceId != null &&
                      !event.targetDeviceIds.contains(event.deviceId))
                    <String, Object?>{
                      'deviceId': event.deviceId,
                      if (event.appVersion != null)
                        'appVersion': event.appVersion,
                    },
                ],
              },
            ),
          )
        else
          const SelectableText(
            '문의: ${AppLinks.supportEmail}\n기록 정보를 복사해 함께 보내주시면 확인에 도움이 됩니다.',
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: copyDetails,
          icon: const Icon(Icons.copy_outlined),
          label: const Text('문의용 기록 정보 복사'),
        ),
      ],
    );
  }
}
