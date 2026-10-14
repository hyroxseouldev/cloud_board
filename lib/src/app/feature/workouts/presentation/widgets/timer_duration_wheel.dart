import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart'
    show maxTimingSeconds;
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

/// Presentation-only ownership of the one visible wheel. Commit reads its
/// current centered items synchronously, before a field switch or Apply.
class TimerWheelSelection extends ChangeNotifier {
  TimerWheelSelection(this.selectedKey);
  String? selectedKey;
  Object? _session;
  VoidCallback? _commit;
  bool _disposed = false;

  void commit() => _commit?.call();

  void select(String? key) {
    if (selectedKey == key) return;
    commit();
    _session = null;
    _commit = null;
    selectedKey = key;
    notifyListeners();
  }

  Object attach(String key, VoidCallback commit) {
    final token = Object();
    _session = token;
    _commit = commit;
    return token;
  }

  bool accepts(String key, Object? token) =>
      !_disposed && selectedKey == key && identical(_session, token);

  void detach(Object? token) {
    if (!identical(_session, token)) return;
    _session = null;
    _commit = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _session = null;
    _commit = null;
    super.dispose();
  }
}

class TimerDurationOption {
  const TimerDurationOption({
    required this.fieldKey,
    required this.label,
    required this.seconds,
    required this.onChanged,
    this.minimumSeconds = 0,
    this.error,
  });
  final String fieldKey, label;
  final int seconds, minimumSeconds;
  final String? error;
  final ValueChanged<int> onChanged;
}

class TimerDurationGroup extends HookWidget {
  const TimerDurationGroup({
    super.key,
    required this.options,
    required this.selection,
  });
  final List<TimerDurationOption> options;
  final TimerWheelSelection selection;

  @override
  Widget build(BuildContext context) {
    useListenable(selection);
    final active = options
        .where((o) => o.fieldKey == selection.selectedKey)
        .firstOrNull;
    Widget summary(TimerDurationOption option) {
      final selected = option == active;
      void select() {
        FocusScope.of(context).unfocus();
        selection.select(option.fieldKey);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            option.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            selected: selected,
            label: option.label,
            value: formatSlideTime(option.seconds),
            hint: '분과 초 선택',
            excludeSemantics: true,
            onTap: select,
            child: Material(
              color: selected
                  ? SlideEditorStyle.wheel
                  : SlideEditorStyle.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: option.error != null
                      ? Theme.of(context).colorScheme.error
                      : SlideEditorStyle.controlBorder,
                ),
              ),
              child: InkWell(
                key: ValueKey(option.fieldKey),
                borderRadius: BorderRadius.circular(12),
                onTap: select,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatSlideTime(option.seconds),
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: SlideEditorStyle.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (option.error != null)
            Text(
              option.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            if (options.length == 1) return summary(options.single);
            if (MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                children: [
                  summary(options.first),
                  const SizedBox(height: 12),
                  summary(options.last),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary(options.first)),
                const SizedBox(width: 12),
                Expanded(child: summary(options.last)),
              ],
            );
          },
        ),
        if (active != null) ...[
          const Divider(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 240 * MediaQuery.textScalerOf(context).scale(14) / 14,
              ),
              child: TimerDurationWheel(
                key: ValueKey('wheel-${active.fieldKey}'),
                option: active,
                selection: selection,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '위아래로 움직여 시간을 선택하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: SlideEditorStyle.muted),
          ),
        ],
      ],
    );
  }
}

class TimerDurationWheel extends HookWidget {
  const TimerDurationWheel({
    super.key,
    required this.option,
    required this.selection,
  });
  final TimerDurationOption option;
  final TimerWheelSelection selection;

