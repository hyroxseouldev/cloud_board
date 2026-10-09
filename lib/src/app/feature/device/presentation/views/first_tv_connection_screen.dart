import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/add_display_dialog.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_verification.dart';

class FirstTvConnectionScreen extends ConsumerWidget {
  const FirstTvConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(firstClassScopeProvider);
    final devices = ref.watch(displayDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('TV 첫 연결')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '수업을 보여 줄 TV를 연결하세요',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('1')),
              title: Text('TV에서 CloudBoard 앱 열기'),
              subtitle: Text('TV를 인터넷에 연결하고 앱의 연결 대기 화면을 켜 두세요.'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('2')),
              title: Text('QR 스캔 또는 6자리 코드 입력'),
              subtitle: Text('현재 화면의 코드를 사용하세요. 만료되면 TV에서 새 코드를 만드세요.'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('3')),
              title: Text('이름과 확인 번호로 TV 확인'),
              subtitle: Text(
                '등록 뒤 소리 없는 확인 화면을 보냅니다. 원하는 TV의 번호가 맞으면 확인을 누르세요.',
              ),
            ),
            const SizedBox(height: 20),
            if (scope.value != null)
              FilledButton.icon(
                onPressed: () => showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AddDisplayDialog(),
                ),
                icon: const Icon(Icons.add),
                label: const Text('새 TV 연결하기'),
              )
            else if (scope.isLoading)
              const LinearProgressIndicator()
            else if (scope.hasError)
              TextButton(
                onPressed: () => ref.invalidate(firstClassScopeProvider),
                child: const Text('센터 정보를 불러오지 못했습니다 · 다시 확인'),
              )
            else
              const Text(
                '새 TV 등록은 센터 소유자에게 요청해 주세요. 이미 등록된 TV는 아래에서 확인할 수 있습니다.',
              ),
            const SizedBox(height: 24),
            Text('등록된 TV 확인', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (devices.isLoading) const LinearProgressIndicator(),
            if (devices.hasError)
              TextButton(
                onPressed: () => ref.invalidate(displayDevicesProvider),
                child: const Text('TV 목록 다시 불러오기'),
              ),
            if (devices.value?.isEmpty == true) const Text('아직 등록된 TV가 없습니다.'),
            for (final device in devices.value ?? [])
              Card(
                child: ListTile(
                  title: Text(device.name),
                  subtitle: Text(
                    '${device.zoneName} · ${device.online ? '온라인' : '오프라인'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AppAlertDialog(
                      title: const Text('TV 응답 확인'),
                      content: SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                          child: DisplayVerification(
                            deviceId: device.id,
                            onDone: () => Navigator.of(dialogContext).pop(),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('닫기'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/displays'),
              child: const Text('디스플레이 이름·구역 관리'),
            ),
          ],
        ),
      ),
    );
  }
}
