import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/countdown_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/countdown_defaults_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class WorkoutCountdown extends StatelessWidget {
  const WorkoutCountdown({
    super.key,
    required this.workout,
    required this.seconds,
    this.slideName,
    this.slide,
  });
  final Workout workout;
  final int seconds;
  final String? slideName;
  final WorkoutModule? slide;

  @override
  Widget build(BuildContext context) {
    final appearance = workout.countdownAppearance;
    final module = slide ?? workout.modules.firstOrNull;
    final customImage = workout.countdownImageSource;
    final image = customImage.isNotEmpty
        ? customImage
        : module?.imageSource ?? '';
    final opacity = appearance.overlayEnabled
        ? (appearance.overlayOpacity ?? (customImage.isNotEmpty ? .54 : 1.0))
              .clamp(0.0, 1.0)
        : 0.0;
    final background = Color(
      appearance.overlayColor ??
          (customImage.isNotEmpty
              ? 0xFF000000
              : workout.countdownBackgroundColor),
    );
    final foreground = appearance.numberColor != null
        ? Color(appearance.numberColor!)
        : opacity >= .8 && background.computeLuminance() >= .4
        ? Colors.black
        : Colors.white;
    final number = appearance.numberFormat == CountdownNumberFormat.clock
        ? '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}'
        : '$seconds';
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            if (image.isNotEmpty)
              WorkoutImage(
                source: image,
                fit: customImage.isNotEmpty || module?.coverImage == true
                    ? BoxFit.cover
                    : BoxFit.contain,
              ),
            if (opacity > 0)
              ColoredBox(
                key: const ValueKey('countdown-overlay'),
                color: background.withValues(alpha: opacity),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.all(
                  math.min(box.maxWidth, box.maxHeight) * .04,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'Pretendard',
                      shadows: appearance.numberShadow
                          ? const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (appearance.showReady)
                          const Text(
                            '준비하세요',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          number,
                          key: const ValueKey('countdown-number'),
                          style: TextStyle(
                            fontSize:
                                math.min(box.maxWidth, box.maxHeight) *
                                .3 *
                                appearance.numberScale.clamp(.5, 1.8),
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        if (appearance.showTitle)
                          Text(
                            slideName ?? module?.name ?? workout.name,
                            style: const TextStyle(fontSize: 24),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountdownSettings extends HookConsumerWidget {
  const CountdownSettings({
    super.key,
    required this.workout,
    required this.onChanged,
    this.showAccountDefaults = true,
  });
  final bool showAccountDefaults;
  final Workout workout;
  final ValueChanged<Workout> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = useRef(workout)..value = workout;
    final loading = useState(false);
    final imageError = useState<String?>(null);
    final seconds = useTextEditingController(
      text: '${workout.countdownSeconds}',
    );
    final inputFocus = useFocusNode();
    final previewSeconds = useState<int?>(null);
    final previewTimer = useRef<Timer?>(null);
    final undo = useState<CountdownPreferences?>(null);
    final ownerId = ref.watch(authStateProvider).value?.id;
    final defaultsProvider = countdownDefaultsControllerProvider(ownerId ?? '');
    final defaults = ref.watch(defaultsProvider);
    ref.listen(defaultsProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기본값 작업을 완료하지 못했습니다. 연결과 로그인 상태를 확인해 주세요.'),
          ),
        );
      } else if (next.value != null && next.value != previous?.value) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.value!)));
      }
    });
    void stopPreview() {
      previewTimer.value?.cancel();
      previewSeconds.value = null;
    }

    useEffect(() {
      if (seconds.text != '${workout.countdownSeconds}') {
        seconds.text = '${workout.countdownSeconds}';
      }
      return null;
    }, [workout.countdownSeconds]);
    useEffect(() {
      void restoreEmpty() {
        if (!inputFocus.hasFocus && seconds.text.isEmpty) {
          seconds.text = '${latest.value.countdownSeconds}';
        }
      }

      inputFocus.addListener(restoreEmpty);
      return () {
        inputFocus.removeListener(restoreEmpty);
        previewTimer.value?.cancel();
      };
    }, const []);
    // Changing any preference cancels the rehearsal. Never invokes player/session actions.
    useEffect(() {
      stopPreview();
      return null;
    }, [CountdownPreferences.fromWorkout(workout)]);
    final appearance = workout.countdownAppearance;
    void appearanceChanged(CountdownAppearance value) =>
        onChanged(latest.value.copyWith(countdownAppearance: value));
    String hex(int value) =>
        '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('수업 시작 카운트다운', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: workout.countdownSeconds == 0
                ? const ColoredBox(
                    color: Color(0xFFF3F2F7),
                    child: Center(child: Text('바로 시작 (카운트다운 없음)')),
                  )
                : WorkoutCountdown(
                    workout: workout,
                    seconds: previewSeconds.value ?? workout.countdownSeconds,
                  ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('countdown-preview'),
            onPressed: workout.countdownSeconds == 0
                ? null
                : () {
                    if (previewSeconds.value != null) {
                      stopPreview();
                      return;
                    }
                    final start = DateTime.now();
                    final duration = workout.countdownSeconds;
                    previewSeconds.value = duration;
                    previewTimer.value = Timer.periodic(
                      const Duration(milliseconds: 100),
                      (_) {
                        final left =
                            duration -
                            DateTime.now().difference(start).inSeconds;
                        if (left <= 0) {
                          stopPreview();
                        } else {
                          previewSeconds.value = left;
                        }
                      },
                    );
                  },
            icon: Icon(
              previewSeconds.value == null
                  ? Icons.play_arrow_rounded
                  : Icons.stop_rounded,
            ),
            label: Text(previewSeconds.value == null ? '미리 재생' : '미리보기 중지'),
          ),
        ),
        const Text(
          '미리보기는 이 화면에서만 재생되며 수업에는 영향을 주지 않습니다.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('countdown-seconds'),
          controller: seconds,
          focusNode: inputFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
            TextInputFormatter.withFunction(
              (oldValue, newValue) =>
                  newValue.text.isEmpty ||
                      (int.tryParse(newValue.text) ?? 61) <= 60
                  ? newValue
                  : oldValue,
            ),
          ],
          decoration: const InputDecoration(
            labelText: '준비 시간',
            suffixText: '초',
            helperText: '0~60초 · 0초는 카운트다운 없이 바로 시작',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) {
              onChanged(latest.value.copyWith(countdownSeconds: parsed));
            }
          },
          onSubmitted: (_) => inputFocus.unfocus(),
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('준비하세요 표시'),
          value: appearance.showReady,
          onChanged: (v) =>
              appearanceChanged(appearance.copyWith(showReady: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('운동 제목 표시'),
          value: appearance.showTitle,
          onChanged: (v) =>
              appearanceChanged(appearance.copyWith(showTitle: v)),
        ),
        const SizedBox(height: 12),
        const Text('숫자 형식'),
        const SizedBox(height: 8),
        SegmentedButton<CountdownNumberFormat>(
          segments: const [
            ButtonSegment(
              value: CountdownNumberFormat.seconds,
              label: Text('숫자 · 5'),
            ),
            ButtonSegment(
              value: CountdownNumberFormat.clock,
              label: Text('시간 · 00:05'),
            ),
          ],
          selected: {appearance.numberFormat},
          onSelectionChanged: (v) =>
              appearanceChanged(appearance.copyWith(numberFormat: v.single)),
        ),
        const SizedBox(height: 16),
        Text('숫자 크기 ${(appearance.numberScale * 100).round()}%'),
        Slider(
          key: const ValueKey('countdown-number-scale'),
          min: .5,
          max: 1.8,
          divisions: 26,
          value: appearance.numberScale.clamp(.5, 1.8),
          onChanged: (v) =>
              appearanceChanged(appearance.copyWith(numberScale: v)),
        ),
        HexColorField(
          label: '숫자 색상',
          initialValue: hex(appearance.numberColor ?? 0xFFFFFFFF),
          onChanged: (v) {
            final color = parseHexColor(v);
            if (color != null) {
              appearanceChanged(
                latest.value.countdownAppearance.copyWith(numberColor: color),
              );
            }
          },
        ),
        TextButton(
          onPressed: () =>
              appearanceChanged(appearance.copyWith(numberColor: null)),
          child: const Text('배경에 맞춰 자동 색상'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('숫자 그림자'),
          value: appearance.numberShadow,
          onChanged: (v) =>
              appearanceChanged(appearance.copyWith(numberShadow: v)),
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('배경 오버레이'),
          subtitle: const Text('끄면 원래 배경이 그대로 보입니다.'),
          value: appearance.overlayEnabled,
          onChanged: (v) =>
              appearanceChanged(appearance.copyWith(overlayEnabled: v)),
        ),
        if (appearance.overlayEnabled) ...[
          HexColorField(
            label: '카운트다운 배경색',
            initialValue: hex(
              appearance.overlayColor ??
                  (workout.countdownImageSource.isNotEmpty
                      ? 0xFF000000
                      : workout.countdownBackgroundColor),
            ),
            onChanged: (v) {
              final color = parseHexColor(v);
              if (color != null) {
                onChanged(
                  latest.value.copyWith(
                    countdownBackgroundColor: color,
                    countdownAppearance: latest.value.countdownAppearance
                        .copyWith(overlayColor: color),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            '배경 불투명도 ${((appearance.overlayOpacity ?? (workout.countdownImageSource.isEmpty ? 1.0 : .54)) * 100).round()}%',
          ),
          Slider(
            key: const ValueKey('countdown-opacity'),
            value:
                (appearance.overlayOpacity ??
                        (workout.countdownImageSource.isEmpty ? 1.0 : .54))
                    .clamp(0, 1),
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: (v) =>
                appearanceChanged(appearance.copyWith(overlayOpacity: v)),
          ),
        ],
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: loading.value
                  ? null
                  : () async {
                      loading.value = true;
                      imageError.value = null;
                      try {
                        final file = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (file == null) return;
                        final source = WorkoutImageSource.fromBytes(
                          await file.readAsBytes(),
                          contentType: file.mimeType,
                        );
                        if (context.mounted) {
                          onChanged(
                            latest.value.copyWith(countdownImageSource: source),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          imageError.value = '이미지를 불러오지 못했습니다.';
                        }
                      } finally {
                        if (context.mounted) loading.value = false;
                      }
                    },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(loading.value ? '불러오는 중…' : '배경 이미지 선택'),
            ),
            if (workout.countdownImageSource.isNotEmpty)
              TextButton(
                onPressed: () =>
                    onChanged(workout.copyWith(countdownImageSource: '')),
                child: const Text('배경 이미지 제거'),
              ),
          ],
        ),
        if (imageError.value != null) Text(imageError.value!),
        if (showAccountDefaults) ...[
          const Divider(height: 32),
          Text('계정 기본값', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '새 워크아웃부터 적용됩니다. 기존 워크아웃과 진행 중인 수업은 바뀌지 않습니다.',
            style: TextStyle(fontSize: 12),
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: ownerId == null || defaults.isLoading
                    ? null
                    : () async {
                        await ref
                            .read(defaultsProvider.notifier)
                            .save(
                              CountdownPreferences.fromWorkout(latest.value),
                            );
                      },
                icon: defaults.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined),
                label: const Text('내 기본값으로 저장'),
              ),
              TextButton.icon(
                onPressed: ownerId == null || defaults.isLoading
                    ? null
                    : () async {
                        final capturedOwner = ownerId;
                        final captured = CountdownPreferences.fromWorkout(
                          latest.value,
                        );
                        final value = await ref
                            .read(defaultsProvider.notifier)
                            .load();
                        if (!context.mounted ||
                            value == null ||
                            ref.read(authStateProvider).value?.id !=
                                capturedOwner) {
                          return;
                        }
                        if (CountdownPreferences.fromWorkout(latest.value) !=
                            captured) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '설정이 변경되어 기본값을 적용하지 않았습니다. 다시 눌러 주세요.',
                              ),
                            ),
                          );
                          return;
                        }
                        undo.value = captured;
                        onChanged(value.applyTo(latest.value));
                      },
                icon: const Icon(Icons.download_rounded),
                label: const Text('내 기본값 가져오기'),
              ),
              if (undo.value != null)
                TextButton(
                  onPressed: () {
                    onChanged(undo.value!.applyTo(latest.value));
                    undo.value = null;
                  },
                  child: const Text('가져오기 되돌리기'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
