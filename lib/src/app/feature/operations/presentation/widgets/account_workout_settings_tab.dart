import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_settings_sheet.dart';

class AccountWorkoutSettingsTab extends ConsumerWidget {
  const AccountWorkoutSettingsTab({super.key, this.guard});
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authStateProvider).value;
    if (owner == null) return const Center(child: Text('로그인이 필요합니다.'));
    final provider = accountWorkoutPreferencesProvider(owner.id);
    return ref
        .watch(provider)
        .when(
          data: (settings) => _SettingsForm(
            key: ValueKey(owner.id),
            ownerId: owner.id,
            initial: settings,
            guard: guard,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('워크아웃 설정을 불러오지 못했습니다.'),
                TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
  }
}

class _SettingsForm extends HookConsumerWidget {
  const _SettingsForm({
    super.key,
    required this.ownerId,
    required this.initial,
    this.guard,
  });
  final ExitGuard? guard;
  final String ownerId;
  final WorkoutPreferences initial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final draft = useState(initial);
    final brandL = useTextEditingController(text: initial.brandL);
    final brandR = useTextEditingController(text: initial.brandR);
    useListenable(brandL);
    useListenable(brandR);
    final baseline = useState(initial);
    final current = draft.value.copyWith(
      brandL: brandL.text,
      brandR: brandR.text,
    );
    final provider = workoutPreferencesControllerProvider(ownerId);
    final action = ref.watch(provider);
    return UnsavedChangesGuard(
      guard: guard,
      dirty: current != baseline.value,
      blocked: action.isLoading,
      child: SingleChildScrollView(
        key: const PageStorageKey('account-workout-settings'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '계정 공통 워크아웃 설정',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  '저장하면 기존·신규 워크아웃 모두 다음 수업부터 적용됩니다. 진행 중인 수업은 그대로 유지됩니다.',
                ),
                const SizedBox(height: 24),
                AbsorbPointer(
                  absorbing: action.isLoading,
                  child: WorkoutSettingsContent(
                    draft: draft,
                    brandL: brandL,
                    brandR: brandR,
                  ),
                ),
                const SizedBox(height: 24),
                if (action.hasError) ...[
                  Text('${action.error}'),
                  TextButton(
                    onPressed: () async {
                      // Explicit reload; retain the user's draft for comparison/retry.
                      final latest = await ref.read(provider.notifier).reload();
                      if (!context.mounted || latest == null) return;
                      final replace = await showDialog<bool>(
                        context: context,
                        builder: (context) => AppAlertDialog(
                          title: const Text('최신 설정을 불러올까요?'),
                          content: const Text('현재 입력을 최신 저장된 설정으로 바꿉니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('불러오기'),
                            ),
                          ],
                        ),
                      );
                      if (!context.mounted || replace != true) return;
                      draft.value = latest;
                      baseline.value = latest;
                      brandL.text = latest.brandL;
                      brandR.text = latest.brandR;
                    },
                    child: const Text('최신 설정 다시 불러오기'),
                  ),
                ],
                FilledButton.icon(
                  onPressed: action.isLoading
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final saved = await ref
                              .read(provider.notifier)
                              .save(current);
                          if (!context.mounted) return;
                          if (saved != null) {
                            baseline.value = saved;
                            draft.value = saved;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                saved != null
                                    ? '계정 공통 설정을 저장했습니다. 다음 수업부터 적용됩니다.'
                                    : '저장하지 못했습니다. 연결과 로그인 상태를 확인하고 다시 시도해 주세요.',
                              ),
                            ),
                          );
                        },
                  icon: action.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(action.isLoading ? '저장 중…' : '공통 설정 저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
