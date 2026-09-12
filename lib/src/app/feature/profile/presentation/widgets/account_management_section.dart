import 'package:cloud_board/src/app/feature/profile/domain/repositories/account_deletion_repository.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/controllers/account_deletion_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';

const accountSupportEmail = 'vividxxxxx@gmail.com';
const _policyBase = 'https://clyr-landing-20.vercel.app/apps/cloudboard';

Future<bool> _openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opening an information page does not mutate auth, profile or playback state.
class AccountManagementSection extends HookConsumerWidget {
  const AccountManagementSection({super.key, this.openLink = _openExternal});

  final Future<bool> Function(Uri) openLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(androidTvProvider);
    final opening = useState(false);
    final deletion = ref.watch(accountDeletionControllerProvider);
    final processing = deletion.value == AccountDeletionResult.processing;
    final deleting = deletion.isLoading || processing;
    // Wait for platform detection; TV must never launch a mobile browser flow.
    if (isTv.value != false) return const SizedBox.shrink();

    Future<void> open(String path) async {
      if (opening.value) return;
      opening.value = true;
      var launched = false;
      try {
        launched = await openLink(Uri.parse('$_policyBase/$path'));
      } catch (_) {
        // Platform errors follow the same honest fallback as a false result.
      }
      if (!context.mounted) return;
      opening.value = false;
      if (launched) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('안내 페이지를 열 수 없습니다'),
          content: const SelectableText(
            '안내 페이지를 열 수 없습니다. 잠시 후 다시 시도하거나 '
            '$accountSupportEmail'
            '으로 문의해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await Clipboard.setData(
                    const ClipboardData(text: accountSupportEmail),
                  );
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이메일 주소를 복사했습니다.')),
                  );
                } catch (_) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('복사하지 못했습니다. 이메일 주소를 길게 눌러 복사해 주세요.'),
                    ),
                  );
                }
              },
              child: const Text('이메일 주소 복사'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
    }

    Future<void> requestDeletion() async {
      if (deleting) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('클라우드보드 계정을 삭제할까요?'),
          content: const Text(
            '프로필, 워크아웃, 업로드 파일, 매장 설정과 연결 기기 정보를 삭제하고 진행 중인 수업을 종료합니다. 삭제한 콘텐츠는 복구할 수 없습니다.\n\n'
            'Google 계정 자체는 삭제되지 않습니다. 본인 확인 후 실제 삭제가 시작됩니다. 백업과 삭제 처리 기록의 보관 기간은 개인정보처리방침을 따릅니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('본인 확인 후 삭제'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref
            .read(accountDeletionControllerProvider.notifier)
            .deleteAccount();
      }
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('계정 관리', style: AppStyle.of(context).subText2),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_remove_outlined),
              title: Text(
                processing
                    ? '계정 삭제 처리 중…'
                    : deleting
                    ? '본인 확인 및 삭제 처리 중…'
                    : '계정 삭제',
              ),
              subtitle: const Text('클라우드보드 계정과 관련 데이터를 삭제합니다.'),
              trailing: deletion.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      processing
                          ? Icons.hourglass_top_rounded
                          : Icons.chevron_right_rounded,
                    ),
              enabled: !opening.value && !deleting,
              onTap: requestDeletion,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('계정 삭제 안내 및 문의'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              enabled: !opening.value && !deleting,
              onTap: () => open('delete-account'),
            ),
            if (processing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SelectableText(AccountDeletionResult.processing.message),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('개인정보처리방침'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              enabled: !opening.value,
              onTap: () => open('privacy'),
            ),
          ],
        ),
      ),
    );
  }
}
