import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

class StoreOperationsScreen extends ConsumerWidget {
  const StoreOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('매장 운영'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(
              icon: Icon(Icons.branding_watermark_outlined),
              text: '브랜드·대기 화면',
            ),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: '예약 재생'),
            Tab(icon: Icon(Icons.connected_tv_rounded), text: '원격 관리'),
            Tab(icon: Icon(Icons.insights_rounded), text: '운영 리포트'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _BrandSettingsTab(),
          _ScheduleTab(),
          _RemoteDisplaysTab(),
          _ReportTab(),
        ],
      ),
    ),
  );
}

class _BrandSettingsTab extends HookConsumerWidget {
  const _BrandSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(brandTemplateProvider);
    final action = ref.watch(storeOperationsActionControllerProvider);
    final storeName = useTextEditingController();
    final message = useTextEditingController();
    final initialized = useRef(false);
    final draft = useState<BrandTemplate?>(null);

    useEffect(() {
      final value = settings.value;
      if (value != null && !initialized.value) {
        initialized.value = true;
        draft.value = value;
        storeName.text = value.storeName;
        message.text = value.standbyMessage;
      }
      return null;
    }, [settings.value]);

    Future<({Uint8List bytes, String extension})?> pickImage() async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 88,
      );
      if (image == null) return null;
      return (
        bytes: await image.readAsBytes(),
        extension: image.name.split('.').last,
      );
    }

    Future<void> uploadLogo() async {
      final picked = await pickImage();
      if (picked == null || draft.value == null) return;
      final url = await ref
          .read(storeOperationsActionControllerProvider.notifier)
          .uploadBrandImage(
            bytes: picked.bytes,
            extension: picked.extension,
            purpose: 'logo',
          );
      if (url != null) draft.value = draft.value!.copyWith(logoUrl: url);
    }

    return AsyncValueWidget<BrandTemplate>(
      value: settings,
      data: (_) {
        final value = draft.value;
        if (value == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionHeader(
                      title: '대기 화면 미리보기',
                      subtitle: '수업 전후와 쉬는 시간에 TV에 표시됩니다.',
                    ),
                    _StandbyPreview(
                      template: value.copyWith(
                        promotionImageUrls: settings.value!.promotionImageUrls,
                        promotionDurationMinutes:
                            settings.value!.promotionDurationMinutes,
                        standbyTransition: settings.value!.standbyTransition,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: storeName,
                      decoration: const InputDecoration(
                        labelText: '매장 이름',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: message,
                      decoration: const InputDecoration(
                        labelText: '대기 메시지',
                        prefixIcon: Icon(Icons.campaign_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '브랜드 색상',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          const [
                                0xFF0B50FF,
                                0xFF6750A4,
                                0xFFE53935,
                                0xFF00897B,
                                0xFFFF8F00,
                                0xFF202124,
                              ]
                              .map(
                                (color) => ChoiceChip(
                                  selected: value.primaryColorValue == color,
                                  showCheckmark: true,
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(color),
                                  ),
                                  label: Text(
                                    '#${color.toRadixString(16).substring(2).toUpperCase()}',
                                  ),
                                  onSelected: (_) => draft.value = value
                                      .copyWith(primaryColorValue: color),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 24),
                    _ImageSettingTile(
                      title: '매장 로고',
                      subtitle: value.logoUrl == null
                          ? '등록된 로고가 없습니다.'
                          : '대기 화면에 표시됩니다.',
                      imageUrl: value.logoUrl,
                      actionLabel: '로고 선택',
                      onPressed: action.isLoading ? null : uploadLogo,
                      onRemove: value.logoUrl == null
                          ? null
                          : () => draft.value = value.copyWith(logoUrl: null),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('대기 화면 이미지 · 전환 설정'),
                      subtitle: const Text('이미지 순서, 표시 시간, 전환 효과를 설정합니다.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/operations/standby'),
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('영업 종료 검은 화면'),
                      subtitle: Text(
                        value.blackScreenStartMinutes ==
                                value.blackScreenEndMinutes
                            ? '사용하지 않음'
                            : '${_minutesLabel(value.blackScreenStartMinutes)} ~ ${_minutesLabel(value.blackScreenEndMinutes)}',
                      ),
                      value:
                          value.blackScreenStartMinutes !=
                          value.blackScreenEndMinutes,
                      onChanged: (enabled) => draft.value = value.copyWith(
                        blackScreenStartMinutes: enabled ? 22 * 60 : 0,
                        blackScreenEndMinutes: enabled ? 6 * 60 : 0,
                      ),
                    ),
                    if (value.blackScreenStartMinutes !=
                        value.blackScreenEndMinutes)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: _toTime(
                                    value.blackScreenStartMinutes,
                                  ),
                                );
                                if (time != null) {
                                  draft.value = value.copyWith(
                                    blackScreenStartMinutes:
                                        time.hour * 60 + time.minute,
                                  );
                                }
                              },
                              child: Text(
                                '시작 ${_minutesLabel(value.blackScreenStartMinutes)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: _toTime(
                                    value.blackScreenEndMinutes,
                                  ),
                                );
                                if (time != null) {
                                  draft.value = value.copyWith(
                                    blackScreenEndMinutes:
                                        time.hour * 60 + time.minute,
                                  );
                                }
                              },
                              child: Text(
                                '종료 ${_minutesLabel(value.blackScreenEndMinutes)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: action.isLoading
                          ? null
                          : () async {
                              final latest =
                                  ref.read(brandTemplateProvider).value ??
                                  value;
                              final updated = value.copyWith(
                                promotionImageUrls: latest.promotionImageUrls,
                                promotionDurationMinutes:
                                    latest.promotionDurationMinutes,
                                standbyTransition: latest.standbyTransition,
                                storeName: storeName.text.trim(),
                                standbyMessage: message.text.trim(),
                              );
                              draft.value = updated;
                              await ref
                                  .read(
                                    storeOperationsActionControllerProvider
                                        .notifier,
                                  )
                                  .saveBrandTemplate(updated);
                            },
                      icon: action.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('브랜드·대기 화면 저장'),
                    ),
                    if (action.hasError) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${action.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(workoutSchedulesProvider);
    final workouts =
        ref.watch(workoutControllerProvider).value ?? const <Workout>[];
    final devices =
        ref.watch(displayDevicesProvider).value ?? const <DisplayDevice>[];
    return Scaffold(
      body: AsyncValueWidget<List<WorkoutSchedule>>(
        value: schedules,
        data: (items) => items.isEmpty
            ? const _EmptyState(
                icon: Icons.event_available_outlined,
                title: '예약된 수업이 없습니다',
                subtitle: '요일과 시간을 정하면 온라인 디스플레이에서 자동으로 시작됩니다.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          '${item.hour.toString().padLeft(2, '0')}:${item.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      title: Text(
                        item.workoutName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_weekdaysLabel(item.weekdays)} · ${item.targetDeviceIds.isEmpty ? '모든 온라인 디스플레이' : '${item.targetDeviceIds.length}대'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: item.enabled,
                            onChanged: (enabled) => ref
                                .read(
                                  storeOperationsActionControllerProvider
                                      .notifier,
                                )
                                .saveSchedule(item.copyWith(enabled: enabled)),
                          ),
                          IconButton(
                            tooltip: '예약 삭제',
                            onPressed: () => ref
                                .read(
                                  storeOperationsActionControllerProvider
                                      .notifier,
                                )
                                .deleteSchedule(item.id),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: workouts.isEmpty
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (_) =>
                    _ScheduleDialog(workouts: workouts, devices: devices),
              ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('예약 추가'),
      ),
    );
  }
}

class _ScheduleDialog extends HookConsumerWidget {
  const _ScheduleDialog({required this.workouts, required this.devices});

  final List<Workout> workouts;
  final List<DisplayDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutId = useState(workouts.first.id);
    final weekdays = useState<Set<int>>({1, 2, 3, 4, 5});
    final time = useState(const TimeOfDay(hour: 9, minute: 0));
    final targets = useState<Set<String>>({});
    final action = ref.watch(storeOperationsActionControllerProvider);
    return AlertDialog(
      title: const Text('예약 재생 추가'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: workoutId.value,
                decoration: const InputDecoration(labelText: '워크아웃'),
                items: workouts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) workoutId.value = value;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '반복 요일',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  return FilterChip(
                    label: Text(_weekdayNames[index]),
                    selected: weekdays.value.contains(day),
                    onSelected: (selected) {
                      final next = Set<int>.from(weekdays.value);
                      selected ? next.add(day) : next.remove(day);
                      weekdays.value = next;
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: time.value,
                  );
                  if (selected != null) time.value = selected;
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text('시작 시간 ${time.value.format(context)}'),
              ),
              const SizedBox(height: 18),
              const Text(
                '재생 디스플레이',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text('선택하지 않으면 시작 시 온라인인 모든 디스플레이에서 재생합니다.'),
              ...devices.map(
                (device) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name),
                  subtitle: Text(device.zoneName),
                  value: targets.value.contains(device.id),
                  onChanged: (selected) {
                    final next = Set<String>.from(targets.value);
                    selected == true
                        ? next.add(device.id)
                        : next.remove(device.id);
                    targets.value = next;
                  },
                ),
              ),
              if (action.hasError)
                Text(
                  '${action.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('취소')),
        FilledButton(
          onPressed: action.isLoading || weekdays.value.isEmpty
              ? null
              : () async {
                  final workout = workouts.firstWhere(
                    (item) => item.id == workoutId.value,
                  );
                  final id =
                      'schedule-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
                  final saved = await ref
                      .read(storeOperationsActionControllerProvider.notifier)
                      .saveSchedule(
                        WorkoutSchedule(
                          id: id,
                          workoutId: workout.id,
                          workoutName: workout.name,
                          weekdays: weekdays.value.toList()..sort(),
                          hour: time.value.hour,
                          minute: time.value.minute,
                          targetDeviceIds: targets.value.toList(),
                          enabled: true,
                          lastOccurrenceKey: null,
                          createdAtMs: DateTime.now().millisecondsSinceEpoch,
                        ),
                      );
                  if (saved && context.mounted) context.pop();
                },
          child: const Text('예약 저장'),
        ),
      ],
    );
  }
}

class _RemoteDisplaysTab extends ConsumerWidget {
  const _RemoteDisplaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    return AsyncValueWidget<List<DisplayDevice>>(
      value: devices,
      data: (items) => items.isEmpty
          ? const _EmptyState(
              icon: Icons.tv_off_outlined,
              title: '연결된 디스플레이가 없습니다',
              subtitle: '홈 화면의 TV 아이콘에서 디스플레이를 먼저 연결해 주세요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _RemoteDisplayCard(device: items[index]),
            ),
    );
  }
}

class _RemoteDisplayCard extends ConsumerWidget {
  const _RemoteDisplayCard({required this.device});

  final DisplayDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.circle,
              size: 13,
              color: device.online ? Colors.green : Colors.grey,
            ),
            title: Text(
              device.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${device.zoneName} · ${device.online ? '온라인' : '오프라인'} · ${_displayStateLabel(device.displayState)}',
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'auto',
                icon: Icon(Icons.play_circle_outline),
                label: Text('자동'),
              ),
              ButtonSegment(
                value: 'standby',
                icon: Icon(Icons.wallpaper_rounded),
                label: Text('대기'),
              ),
              ButtonSegment(
                value: 'black',
                icon: Icon(Icons.brightness_1_rounded),
                label: Text('검은 화면'),
              ),
            ],
            selected: {device.displayState},
            onSelectionChanged: device.online
                ? (selected) => ref
                      .read(deviceClaimControllerProvider.notifier)
                      .setDisplayState(
                        deviceId: device.id,
                        displayState: selected.first,
                      )
                : null,
          ),
        ],
      ),
    ),
  );
}

