import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

/// The same palette editor is used before adding a draft and after saving it.
class SlideDesignColors extends StatelessWidget {
  const SlideDesignColors({
    super.key,
    required this.module,
    required this.onChanged,
  });

  final WorkoutModule module;
  final ValueChanged<WorkoutModule> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('색상 테마', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var i = 0; i < 3; i++)
            HexColorField(
              compact: true,
              compactWidth: 72,
              label: ['배경', '글자', '강조'][i],
              initialValue: colorHex(
                [
                  module.designBackgroundColor ?? 0xFF000000,
                  module.designTextColor ?? 0xFFFFFFFF,
                  module.designAccentColor ?? 0xFFFF343A,
                ][i],
              ),
              onChanged: (value) {
                final color = parseHexColor(value);
                if (color == null) return;
                onChanged(switch (i) {
                  0 => module.copyWith(designBackgroundColor: color),
                  1 => module.copyWith(
                    designTextColor: color,
                    appearance: module.appearance.copyWith(setsColor: color),
                  ),
                  _ => module.copyWith(designAccentColor: color),
                });
              },
            ),
        ],
      ),
    ],
  );
}