  @override
  Widget build(BuildContext context) {
    final initial = option.seconds.clamp(
      option.minimumSeconds,
      maxTimingSeconds,
    );
    final minutes = useState(initial ~/ 60);
    final seconds = useState(initial % 60);
    final minuteController = useMemoized(
      () => FixedExtentScrollController(initialItem: minutes.value),
    );
    final secondController = useMemoized(
      () => FixedExtentScrollController(initialItem: seconds.value),
    );
    final token = useRef<Object?>(null);
    final callback = useRef(option.onChanged)..value = option.onChanged;
    final lastPublished = useRef(option.seconds);

    int selected(
      FixedExtentScrollController controller,
      int fallback,
      int maximum,
    ) => controller.hasClients && controller.positions.length == 1
        ? controller.selectedItem.clamp(0, maximum)
        : fallback;

    void publish(int m, int s) {
      if (!context.mounted ||
          !selection.accepts(option.fieldKey, token.value)) {
        return;
      }
      final total = (m * 60 + s).clamp(option.minimumSeconds, maxTimingSeconds);
      minutes.value = total ~/ 60;
      seconds.value = total % 60;
      // Continuous and EMOM time cannot be zero. Keep the centered selection,
      // summary and draft at the same minimum instead of a rejected raw value.
      if (total != m * 60 + s && secondController.hasClients) {
        secondController.jumpToItem(seconds.value);
      }
      if (total != lastPublished.value) {
        lastPublished.value = total;
        callback.value(total);
      }
    }

    void commit() {
      if (!context.mounted ||
          !selection.accepts(option.fieldKey, token.value)) {
        return;
      }
      final m = selected(minuteController, minutes.value, 999);
      final s = selected(secondController, seconds.value, 59);
      // Stop both ballistic activities before publishing the captured center.
      if (minuteController.hasClients) minuteController.jumpToItem(m);
      if (secondController.hasClients) secondController.jumpToItem(s);
      publish(m, s);
    }

    useEffect(() {
      token.value = selection.attach(option.fieldKey, commit);
      return () {
        selection.detach(token.value);
        minuteController.dispose();
        secondController.dispose();
      };
    }, [selection, option.fieldKey]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _DurationColumn(
            fieldKey: option.fieldKey,
            unit: '분',
            label: '${option.label} 분',
            value: minutes.value,
            maximum: 999,
            controller: minuteController,
            onChanged: (value) =>
                publish(value, selected(secondController, seconds.value, 59)),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 6,
            right: 6,
            top: MediaQuery.textScalerOf(context).scale(20),
          ),
          child: const ExcludeSemantics(
            child: Text(
              ':',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: _DurationColumn(
            fieldKey: option.fieldKey,
            unit: '초',
            label: '${option.label} 초',
            value: seconds.value,
            minimum: minutes.value == 0 ? option.minimumSeconds : 0,
            maximum: 59,
            controller: secondController,
            onChanged: (value) =>
                publish(selected(minuteController, minutes.value, 999), value),
          ),
        ),
      ],
    );
  }
}

class _DurationColumn extends HookWidget {
  const _DurationColumn({
    required this.fieldKey,
    required this.unit,
    required this.label,
    required this.value,
    required this.maximum,
    required this.controller,
    required this.onChanged,
    this.minimum = 0,
  });
  final String fieldKey, unit, label;
  final int value, minimum, maximum;
  final FixedExtentScrollController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final focus = useFocusNode();
    useListenable(focus);
    final extent = math.max(
      32.0,
      MediaQuery.textScalerOf(context).scale(30) * 1.05,
    );
    final name = unit == '분' ? 'minutes' : 'seconds';
    void moveTo(int next) {
      next = next.clamp(minimum, maximum);
      if (!controller.hasClients) return;
      controller.jumpToItem(next);
      onChanged(next);
    }

    void step(int delta) {
      final current = controller.hasClients && controller.positions.length == 1
          ? controller.selectedItem
          : value;
      moveTo(current + delta);
    }

    return Semantics(
      key: ValueKey('$fieldKey-$name-semantics'),
      container: true,
      excludeSemantics: true,
      label: label,
      value: '$value$unit',
      increasedValue: value < maximum ? '${value + 1}$unit' : null,
      decreasedValue: value > minimum ? '${value - 1}$unit' : null,
      onIncrease: value < maximum ? () => step(1) : null,
      onDecrease: value > minimum ? () => step(-1) : null,
      focusable: true,
      focused: focus.hasFocus,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => step(1),
          const SingleActivator(LogicalKeyboardKey.home): () => moveTo(minimum),
          const SingleActivator(LogicalKeyboardKey.end): () => moveTo(maximum),
          const SingleActivator(LogicalKeyboardKey.pageUp): () => step(-10),
          const SingleActivator(LogicalKeyboardKey.pageDown): () => step(10),
        },
        child: Focus(
          focusNode: focus,
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(20),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SlideEditorStyle.muted,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('$fieldKey-$name-decrease'),
                tooltip: '$label 줄이기',
                onPressed: value > minimum ? () => step(-1) : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: focus.hasFocus
                        ? SlideEditorStyle.accent
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  height: extent * 4.2,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: extent,
                          decoration: BoxDecoration(
                            color: SlideEditorStyle.wheel,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: Listener(
                          onPointerDown: (_) => focus.requestFocus(),
                          child: CupertinoPicker.builder(
                            key: ValueKey('$fieldKey-$name-wheel'),
                            scrollController: controller,
                            itemExtent: extent,
                            diameterRatio: 2.5,
                            selectionOverlay: const SizedBox.shrink(),
                            // Finite delegate: unlike a looping picker, neither edge wraps.
                            childCount: maximum + 1,
                            onSelectedItemChanged: (index) {
                              // A queued notification from an interrupted
                              // activity must not overwrite a newer jump.
                              if (controller.hasClients &&
                                  controller.positions.length == 1 &&
                                  controller.selectedItem == index) {
                                onChanged(index);
                              }
                            },
                            itemBuilder: (_, index) => Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$index'.padLeft(2, '0'),
                                    style: TextStyle(
                                      fontFamily: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.fontFamily,
                                      fontSize: index == value ? 30 : 20,
                                      height: 1,
                                      fontWeight: index == value
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: index == value
                                          ? SlideEditorStyle.ink
                                          : SlideEditorStyle.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('$fieldKey-$name-increase'),
                tooltip: '$label 늘리기',
                onPressed: value < maximum ? () => step(1) : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
