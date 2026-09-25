import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/onboarding_controller.dart';

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key, this.editing = false, this.guard});
  final ExitGuard? guard;
  final bool editing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(onboardingControllerProvider);
    return Scaffold(
      body: AsyncValueWidget<CenterOnboarding>(
        value: progress,
        onRetry: () => ref.invalidate(onboardingControllerProvider),
        data: (data) => data.phoneRequired
            ? const _PhoneVerification()
            : _OnboardingForm(
                key: ValueKey(data.storeId),
                initial: data,
                editing: editing,
                guard: guard,
              ),
      ),
    );
  }
}

class _PhoneVerification extends HookConsumerWidget {
  const _PhoneVerification();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = useTextEditingController(), code = useTextEditingController();
    final sent = useState(false), remaining = useState(0);
    final action = ref.watch(onboardingActionProvider);
    final actions = ref.read(onboardingActionProvider.notifier);
    useEffect(() {
      if (remaining.value <= 0) return null;
      final timer = Timer(const Duration(seconds: 1), () => remaining.value--);
      return timer.cancel;
    }, [remaining.value]);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudBoard'),
        leading: IconButton(
          tooltip: '뒤로',
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: action.isLoading
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    ref.read(authControllerProvider.notifier).signOut();
                  }
                },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 32),
              const Text(
                '반가워요!\n휴대폰 번호를 확인할게요.',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '센터 계정을 안전하게 연결하기 위한 인증이에요.\n인증만으로 무료 체험이 시작되지는 않아요.',
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: phone,
                enabled: !action.isLoading && !sent.value,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                decoration: const InputDecoration(
                  labelText: '휴대폰 번호',
                  hintText: '010 1234 5678',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: action.isLoading || remaining.value > 0
                    ? null
                    : () async {
                        if (await actions.sendCode(phone.text) &&
                            context.mounted) {
                          sent.value = true;
                          remaining.value = 60;
                        }
                      },
                child: Text(
                  remaining.value > 0
                      ? '${remaining.value}초 후 재전송'
                      : sent.value
                      ? '인증번호 다시 받기'
                      : '인증번호 받기',
                ),
              ),
              if (sent.value) ...[
                TextButton(
                  onPressed: action.isLoading
                      ? null
                      : () {
                          sent.value = false;
                          code.clear();
                        },
                  child: const Text('번호 수정'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  enabled: !action.isLoading,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '인증번호',
                    helperText: '문자로 받은 6자리 · 5분 이내 입력',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: action.isLoading
                      ? null
                      : () => actions.verifyCode(code.text),
                  child: const Text('인증하고 계속하기'),
                ),
              ],
              if (action.isLoading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (action.hasError) _ErrorText(action.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingForm extends HookConsumerWidget {
  const _OnboardingForm({
    super.key,
    required this.initial,
    required this.editing,
    this.guard,
  });
  final ExitGuard? guard;
  final CenterOnboarding initial;
  final bool editing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = useState(initial.profile);
    final step = useState(editing ? 1 : initial.step.clamp(0, 3));
    final latest = ref.watch(onboardingControllerProvider).value ?? initial;
    final action = ref.watch(onboardingActionProvider);
    final actions = ref.read(onboardingActionProvider.notifier);
    final busy = action.isLoading;
    final scroll = useScrollController();
    void move(int value) {
      step.value = value;
      if (scroll.hasClients) scroll.jumpTo(0);
    }

    Future<bool> save(int value, {String action = 'save'}) async {
      FocusScope.of(context).unfocus();
      final ok = await actions.save(profile.value, value, action: action);
      if (ok && context.mounted) {
        profile.value = ref
            .read(onboardingControllerProvider)
            .requireValue
            .profile;
      }
      return ok;
    }

    Future<void> later() async {
      if (await save(step.value, action: 'defer') && context.mounted) {
        context.go('/');
      }
    }

    Future<void> next() async {
      if (step.value == 1 && !profile.value.isComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('담당자 역할·센터명·센터 유형·지역을 입력해 주세요.')),
        );
        return;
      }
      if (await save(step.value + 1) && context.mounted) move(step.value + 1);
    }

    Future<void> finish({required bool trial}) async {
      if (!await save(2)) return;
      if (trial && !await actions.startTrial()) return;
      if (await save(3, action: 'complete') && context.mounted) move(3);
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: profile.value != latest.profile,
      blocked: busy,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: step.value > 0 && step.value < 3
              ? IconButton(
                  tooltip: '이전',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: busy ? null : () => move(step.value - 1),
                )
              : null,
          title: const Text('CloudBoard'),
          actions: [
            if (step.value < 3)
              TextButton(
                onPressed: busy ? null : later,
                child: const Text('나중에'),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    children: [
                      if (step.value < 3) ...[
                        Row(
                          children: List.generate(
                            3,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: Container(
                                width: 28,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: index <= step.value
                                      ? AppColors.accent
                                      : AppColors.line,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                      if (step.value == 0) ...[
                        const _Heading(
                          '어떻게 시작하고 싶으세요?',
                          '선택에 맞춰 첫 사용을 안내해 드릴게요.',
                        ),
                        const SizedBox(height: 26),
                        _PurposeChoices(
                          value: profile.value.purpose,
                          onChanged: busy
                              ? null
                              : (value) =>
                                    profile.value = profile.value.copyWith(
                                      purpose: value,
                                      undecidedName: value == 'operating'
                                          ? false
                                          : profile.value.undecidedName,
                                      undecidedRegion: value == 'operating'
                                          ? false
                                          : profile.value.undecidedRegion,
                                    ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '선택은 나중에 바꿀 수 있어요.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ] else if (step.value == 1) ...[
                        _Heading(
                          editing ? '센터 정보를 수정해요' : '센터를 조금 알려주세요',
                          profile.value.purpose == 'operating'
                              ? '첫 수업을 준비하는 데 필요한 정보만 받아요.'
                              : '준비 중인 정보는 미정으로 남겨도 괜찮아요.',
                        ),
                        const SizedBox(height: 24),
                        _CenterFields(
                          profile: profile.value,
                          onChanged: (value) => profile.value = value,
                          enabled: !busy,
                        ),
                      ] else if (step.value == 2) ...[
                        _Heading(
                          latest.hasAccess
                              ? '이미 이용 중인 권한이 있어요'
                              : latest.trialEligible
                              ? '우리 센터에서\n1개월 무료로 시작해요'
                              : '기존 이용 내역을 확인했어요',
                          latest.trialEligible && !latest.hasAccess
                              ? '카드 등록 없이 준비하고, 내 기기로 먼저 살펴보세요.'
                              : '기존 이용 기간은 그대로 유지해요. 센터 설정을 마치고 시작해 보세요.',
                        ),
                        const SizedBox(height: 26),
                        for (final item in [
                          '워크아웃과 슬라이드 만들기',
                          '타이머·효과음과 원격 수업 제어',
                          '디스플레이·즐겨찾기 수 제한 없는 프리미엄',
                        ])
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.accent,
                            ),
                            title: Text(item),
                          ),
                        const SizedBox(height: 20),
                        if (latest.trialStartedAtMs > 0 ||
                            (latest.trialEligible && !latest.hasAccess))
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latest.trialStartedAtMs > 0
                                      ? '기존 체험 기간'
                                      : '지금 시작하면',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_date(latest.trialStartedAtMs > 0 ? latest.trialStartedAtMs : latest.serverNowMs)} →\n${_date(latest.trialEndsAtMs > 0 ? latest.trialEndsAtMs : latest.suggestedTrialEndsAtMs)} (한국 시간)',
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '시작 버튼을 누른 서버 시각부터 달력 기준 1개월이에요. 기존 체험·유료 이용 기간은 변경하지 않아요.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          '체험이 끝나도 자동 결제되지 않아요. 만든 워크아웃은 그대로 남고 편집·미리보기를 계속할 수 있어요. 새 수업 송출에는 유효한 이용권이 필요해요.',
                          style: TextStyle(color: AppColors.muted, height: 1.6),
                        ),
                      ] else ...[
                        const SizedBox(height: 35),
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.accent,
                          size: 58,
                        ),
                        const SizedBox(height: 24),
                        _Heading(
                          profile.value.purpose == 'preparing'
                              ? '센터의 첫 수업을 준비해요!'
                              : '이제 시작할 준비가 됐어요!',
                          '센터 정보는 프로필에서 언제든 수정할 수 있어요.',
                        ),
                        const SizedBox(height: 28),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SlideRehearsalScreen(
                                module:
                                    WorkoutModule.empty('onboarding-example')
                                        .copyWith(
                                          name: '첫 수업 · 스쿼트',
                                          text: '발을 어깨너비로 벌리고\n천천히 앉았다 일어나세요.',
                                          workSeconds: 30,
                                          restSeconds: 10,
                                          sets: 3,
                                          beep: false,
                                        ),
                                brandL: profile.value.centerName.isEmpty
                                    ? 'CloudBoard'
                                    : profile.value.centerName,
                                brandR: '예시 수업',
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('예시 수업 미리보기'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.go('/');
                            context.push('/displays');
                          },
                          icon: const Icon(Icons.connected_tv_rounded),
                          label: const Text('디스플레이 연결하기'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          latest.trialStartedAtMs > 0
                              ? '체험 종료: ${_date(latest.trialEndsAtMs)} (한국 시간)'
                              : latest.trialEligible && !latest.hasAccess
                              ? '체험은 프로필에서 나중에 시작할 수 있어요.'
                              : '이용 상태는 프로필에서 확인할 수 있어요.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      if (action.hasError) ...[
                        _ErrorText(action.error),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await actions.reload() &&
                                      context.mounted) {
                                    final loaded = ref
                                        .read(onboardingControllerProvider)
                                        .requireValue;
                                    profile.value = loaded.profile;
                                    move(loaded.step.clamp(0, 3));
                                  }
                                },
                          child: const Text('저장된 정보 다시 불러오기'),
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step.value == 0)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: Text(
                              '1개월 무료 체험 · 카드 등록 없이',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed:
                              busy ||
                                  (step.value == 0 &&
                                      profile.value.purpose == null)
                              ? null
                              : () {
                                  if (step.value < 2) {
                                    next();
                                  } else if (step.value == 2) {
                                    finish(
                                      trial:
                                          latest.trialEligible &&
                                          !latest.hasAccess,
                                    );
                                  } else {
                                    context.go('/');
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  step.value < 2
                                      ? '다음'
                                      : step.value == 2
                                      ? ((!latest.trialEligible ||
                                                latest.hasAccess)
                                            ? '센터 설정 마치기'
                                            : '1개월 무료로 시작하기')
                                      : '홈으로 가기',
                                ),
                        ),
                        if (step.value == 0)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              '체험은 준비를 마친 뒤 직접 시작할 수 있어요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        if (step.value == 2 &&
                            latest.trialEligible &&
                            !latest.hasAccess)
                          TextButton(
                            onPressed: busy ? null : () => finish(trial: false),
                            child: const Text('체험은 나중에 시작하기'),
                          ),
                      ],
                    ),
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

class _PurposeChoices extends StatelessWidget {
  const _PurposeChoices({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'operating',
        Icons.desktop_windows_outlined,
        '운영 중인 센터에 연결하기',
        '디스플레이를 연결하고 수업을 준비해요.',
      ),
      (
        'preparing',
        Icons.calendar_month_outlined,
        '오픈할 센터 준비하기',
        '워크아웃과 대기화면을 미리 구성해요.',
      ),
      (
        'exploring',
        Icons.play_circle_outline_rounded,
        '먼저 둘러보기',
        '디스플레이 없이 예시 수업을 살펴봐요.',
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0 && value != item.$1 && value != items[index - 1].$1)
              const Divider(height: 1, indent: 16, endIndent: 16),
            Semantics(
              button: true,
              selected: value == item.$1,
              child: Material(
                color: value == item.$1
                    ? AppColors.surface
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: value == item.$1
                        ? AppColors.accent
                        : Colors.transparent,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onChanged == null ? null : () => onChanged!(item.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.$2,
                          size: 28,
                          color: value == item.$1
                              ? AppColors.ink
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$3,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.$4,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          value == item.$1
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: value == item.$1
                              ? AppColors.accent
                              : AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenterFields extends HookWidget {
  const _CenterFields({
    required this.profile,
    required this.onChanged,
    required this.enabled,
  });
  final CenterProfile profile;
  final ValueChanged<CenterProfile> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: profile.centerName),
        province = useTextEditingController(text: profile.province),
        district = useTextEditingController(text: profile.district);
    final floorArea = useTextEditingController(text: profile.floorArea);
    Widget choices(
      String title,
      Map<String, String> options,
      String? selected,
      ValueChanged<String> change,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in options.entries)
                ChoiceChip(
                  label: Text(item.value),
                  selected: item.key == selected,
                  onSelected: enabled ? (_) => change(item.key) : null,
                ),
            ],
          ),
        ],
      ),
    );
    Widget multi(
      String title,
      Map<String, String> options,
      List<String> selected,
      ValueChanged<List<String>> change, {
      int? max,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final item in options.entries)
                FilterChip(
                  label: Text(item.value),
                  selected: selected.contains(item.key),
                  onSelected:
                      !enabled ||
                          (!selected.contains(item.key) &&
                              max != null &&
                              selected.length >= max)
                      ? null
                      : (v) => change(
                          v
                              ? [...selected, item.key]
                              : selected.where((x) => x != item.key).toList(),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        choices(
          '담당자 역할',
          const {'owner': '대표', 'manager': '매니저', 'coach': '코치', 'other': '기타'},
          profile.role,
          (v) => onChanged(profile.copyWith(role: v)),
        ),
        TextField(
          controller: name,
          enabled: enabled && !profile.undecidedName,
          maxLength: 100,
          decoration: const InputDecoration(labelText: '센터명', counterText: ''),
          onChanged: (v) => onChanged(profile.copyWith(centerName: v)),
        ),
        if (profile.purpose != 'operating')
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('센터명 미정'),
            value: profile.undecidedName,
            onChanged: enabled
                ? (v) => onChanged(profile.copyWith(undecidedName: v!))
                : null,
          ),
        const SizedBox(height: 22),
        const Text(
          '센터 유형 · 복수 선택',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final item in const {
              'functional': '크로스핏·기능성 운동',
              'group': '그룹 트레이닝',
              'gym': 'PT·헬스',
              'pilates': '필라테스·요가',
              'other': '기타',
            }.entries)
              FilterChip(
                label: Text(item.value),
                selected: profile.centerTypes.contains(item.key),
                onSelected: enabled
                    ? (v) => onChanged(
                        profile.copyWith(
                          centerTypes: v
                              ? [...profile.centerTypes, item.key]
                              : profile.centerTypes
                                    .where((t) => t != item.key)
                                    .toList(),
                        ),
                      )
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 22),
        TextField(
          controller: province,
          enabled: enabled && !profile.undecidedRegion,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: '시·도',
            hintText: '예: 서울특별시',
            counterText: '',
          ),
          onChanged: (v) => onChanged(profile.copyWith(province: v)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: district,
          enabled: enabled && !profile.undecidedRegion,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: '시·군·구',
            hintText: '예: 강남구',
            counterText: '',
          ),
          onChanged: (v) => onChanged(profile.copyWith(district: v)),
        ),
        if (profile.purpose != 'operating')
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('지역 미정'),
            value: profile.undecidedRegion,
            onChanged: enabled
                ? (v) => onChanged(profile.copyWith(undecidedRegion: v!))
                : null,
          ),
        const SizedBox(height: 24),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('수업 환경 · 선택'),
          subtitle: const Text('나중에 입력해도 괜찮아요'),
          children: [
            multi(
              '주로 운영하는 수업',
              const {
                'pt': '개인 PT',
                'group': '그룹 수업',
                'circuit': '서킷',
                'open': '자율 운동',
                'other': '기타',
              },
              profile.classTypes,
              (v) => onChanged(profile.copyWith(classTypes: v)),
            ),
            multi(
              '현재 안내 방식',
              const {
                'voice': '구두',
                'whiteboard': '화이트보드',
                'tv': 'TV 이미지·영상',
                'timer': '타이머 앱',
                'other': '기타',
              },
              profile.guidance,
              (v) => onChanged(profile.copyWith(guidance: v)),
            ),
            multi(
              '가장 필요한 기능 · 최대 2개',
              const {
                'instructions': '운동 화면 안내',
                'timer': '타이머·효과음',
                'remote': '원격 제어',
                'standby': '대기화면',
              },
              profile.priorities,
              (v) => onChanged(profile.copyWith(priorities: v)),
              max: 2,
            ),
            multi(
              '컨트롤 기기',
              const {'phone': '휴대폰', 'tablet': '태블릿', 'pc': 'PC'},
              profile.controllers,
              (v) => onChanged(profile.copyWith(controllers: v)),
            ),
            TextField(
              controller: floorArea,
              enabled: enabled,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '센터 면적 · 선택',
                hintText: '예: 100평 / 미정',
              ),
              onChanged: (v) => onChanged(profile.copyWith(floorArea: v)),
            ),
            const SizedBox(height: 16),
            for (final field in environmentFields)
              choices(
                field.$2,
                field.$3,
                profile.environment[field.$1],
                (v) => onChanged(
                  profile.copyWith(
                    environment: {...profile.environment, field.$1: v},
                    environmentSkipped: false,
                  ),
                ),
              ),
            TextButton(
              onPressed: enabled
                  ? () => onChanged(
                      profile.copyWith(
                        environment: {},
                        environmentSkipped: true,
                      ),
                    )
                  : null,
              child: const Text('선택 정보 건너뛰기'),
            ),
          ],
        ),
      ],
    );
  }
}

