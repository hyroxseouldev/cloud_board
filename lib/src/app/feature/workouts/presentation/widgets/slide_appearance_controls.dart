import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

enum SlideAppearanceSection { all, timer, background, visibility }

class SlideAppearanceControls extends StatelessWidget {
  const SlideAppearanceControls({
    super.key,
    required this.value,
    required this.onChanged,
    this.section = SlideAppearanceSection.all,
  });
  final SlideAppearance value;
  final SlideAppearanceSection section;
  final void Function(SlideAppearance, String?) onChanged;
  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 8,
        disabledThumbRadius: 8,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section == SlideAppearanceSection.all ||
            section == SlideAppearanceSection.timer) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  '타이머 배치',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '배치 초기화',
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: () => onChanged(
                  value.copyWith(
                    timerX: .84,
                    timerY: .5,
                    timerSize: 1,
                    ringWidth: 30,
                  ),
                  null,
                ),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
          _adjust(
            '가로 위치',
            value.timerX,
            0,
            1,
            100,
            '${(value.timerX * 100).round()}%',
            (v) => onChanged(value.copyWith(timerX: v), 'timer-x'),
          ),
          _adjust(
            '세로 위치',
            value.timerY,
            0,
            1,
            100,
            '${(value.timerY * 100).round()}%',
            (v) => onChanged(value.copyWith(timerY: v), 'timer-y'),
          ),
          _adjust(
            '타이머 크기',
            value.timerSize,
            .6,
            1.6,
            20,
            '${(value.timerSize * 100).round()}%',
            (v) => onChanged(value.copyWith(timerSize: v), 'timer-size'),
          ),
          _adjust(
            '게이지 두께',
            value.ringWidth,
            12,
            40,
            28,
            '${value.ringWidth.round()}',
            (v) => onChanged(value.copyWith(ringWidth: v), 'timer-ring'),
          ),
          const Text(
            '타이머는 화면 밖으로 나가지 않도록 자동으로 맞춰집니다.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
        if (section == SlideAppearanceSection.all ||
            section == SlideAppearanceSection.visibility) ...[
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('화면 제목 표시'),
            subtitle: const Text('꺼도 관리용 슬라이드 제목은 유지됩니다.'),
            value: value.showTitle,
            onChanged: (v) => onChanged(value.copyWith(showTitle: v), null),
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('본문 표시'),
            value: value.showBody,
            onChanged: (v) => onChanged(value.copyWith(showBody: v), null),
          ),
          const Divider(height: 1),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('브랜드 표시'),
            value: value.showBrand,
            onChanged: (v) => onChanged(value.copyWith(showBrand: v), null),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in [
              if (section == SlideAppearanceSection.all ||
                  section == SlideAppearanceSection.background)
                (
                  '제목 색상',
                  value.titleColor,
                  (int v) => value.copyWith(titleColor: v),
                ),
              if (section == SlideAppearanceSection.all ||
                  section == SlideAppearanceSection.background)
                (
                  '본문 색상',
                  value.bodyColor,
                  (int v) => value.copyWith(bodyColor: v),
                ),
              if (section == SlideAppearanceSection.all)
                (
                  '세트 숫자 색상',
                  value.setsColor,
                  (int v) => value.copyWith(setsColor: v),
                ),
              if (section == SlideAppearanceSection.all ||
                  section == SlideAppearanceSection.background)
                (
                  '브랜드 색상',
                  value.brandColor,
                  (int v) => value.copyWith(brandColor: v),
                ),
            ])
              HexColorField(
                compact: true,
                label: item.$1,
                initialValue: colorHex(item.$2),
                onChanged: (input) {
                  final color = parseHexColor(input);
                  if (color != null) onChanged(item.$3(color), item.$1);
                },
              ),
          ],
        ),
      ],
    ),
  );

  Widget _adjust(
    String label,
    double value,
    double min,
    double max,
    int divisions,
    String display,
    ValueChanged<double> change,
  ) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Slider(
              key: ValueKey(label),
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: change,
            ),
          ),
        ],
      ),
    );
  }
}
