import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';

class SlideDurationField extends StatelessWidget {
  const SlideDurationField({
    super.key,
    required this.controller,
    required this.label,
    required this.minimumSeconds,
    required this.onChanged,
    required this.validator,
    this.grouped = false,
  });

  final TextEditingController controller;
  final String label;
  final int minimumSeconds;
  final ValueChanged<int> onChanged;
  final FormFieldValidator<String> validator;
  final bool grouped;

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: controller.text,
    validator: validator,
    builder: (field) => _MetricBlock(
      label: label,
      value: controller.text,
      unit: 'mm:ss',
      icon: Icons.access_time_rounded,
      errorText: field.errorText,
      grouped: grouped,
      onTap: () async {
        final seconds = await showModalBottomSheet<int>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 520),
          builder: (_) => _DurationPickerSheet(
            title: label,
            initialSeconds: parseSlideTime(controller.text) ?? minimumSeconds,
            minimumSeconds: minimumSeconds,
          ),
        );
        if (seconds == null) return;
        controller.text = formatSlideTime(seconds);
        field.didChange(controller.text);
        onChanged(seconds);
      },
    ),
  );
}

class SlideTimingBlocks extends StatelessWidget {
  const SlideTimingBlocks({
    super.key,
    required this.workController,
    required this.restController,
    required this.setsController,
    required this.onChanged,
    required this.workValidator,
    required this.restValidator,
    required this.setsValidator,
    this.title = '시간 및 세트',
    this.leading,
    this.trailing,
    this.onEditing,
  });

  final TextEditingController workController;
  final TextEditingController restController;
  final TextEditingController setsController;
  final VoidCallback onChanged;
  final FormFieldValidator<String> workValidator;
  final FormFieldValidator<String> restValidator;
  final FormFieldValidator<String> setsValidator;
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onEditing;

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: _summary,
    validator: (_) =>
        workValidator(workController.text) ??
        restValidator(restController.text) ??
        setsValidator(setsController.text),
    builder: (field) {
      final colors = Theme.of(context).colorScheme;
      return Material(
        key: ValueKey(
          title == '시간 및 세트'
              ? 'timing-summary-block'
              : 'timing-summary-block-$title',
        ),
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: field.errorText == null ? Colors.transparent : colors.error,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            onEditing?.call();
            final selection = await showModalBottomSheet<SlideTimingSelection>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              constraints: const BoxConstraints(maxWidth: 520),
              builder: (_) => SlideTimingEditor(
                initialWorkSeconds: parseSlideTime(workController.text) ?? 1,
                initialRestSeconds: parseSlideTime(restController.text) ?? 0,
                initialSets: (int.tryParse(setsController.text) ?? 1).clamp(
                  1,
                  999,
                ),
              ),
            );
            if (selection == null) return;
            workController.text = formatSlideTime(selection.workSeconds);
            restController.text = formatSlideTime(selection.restSeconds);
            setsController.text = '${selection.sets}';
            field.didChange(_summary);
            onChanged();
          },
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            leading:
                leading ?? Icon(Icons.timer_outlined, color: colors.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _summary,
                key: const ValueKey('timing-summary'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
    },
  );

  String get _summary =>
      '${setsController.text}세트 · ${workController.text} / 휴식 ${restController.text}';
}

typedef SlideTimingSelection = ({int workSeconds, int restSeconds, int sets});

enum _TimingPart { work, rest }

class SlideTimingEditor extends HookWidget {
  const SlideTimingEditor({
    super.key,
    required this.initialWorkSeconds,
    required this.initialRestSeconds,
    required this.initialSets,
    this.embedded = false,
    this.onApply,
    this.onCancel,
  });

  final int initialWorkSeconds;
  final int initialRestSeconds;
  final int initialSets;
  final bool embedded;
  final ValueChanged<SlideTimingSelection>? onApply;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final part = useState(_TimingPart.work);
    final workMinutes = useState(initialWorkSeconds ~/ 60);
    final workSeconds = useState(initialWorkSeconds.remainder(60));
    final restMinutes = useState(initialRestSeconds ~/ 60);
    final restSeconds = useState(initialRestSeconds.remainder(60));
    final sets = useState(initialSets);
    final workMinuteController = useMemoized(
      () => FixedExtentScrollController(initialItem: workMinutes.value),
    );
    final workSecondController = useMemoized(
      () => FixedExtentScrollController(initialItem: workSeconds.value),
    );
    final restMinuteController = useMemoized(
      () => FixedExtentScrollController(initialItem: restMinutes.value),
    );
    final restSecondController = useMemoized(
      () => FixedExtentScrollController(initialItem: restSeconds.value),
    );
    final setsController = useMemoized(
      () => FixedExtentScrollController(initialItem: sets.value - 1),
    );
    useEffect(
      () {
        return () {
          workMinuteController.dispose();
          workSecondController.dispose();
          restMinuteController.dispose();
          restSecondController.dispose();
          setsController.dispose();
        };
      },
      [
        workMinuteController,
        workSecondController,
        restMinuteController,
        restSecondController,
        setsController,
      ],
    );
    final workTotal = workMinutes.value * 60 + workSeconds.value;
    final restTotal = restMinutes.value * 60 + restSeconds.value;
    final valid = workTotal > 0;