const environmentFields = [
  (
    'branches',
    '운영 지점 수',
    {'1': '1개', '2-3': '2~3개', '4+': '4개 이상', 'unknown': '미정'},
  ),
  ('rooms', '수업 공간 수', {'1': '1개', '2': '2개', '3+': '3개 이상', 'unknown': '미정'}),
  (
    'classSize',
    '한 수업의 평균 인원',
    {
      '1-5': '1~5명',
      '6-10': '6~10명',
      '11-20': '11~20명',
      '21+': '21명 이상',
      'unknown': '미정',
    },
  ),
  (
    'coaches',
    '운영 코치 수',
    {'1': '1명', '2-5': '2~5명', '6+': '6명 이상', 'unknown': '미정'},
  ),
  (
    'classDuration',
    '일반적인 수업 시간',
    {'30': '30분', '45': '45분', '60': '60분', 'unknown': '미정'},
  ),
  (
    'displays',
    '사용할 디스플레이',
    {'1': '1대', '2': '2대', '3+': '3대 이상', 'unknown': '미정'},
  ),
  (
    'displayType',
    '디스플레이 환경',
    {'tv': '스마트 TV', 'pc': 'PC 연결 화면', 'tablet': '태블릿', 'unknown': '잘 모르겠음'},
  ),
  (
    'sound',
    '소리 출력',
    {'tv': 'TV', 'speaker': '별도 스피커', 'controller': '컨트롤 기기', 'unknown': '미정'},
  ),
];

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      ),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object? error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      error.toString().replaceFirst('Bad state: ', ''),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String _date(int milliseconds) {
  if (milliseconds <= 0) return '시작 시 확인';
  final d = DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).add(const Duration(hours: 9));
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