class _ReportTab extends ConsumerWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(operationsReportProvider);
    final events = ref.watch(operationEventsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: '오늘 수업',
              value: '${report.todayPlaybackCount}회',
              icon: Icons.today_rounded,
            ),
            _MetricCard(
              label: '이번 달 수업',
              value: '${report.monthPlaybackCount}회',
              icon: Icons.calendar_month_rounded,
            ),
            _MetricCard(
              label: '예약 정시 시작',
              value: report.scheduledPlaybackCount == 0
                  ? '-'
                  : '${(report.onTimePlaybackCount / report.scheduledPlaybackCount * 100).round()}%',
              icon: Icons.timer_outlined,
            ),
            _MetricCard(
              label: '온라인 누적',
              value: _durationLabel(report.onlineDuration),
              icon: Icons.wifi_rounded,
            ),
            _MetricCard(
              label: '연결 끊김',
              value: '${report.disconnectCount}회',
              icon: Icons.wifi_off_rounded,
            ),
            _MetricCard(
              label: '최다 워크아웃',
              value: report.mostPlayedWorkoutName == null
                  ? '-'
                  : '${report.mostPlayedWorkoutName}\n${report.mostPlayedWorkoutCount}회',
              icon: Icons.star_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SectionHeader(
          title: '최근 운영 기록',
          subtitle: '최대 1,000개의 최근 이벤트를 기준으로 계산합니다.',
        ),
        events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('운영 기록을 불러오지 못했습니다. $error'),
          data: (items) => items.isEmpty
              ? const Text('아직 기록이 없습니다. 수업을 시작하면 자동으로 쌓입니다.')
              : Column(children: items.take(30).map(_EventTile.new).toList()),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);
  final OperationEvent event;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs);
    final title = switch (event.type) {
      'playback_started' => '${event.workoutName ?? '워크아웃'} 재생 시작',
      'playback_completed' => '${event.workoutName ?? '워크아웃'} 재생 종료',
      'device_online' => '디스플레이 연결됨',
      'device_offline' => '디스플레이 연결 끊김',
      _ => event.type,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        event.type.contains('device')
            ? Icons.connected_tv_rounded
            : Icons.play_circle_outline_rounded,
      ),
      title: Text(title),
      subtitle: Text(
        '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}${event.scheduled ? ' · 예약 재생' : ''}',
      ),
    );
  }
}