    return Material(
      color: embedded
          ? Colors.transparent
          : Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!embedded)
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: onCancel ?? () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (!embedded)
                        Text(
                          '시간 및 세트 설정',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      Text(
                        '${sets.value}세트 · ${formatSlideTime(workTotal)} / 휴식 ${formatSlideTime(restTotal)}',
                        key: const ValueKey('selected-timing-summary'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: valid
                      ? () {
                          final selection = (
                            workSeconds: workTotal,
                            restSeconds: restTotal,
                            sets: sets.value,
                          );
                          if (onApply != null) {
                            onApply!(selection);
                          } else {
                            Navigator.pop(context, selection);
                          }
                        }
                      : null,
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SegmentedButton<_TimingPart>(
                    segments: const [
                      ButtonSegment(value: _TimingPart.work, label: Text('운동')),
                      ButtonSegment(value: _TimingPart.rest, label: Text('휴식')),
                    ],
                    selected: {part.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) => part.value = values.first,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Center(child: Text('세트'))),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: embedded && MediaQuery.sizeOf(context).width >= 700
                  ? 184
                  : 132,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppStyle.cardRadius,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: part.value == _TimingPart.work
                            ? _DurationWheels(
                                key: const ValueKey('work-duration-wheels'),
                                minuteController: workMinuteController,
                                secondController: workSecondController,
                                onMinutesChanged: (value) =>
                                    workMinutes.value = value,
                                onSecondsChanged: (value) =>
                                    workSeconds.value = value,
                              )
                            : _DurationWheels(
                                key: const ValueKey('rest-duration-wheels'),
                                minuteController: restMinuteController,
                                secondController: restSecondController,
                                onMinutesChanged: (value) =>
                                    restMinutes.value = value,
                                onSecondsChanged: (value) =>
                                    restSeconds.value = value,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppStyle.cardRadius,
                        ),
                      ),
                      child: CupertinoPicker.builder(
                        key: const ValueKey('combined-set-count-picker'),
                        scrollController: setsController,
                        itemExtent: 42,
                        diameterRatio: 2.5,
                        selectionOverlay: const SizedBox.shrink(),
                        childCount: 999,
                        onSelectedItemChanged: (value) =>
                            sets.value = value + 1,
                        itemBuilder: (_, value) => Center(
                          child: Text(
                            '${value + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 27,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: value + 1 == sets.value
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!valid)
              Text(
                '운동 시간은 00:01 이상이어야 합니다.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationWheels extends StatelessWidget {
  const _DurationWheels({
    super.key,
    required this.minuteController,
    required this.secondController,
    required this.onMinutesChanged,
    required this.onSecondsChanged,
  });

  final FixedExtentScrollController minuteController;
  final FixedExtentScrollController secondController;
  final ValueChanged<int> onMinutesChanged;
  final ValueChanged<int> onSecondsChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final minutes in [true, false]) ...[
        if (!minutes)
          Text(
            ':',
            style: TextStyle(
              fontSize: 27,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        Expanded(
          child: Semantics(
            label: minutes ? '분' : '초',
            child: CupertinoPicker.builder(
              key: ValueKey(
                minutes ? 'combined-minutes-picker' : 'combined-seconds-picker',
              ),
              scrollController: minutes ? minuteController : secondController,
              itemExtent: 42,
              diameterRatio: 2.5,
              selectionOverlay: const SizedBox.shrink(),
              childCount: minutes ? 1000 : 60,
              onSelectedItemChanged: minutes
                  ? onMinutesChanged
                  : onSecondsChanged,
              itemBuilder: (_, value) => Center(
                child: Text(
                  value.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 27,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class SlideSetCountField extends StatelessWidget {
  const SlideSetCountField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.validator,
  });

  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: controller.text,
    validator: validator,
    builder: (field) => _MetricBlock(
      label: '세트 수',
      value: controller.text,
      unit: '세트',
      icon: Icons.repeat_rounded,
      errorText: field.errorText,
      grouped: false,
      onTap: () async {
        final count = await showModalBottomSheet<int>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 520),
          builder: (_) => _SetCountPickerSheet(
            initialCount: (int.tryParse(controller.text) ?? 1).clamp(1, 999),
          ),
        );
        if (count == null) return;
        controller.text = '$count';
        field.didChange(controller.text);
        onChanged(count);
      },
    ),
  );
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.errorText,
    required this.onTap,
    required this.grouped,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final String? errorText;
  final VoidCallback onTap;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label $value, 탭해서 변경',
      child: Material(
        color: grouped ? Colors.transparent : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(grouped ? 0 : 12),
          side: BorderSide(
            color: grouped
                ? Colors.transparent
                : errorText == null
                ? colors.outlineVariant
                : colors.error,
            width: grouped ? 0 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 17, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    key: ValueKey('metric-$label'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationPickerSheet extends HookWidget {
  const _DurationPickerSheet({
    required this.title,
    required this.initialSeconds,
    required this.minimumSeconds,
  });

  final String title;
  final int initialSeconds;
  final int minimumSeconds;

  @override
  Widget build(BuildContext context) {
    final initialMinutes = (initialSeconds ~/ 60).clamp(0, 999);
    final initialRemainder = initialSeconds.remainder(60).clamp(0, 59);
    final minutes = useState(initialMinutes);
    final seconds = useState(initialRemainder);
    final minuteController = useMemoized(
      () => FixedExtentScrollController(initialItem: initialMinutes),
    );
    final secondController = useMemoized(
      () => FixedExtentScrollController(initialItem: initialRemainder),
    );
    useEffect(() {
      return () {
        minuteController.dispose();
        secondController.dispose();
      };
    }, [minuteController, secondController]);
    final total = minutes.value * 60 + seconds.value;
    final valid = total >= minimumSeconds;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$title 설정',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        formatSlideTime(total),
                        key: const ValueKey('selected-duration'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: valid ? () => Navigator.pop(context, total) : null,
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Center(child: Text('분'))),
                Expanded(child: Center(child: Text('초'))),
              ],
            ),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker.builder(
                      key: const ValueKey('minutes-picker'),
                      scrollController: minuteController,
                      itemExtent: 44,
                      useMagnifier: true,
                      magnification: 1.12,
                      selectionOverlay:
                          const CupertinoPickerDefaultSelectionOverlay(
                            capStartEdge: false,
                            capEndEdge: false,
                          ),
                      childCount: 1000,
                      onSelectedItemChanged: (value) => minutes.value = value,
                      itemBuilder: (_, value) =>
                          Center(child: Text(value.toString().padLeft(2, '0'))),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker.builder(
                      key: const ValueKey('seconds-picker'),
                      scrollController: secondController,
                      itemExtent: 44,
                      useMagnifier: true,
                      magnification: 1.12,
                      selectionOverlay:
                          const CupertinoPickerDefaultSelectionOverlay(
                            capStartEdge: false,
                            capEndEdge: false,
                          ),
                      childCount: 60,
                      onSelectedItemChanged: (value) => seconds.value = value,
                      itemBuilder: (_, value) =>
                          Center(child: Text(value.toString().padLeft(2, '0'))),
                    ),
                  ),
                ],
              ),
            ),
            if (!valid)
              Padding(
                padding: EdgeInsets.zero,
                child: Text(
                  '운동 시간은 00:01 이상이어야 합니다.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetCountPickerSheet extends HookWidget {
  const _SetCountPickerSheet({required this.initialCount});

  final int initialCount;

  @override
  Widget build(BuildContext context) {
    final count = useState(initialCount);
    final controller = useMemoized(
      () => FixedExtentScrollController(initialItem: initialCount - 1),
    );
    useEffect(() => controller.dispose, [controller]);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '세트 수 설정',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${count.value}세트',
                        key: const ValueKey('selected-set-count'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, count.value),
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('세트'),
            SizedBox(
              height: 220,
              child: CupertinoPicker.builder(
                key: const ValueKey('set-count-picker'),
                scrollController: controller,
                itemExtent: 44,
                useMagnifier: true,
                magnification: 1.12,
                childCount: 999,
                onSelectedItemChanged: (value) => count.value = value + 1,
                itemBuilder: (_, value) => Center(child: Text('${value + 1}')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
