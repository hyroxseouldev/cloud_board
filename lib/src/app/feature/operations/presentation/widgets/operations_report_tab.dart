import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history_filters.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/operation_event_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OperationsReportTab extends HookConsumerWidget {
  const OperationsReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = useMemoized(
      () => centerDateTime(DateTime.now().millisecondsSinceEpoch),
    );
    final range = useState(
      OperationEventRange(
        startAtMs: centerDayStartMs(today),
        endBeforeMs: centerDayStartMs(today.add(const Duration(days: 1))),
      ),
    );
    final preset = useState<int?>(1);
    final device = useState<String?>(null);
    final workout = useState<String?>(null);
    final type = useState<String?>(null);
    final visibleCount = useState(50);
    final source = operationEventsInRangeProvider(range.value);
    final batch = ref.watch(source);
    useEffect(() {
      visibleCount.value = 50;
      return null;
    }, [range.value, device.value, workout.value, type.value]);

    void selectRange(OperationEventRange value, int? days) {
      preset.value = days;
      range.value = value;
      device.value = null;
      workout.value = null;
      type.value = null;
    }

    useEffect(() {
      if (preset.value == null) return null;
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextDay = centerDayStartMs(
        centerDateTime(now).add(const Duration(days: 1)),
      );
      final timer = Timer(Duration(milliseconds: nextDay - now + 50), () {
        if (!context.mounted || preset.value == null) return;
        final current = centerDateTime(DateTime.now().millisecondsSinceEpoch);
        range.value = OperationEventRange(
          startAtMs: centerDayStartMs(
            current.subtract(Duration(days: preset.value! - 1)),
          ),
          endBeforeMs: centerDayStartMs(current.add(const Duration(days: 1))),
        );
      });
      return timer.cancel;
    }, [preset.value, range.value]);

    Future<void> customRange() async {
      final current = centerDateTime(DateTime.now().millisecondsSinceEpoch);
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(current.year, current.month, current.day),
        initialDateRange: DateTimeRange(
          start: centerDateTime(range.value.startAtMs),
          end: centerDateTime(range.value.endBeforeMs - 1),
        ),
        helpText: '조회 기간 선택 · 한국 시간',
        saveText: '조회',
      );
      if (picked != null && context.mounted) {
        selectRange(
          OperationEventRange(
            startAtMs: centerDayStartMs(picked.start),
            endBeforeMs: centerDayStartMs(
              picked.end.add(const Duration(days: 1)),
            ),
          ),
          null,
        );
      }
    }

    final period =
        '${operationDateLabel(range.value.startAtMs).split(' ').first} – '
        '${operationDateLabel(range.value.endBeforeMs - 1).split(' ').first}';
    final header = <Widget>[
      Text('수업과 기기 기록', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('기기별 수업과 연결 기록을 확인하세요.'),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final days in [1, 7, 30])
            ChoiceChip(
              label: Text(days == 1 ? '오늘' : '최근 $days일'),
              selected: preset.value == days,
              onSelected: (_) {
                final now = centerDateTime(
                  DateTime.now().millisecondsSinceEpoch,
                );
                selectRange(
                  OperationEventRange(
                    startAtMs: centerDayStartMs(
                      now.subtract(Duration(days: days - 1)),
                    ),
                    endBeforeMs: centerDayStartMs(
                      now.add(const Duration(days: 1)),
                    ),
                  ),
                  days,
                );
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 18),
            label: const Text('기간 직접 선택'),
            onPressed: customRange,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              '$period\n한국 시간 · $centerTimeZone',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: '기록 새로고침',
            onPressed: () => ref.invalidate(source),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
    // Do not retain previous-period figures under a new date/filter heading.
    if (batch.isLoading || batch.hasError || !batch.hasValue) {
      return _ReportScroll(
        children: [
          ...header,
          if (batch.hasError) ...[
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 12),
            const Text(
              '운영 기록을 불러오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(source),
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ),
          ] else ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Text('선택한 기간의 기록을 불러오는 중입니다.', textAlign: TextAlign.center),
          ],
        ],
      );
    }
    final data = batch.requireValue;
    final allEvents = filterOperationHistory(data.events);
    final devices = operationDeviceOptions(allEvents);
    final workouts = operationWorkoutOptions(allEvents);
    final types = {
      for (final event in allEvents) event.type: operationTypeLabel(event.type),
    };
    final scoped = filterOperationHistory(
      allEvents,
      deviceId: device.value,
      workoutId: workout.value,
    );
    final visible = filterOperationHistory(scoped, type: type.value);
    final report = buildOperationsRangeReport(scoped, range: range.value);
    final incidents = {
      for (final incident in buildOperationIncidents(allEvents))
        incident.event.id: incident,
    };
    final recoveredIds = {
      for (final incident in incidents.values)
        if (incident.recovery != null) incident.recovery!.id,
    };
    final rows = visible
        .where(
          (event) => type.value != null || !recoveredIds.contains(event.id),
        )
        .toList();
    String count(int value) => scoped.isEmpty ? '기록 없음' : '$value회 기록';
    return _ReportScroll(
      children: [
        ...header,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 740
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HistoryFilter(
                  key: ValueKey('operation-device-${range.value.hashCode}'),
                  width: width,
                  label: '기기',
                  allLabel: '모든 기기',
                  options: devices,
                  value: device.value,
                  onChanged: (value) => device.value = value,
                ),
                _HistoryFilter(
                  key: ValueKey('operation-workout-${range.value.hashCode}'),
                  width: width,
                  label: '수업',
                  allLabel: '모든 수업',
                  options: workouts,
                  value: workout.value,
                  onChanged: (value) => workout.value = value,
                ),
                _HistoryFilter(
                  key: ValueKey('operation-type-${range.value.hashCode}'),
                  width: width,
                  label: '이벤트',
                  allLabel: '모든 유형',
                  options: types,
                  value: type.value,
                  onChanged: (value) => type.value = value,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text('선택 기간 요약', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('선택한 기기·수업의 기록 기준입니다. 이벤트 유형 필터는 아래 목록에 적용됩니다.'),
        const SizedBox(height: 12),
        if (!data.isComplete)
          const _ReportNote(
            icon: Icons.warning_amber,
            text: '부분 조회입니다. 모든 기록을 읽지 못해 합계가 실제보다 적을 수 있습니다.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 850
                ? 4
                : constraints.maxWidth >= 540
                ? 3
                : 2;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ReportMetric(
                  width: width,
                  title: '수업 시작',
                  value: count(report.playbackCount),
                  icon: Icons.play_circle_outline,
                ),
                _ReportMetric(
                  width: width,
                  title: '수업 종료',
                  value: count(report.completedCount),
                  icon: Icons.stop_circle_outlined,
                ),
                _ReportMetric(
                  width: width,
                  title: '서버 접속 끊김',
                  value: count(report.disconnectCount),
                  icon: Icons.wifi_off_outlined,
                ),
                _ReportMetric(
                  width: width,
                  title: '확인된 재생 중단',
                  value: count(report.interruptionCount),
                  icon: Icons.pause_circle_outline,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _ReportNote(
          icon: Icons.info_outline,
          text: '수집된 기록만 집계합니다. 기록 0건이 실제 수업이나 장애 0회를 뜻하지 않습니다. 종료는 종료 명령 기록이며 수업 완주 여부를 뜻하지 않습니다. 예시 수업은 수업 횟수에서 제외합니다.',
        ),
        if (report.hasLegacyEvents)
          const _ReportNote(
            icon: Icons.history,
            text:
                '이전 버전의 기록이 포함되어 있습니다. 수집하지 않은 기기명·버전·원인·복구 정보는 기록 없음으로 표시합니다.',
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('기기별 연결 시간 · 집계 기준'),
          subtitle: Text(
            report.onlineDurationByDevice.isEmpty
                ? '확인 가능한 연결 구간 없음'
                : '확인된 TV 연결 시간 합계 ${operationDurationLabel(report.onlineDuration)}',
          ),
          children: [
            const _ReportNote(
              icon: Icons.connected_tv_outlined,
              text: 'TV별 연결~접속 종료가 모두 기록된 구간만 합산합니다. TV 3대가 각각 1시간 연결되면 3시간입니다. 기간 밖의 연결 시작이나 종료가 누락된 구간은 포함하지 않습니다.',
            ),
            if (report.hasUnknownConnectionTime)
              const _ReportNote(
                icon: Icons.info_outline,
                text: '일부 연결 구간의 시작 또는 종료 기록이 없어 시간은 부분 집계입니다.',
              ),
            for (final entry in report.onlineDurationByDevice.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(devices[entry.key] ?? '이름 기록 없음'),
                subtitle: Text(operationDurationLabel(entry.value)),
              ),
            const _ReportNote(
              icon: Icons.schedule_outlined,
              text: '예약 정시율은 집계하지 않습니다. 변경된 예약과 실행되지 않은 예약 이력이 수집되지 않아 정확한 분모를 확인할 수 없습니다. 시작 기록의 정시 기준은 예약 시각 ±2분입니다.',
            ),
            Text(
              '예약 시작 ${report.scheduledPlaybackCount}건 중 정시 시작 기록 ${report.onTimePlaybackCount}건',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
        ),
        const Divider(height: 32),
        Text(
          '운영 기록 ${rows.length}건',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          '연결 끊김과 명시적으로 연결된 복구 기록은 하나로 묶습니다. 기록을 눌러 당시 상황과 수업 흐름을 확인하세요.',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _ReportNote(
            icon: Icons.manage_search,
            text: '선택한 조건에서 수집된 기록이 없습니다. 기간이나 필터를 바꿔 확인해 주세요.',
          ),
        for (final event in rows.take(visibleCount.value)) ...[
          _OperationRecord(
            event: event,
            incident: incidents[event.id],
            onTap: () => showOperationEventDetail(
              context,
              event: event,
              events: allEvents,
            ),
          ),
          const Divider(height: 1),
        ],
        if (rows.length > visibleCount.value)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              key: const ValueKey('operation-history-more'),
              onPressed: () => visibleCount.value += 50,
              child: Text('이전 기록 더 보기 (${visibleCount.value}/${rows.length})'),
            ),
          ),
      ],
    );
  }
}

class _ReportScroll extends StatelessWidget {
  const _ReportScroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: children,
      ),
    ),
  );
}

