import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class WorkoutCountdown extends StatelessWidget {
  const WorkoutCountdown({
    super.key,
    required this.workout,
    required this.seconds,
    this.slideName,
  });
  final Workout workout;
  final int seconds;
  final String? slideName;
  @override
  Widget build(BuildContext context) {
    final background = Color(workout.countdownBackgroundColor);
    final hasImage = workout.countdownImageSource.isNotEmpty;
    final foreground = hasImage || background.computeLuminance() < .4
        ? Colors.white
        : Colors.black;
    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              WorkoutImage(
                source: workout.countdownImageSource,
                fit: BoxFit.cover,
              ),
            if (hasImage) const ColoredBox(color: Colors.black54),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'Pretendard',
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '준비하세요',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$seconds',
                          style: TextStyle(
                            fontSize:
                                math.min(box.maxWidth, box.maxHeight) * .4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          slideName ?? workout.name,
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

class CountdownSettings extends HookWidget {
  const CountdownSettings({
    super.key,
    required this.workout,
    required this.onChanged,
  });
  final Workout workout;
  final ValueChanged<Workout> onChanged;
  @override
  Widget build(BuildContext context) {
    final latest = useRef(workout)..value = workout;
    final loading = useState(false);
    final error = useState<String?>(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('수업 시작 카운트다운', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          workout.countdownSeconds == 0
              ? '바로 시작 (카운트다운 없음)'
              : '${workout.countdownSeconds}초 후 시작',
        ),
        Slider(
          key: const ValueKey('countdown-seconds'),
          label: '${workout.countdownSeconds}초',
          min: 0,
          max: 60,
          divisions: 60,
          value: workout.countdownSeconds.clamp(0, 60).toDouble(),
          onChanged: (v) =>
              onChanged(workout.copyWith(countdownSeconds: v.round())),
        ),
        HexColorField(
          label: '카운트다운 배경색',
          initialValue:
              '#${workout.countdownBackgroundColor.toRadixString(16).padLeft(8, '0').substring(2)}',
          onChanged: (v) {
            final color = parseHexColor(v);
            if (color != null) {
              onChanged(latest.value.copyWith(countdownBackgroundColor: color));
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: loading.value
                  ? null
                  : () async {
                      loading.value = true;
                      error.value = null;
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
                          error.value = '이미지를 불러오지 못했습니다. 다시 시도해 주세요.';
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
        if (error.value != null) Text(error.value!),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: WorkoutCountdown(
              workout: workout,
              seconds: workout.countdownSeconds,
            ),
          ),
        ),
      ],
    );
  }
}
