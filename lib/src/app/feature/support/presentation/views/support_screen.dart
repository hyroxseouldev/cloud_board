import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/core/config/app_links.dart';
import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/presentation/controllers/support_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SupportScreen extends HookConsumerWidget {
  const SupportScreen({
    super.key,
    this.initialDiagnostics = const {},
    this.initialAccountId,
  });
  final Map<String, Object?> initialDiagnostics;
  final String? initialAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(androidTvProvider);
    final displayMode =
        ref.watch(deviceModeControllerProvider).value == DeviceMode.display;
    final auth = ref.watch(authStateProvider);
    final draft = ref.watch(supportControllerProvider);
    final controller = ref.read(supportControllerProvider.notifier);
    final picking = useState(false);
    final message = useTextEditingController(text: draft.message);
    final email = useTextEditingController(text: draft.replyEmail);
    final form = useMemoized(GlobalKey<FormState>.new);
    useEffect(() {
      Future.microtask(() {
        if (context.mounted &&
            initialAccountId != null &&
            auth.value?.id == initialAccountId) {
          controller.attachDiagnostics(initialDiagnostics);
        }
      });
      return null;
    }, [initialDiagnostics, auth.value?.id]);
    useEffect(() {
      if (message.text != draft.message) message.text = draft.message;
      if (email.text != draft.replyEmail) email.text = draft.replyEmail;
      return null;
    }, [draft.message, draft.replyEmail]);
    final available = auth.value != null && isTv.value == false && !displayMode
        ? ref.watch(supportAvailableDiagnosticsProvider)
        : const <String, Object?>{};
    final diagnostics = draft.frozen
        ? draft.diagnostics
        : {...available, ...draft.diagnostics};
    final busy = draft.submitting || picking.value;
    final ticket = draft.ticket;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('문의하기'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/more'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                if (isTv.value == true || displayMode) ...[
                  Text(
                    '연결된 휴대폰이나 웹에서 문의해 주세요.',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '더보기 → 문의하기에서 연결된 TV의 설치 버전과 최근 준비 응답을 함께 보낼 수 있어요.',
                  ),
                ] else if (isTv.value == null || auth.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (auth.value == null) ...[
                  const Text('로그인 후 문의를 접수해 주세요. 문의와 첨부는 본인과 운영자만 확인할 수 있어요.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('로그인하기'),
                  ),
                  const SizedBox(height: 16),
                  const SelectableText(
                    '로그인할 수 없다면 ${AppLinks.supportEmail}으로 문의해 주세요.',
                  ),
                ] else if (ticket != null) ...[
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.accent,
                    size: 44,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '문의가 접수됐어요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    '문의 번호 ${ticket.number}',
                    textAlign: TextAlign.center,
                    key: const ValueKey('support-ticket-number'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    ticket.notificationStatus == 'sent'
                        ? '운영자 알림을 발송했어요. 답변은 입력한 이메일로 보내드려요.'
                        : '문의는 안전하게 저장됐어요. 운영자 알림 상태를 확인 중이에요. 다시 문의를 작성하지 않아도 됩니다.',
                  ),
                  const SizedBox(height: 12),
                  Text('답변받을 이메일: ${draft.replyEmail}'),
                  if (draft.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      draft.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (ticket.notificationStatus != 'sent')
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => controller.submit(available),
                      child: Text(busy ? '확인 중…' : '알림 상태 다시 확인'),
                    ),
                  FilledButton(
                    onPressed: busy ? null : controller.reset,
                    child: const Text('새 문의 작성'),
                  ),
                ] else
                  Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '어떤 문제가 있었나요?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '발생 상황을 알려주시면 확인 후 이메일로 답변드려요. 비밀번호나 인증번호는 적지 마세요.',
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('support-message'),
                          controller: message,
                          enabled: !busy,
                          minLines: 5,
                          maxLines: 10,
                          maxLength: supportMessageLimit,
                          decoration: const InputDecoration(
                            labelText: '발생 상황',
                            hintText: '어떤 화면에서 무엇을 하던 중 문제가 생겼나요?',
                            alignLabelWithHint: true,
                          ),
                          onChanged: controller.message,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '발생 상황을 입력해 주세요.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('support-email'),
                          controller: email,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          maxLength: 254,
                          decoration: const InputDecoration(
                            labelText: '답변받을 이메일',
                          ),
                          onChanged: controller.replyEmail,
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value.trim())
                              ? '이메일 주소를 확인해 주세요.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (draft.attachment case final attachment?) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              attachment.bytes,
                              key: const ValueKey('support-screenshot-preview'),
                              height: 200,
                              fit: BoxFit.contain,
                              cacheWidth: 1200,
                              errorBuilder: (_, _, _) => const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  '이미지를 표시할 수 없어요. 첨부를 제거한 뒤 다른 이미지를 선택해 주세요.',
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => controller.attachment(null),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('첨부 제거'),
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    picking.value = true;
                                    final owner = auth.value?.id;
                                    try {
                                      final selected = await ref
                                          .read(supportScreenshotPickerProvider)
                                          .pick();
                                      if (context.mounted &&
                                          ref
                                                  .read(authStateProvider)
                                                  .value
                                                  ?.id ==
                                              owner &&
                                          selected != null) {
                                        controller.attachment(selected);
                                      }
                                    } catch (error) {
                                      if (context.mounted &&
                                          ref
                                                  .read(authStateProvider)
                                                  .value
                                                  ?.id ==
                                              owner) {
                                        controller.localError(
                                          error is FormatException
                                              ? error
                                              : const FormatException(
                                                  '스크린샷을 선택하지 못했어요. 권한을 확인하거나 첨부 없이 문의를 보내 주세요.',
                                                ),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        picking.value = false;
                                      }
                                    }
                                  },
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              picking.value ? '스크린샷 확인 중…' : '스크린샷 첨부 · 선택',
                            ),
                          ),
                        const Text(
                          'PNG · JPG · WebP 1장, 5MB 이하. 개인정보가 보이지 않는지 미리 확인해 주세요.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 24),
                        _DiagnosticPreview(values: diagnostics),
                        const SizedBox(height: 16),
                        if (draft.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              draft.error!,
                              key: const ValueKey('support-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        FilledButton(
                          key: const ValueKey('support-submit'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: busy
                              ? null
                              : () {
                                  if (form.currentState?.validate() == true) {
                                    controller.submit(available);
                                  }
                                },
                          child: Text(
                            draft.submitting
                                ? '접수 확인 중…'
                                : draft.frozen
                                ? '같은 내용으로 다시 확인'
                                : '문의 접수하기',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '문의 내용과 선택한 스크린샷, 아래 표시된 진단 정보를 서버에 전송합니다. 앱을 종료하면 아직 접수하지 않은 작성 내용은 사라질 수 있어요.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticPreview extends StatelessWidget {
  const _DiagnosticPreview({required this.values});
  final Map<String, Object?> values;
  @override
  Widget build(BuildContext context) {
    final tvs = (values['tvs'] as List?) ?? const [];
    String value(String key) => values[key]?.toString() ?? '미확인';
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('함께 보낼 진단 정보'),
      subtitle: Text(
        '오류 ID ${value('errorId')} · ${values.containsKey('tvs') ? 'TV ${tvs.length}대' : 'TV 미확인'}',
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            '오류 ID: ${value('errorId')}\n발생 시각: ${values['occurredAtMs'] is int ? DateTime.fromMillisecondsSinceEpoch(values['occurredAtMs'] as int).toLocal() : '미확인'}\n'
            '작업: ${value('action')}\n앱: ${value('platform')} ${value('version')} (빌드 ${value('build')})\n'
            '${values.entries.where((entry) => !const {'errorId', 'occurredAtMs', 'action', 'platform', 'version', 'build', 'tvs'}.contains(entry.key)).map((entry) => '${entry.key}: ${entry.value}').join('\n')}\n'
            '${tvs.isEmpty ? '연결된 TV 진단: 미확인' : tvs.map((tv) => 'TV ${tv['deviceId']}: ${tv['appPlatform'] ?? '미확인'} ${tv['appVersion'] ?? '미확인'} (빌드 ${tv['appBuild'] ?? '미확인'})\n최근 준비 응답: ${tv['preparationStatus'] ?? '미확인'} · 시각 ${tv['checkedAtMs'] is int ? DateTime.fromMillisecondsSinceEpoch(tv['checkedAtMs'] as int).toLocal() : '미확인'}').join('\n')}',
          ),
        ),
        for (final tv in tvs)
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              tv.entries
                  .where(
                    (entry) => !const {
                      'deviceId',
                      'appPlatform',
                      'appVersion',
                      'appBuild',
                      'preparationStatus',
                      'checkedAtMs',
                    }.contains(entry.key),
                  )
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n'),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'TV 준비 응답은 기록된 시각의 정보이며 현재 준비 완료를 보장하지 않습니다. 확보하지 못한 정보는 전송하지 않습니다.',
        ),
      ],
    );
  }
}