class _HistoryFilter extends StatelessWidget {
  const _HistoryFilter({
    super.key,
    required this.width,
    required this.label,
    required this.allLabel,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final double width;
  final String label, allLabel;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(allLabel)),
        if (value != null && !options.containsKey(value))
          DropdownMenuItem(
            value: value,
            child: const Text('선택한 항목 · 현재 기록 없음'),
          ),
        for (final option in options.entries)
          DropdownMenuItem(
            value: option.key,
            child: Text(
              option.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (next) => onChanged(next == '' ? null : next),
    ),
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });
  final double width;
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    ),
  );
}

class _ReportNote extends StatelessWidget {
  const _ReportNote({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _OperationRecord extends StatelessWidget {
  const _OperationRecord({
    required this.event,
    required this.incident,
    required this.onTap,
  });
  final OperationEvent event;
  final OperationIncident? incident;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey('operation-event-${event.id}'),
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    leading: Icon(
      event.deviceRole == 'controller'
          ? Icons.phone_android_outlined
          : Icons.connected_tv_outlined,
      color: AppColors.accent,
    ),
    trailing: const Icon(Icons.chevron_right),
    title: Text(operationTypeLabel(event.type)),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${event.deviceName ?? '기기 이름 기록 없음'} · ${event.zoneName ?? '공간 기록 없음'}',
          ),
          Text(
            '${operationRoleLabel(event)} · ${event.workoutName ?? '수업 기록 없음'}',
          ),
          Text(operationDateLabel(event.occurredAtMs)),
          if (incident != null) ...[
            const SizedBox(height: 4),
            Text(
              '${incident!.recoveryLabel} · ${incident!.impactLabel}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    ),
    onTap: onTap,
  );
}