class _StandbyPreview extends HookWidget {
  const _StandbyPreview({required this.template});
  final BrandTemplate template;

  @override
  Widget build(BuildContext context) {
    final now = useState(DateTime.now());
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      return timer.cancel;
    }, const []);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: StoreWelcomeBoard(brand: template, now: now.value),
      ),
    );
  }
}

class _ImageSettingTile extends StatelessWidget {
  const _ImageSettingTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.actionLabel,
    required this.onPressed,
    required this.onRemove,
  });
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String actionLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: imageUrl == null
        ? const CircleAvatar(child: Icon(Icons.image_outlined))
        : CircleAvatar(backgroundImage: NetworkImage(imageUrl!)),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Wrap(
      children: [
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        TextButton(onPressed: onPressed, child: Text(actionLabel)),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    height: 130,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

String _weekdaysLabel(List<int> days) =>
    days.map((day) => _weekdayNames[day - 1]).join('·');
String _minutesLabel(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
TimeOfDay _toTime(int value) =>
    TimeOfDay(hour: value ~/ 60, minute: value % 60);
String _displayStateLabel(String value) => switch (value) {
  'standby' => '대기 화면',
  'black' => '검은 화면',
  _ => '자동 재생',
};
String _durationLabel(Duration duration) {
  if (duration.inMinutes < 60) return '${duration.inMinutes}분';
  return '${duration.inHours}시간 ${duration.inMinutes.remainder(60)}분';
}
