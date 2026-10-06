import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class AiSlidesDesignEditor extends StatelessWidget {
  const AiSlidesDesignEditor({
    super.key,
    required this.draft,
    required this.state,
    required this.onChanged,
    required this.onSaveTheme,
    required this.onApplyTheme,
  });
  final AiSlideDraft draft;
  final AiSlidesEditorState state;
  final ValueChanged<AiSlideDraft> onChanged;
  final VoidCallback onSaveTheme, onApplyTheme;
  @override
  Widget build(BuildContext context) {
    final module = previewAiSlide(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('배치', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final choice in const {
                'auto': '큰 글씨',
                'columns': '2열',
                'cards': '섹션 카드',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 130,
                    child: InkWell(
                      key: ValueKey('ai-layout-${choice.key}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          onChanged(draft.copyWith(designLayout: choice.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: 2,
                            color: draft.designLayout == choice.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            ExcludeSemantics(
                              child: WorkoutSlidePreview(
                                module: module.copyWith(
                                  designLayout: choice.key,
                                ),
                                isRest: false,
                                borderRadius: 6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              choice.value,
                              style: const TextStyle(fontSize: 12),
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
        const SizedBox(height: 18),
        SlideDesignColors(
          module: module,
          onChanged: (value) => onChanged(
            draft.copyWith(
              designBackgroundColor: value.designBackgroundColor,
              designTextColor: value.designTextColor,
              designAccentColor: value.designAccentColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('글씨', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const {700: '굵게', 900: '아주 굵게'}.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: draft.designFontWeight == option.key,
                onSelected: (_) =>
                    onChanged(draft.copyWith(designFontWeight: option.key)),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('기울임'),
          value: draft.designItalic,
          onChanged: (value) => onChanged(draft.copyWith(designItalic: value)),
        ),
        const Text('간격', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final option in {.85: '좁게', 1.0: '기본', 1.15: '넓게'}.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: (draft.designSpacing - option.key).abs() < .01,
                onSelected: (_) =>
                    onChanged(draft.copyWith(designSpacing: option.key)),
              ),
          ],
        ),
        const Divider(height: 28),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('타이머 표시'),
          value: draft.showTimer,
          onChanged: (value) => onChanged(draft.copyWith(showTimer: value)),
        ),
        if (draft.showTimer) ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('왼쪽'),
                selected: draft.timerX < .5,
                onSelected: (_) => onChanged(draft.copyWith(timerX: .16)),
              ),
              ChoiceChip(
                label: const Text('오른쪽'),
                selected: draft.timerX >= .5,
                onSelected: (_) => onChanged(draft.copyWith(timerX: .84)),
              ),
            ],
          ),
          Row(
            children: [
              const Text('크기'),
              Expanded(
                child: Slider(
                  value: draft.timerSize.clamp(.7, 1.25),
                  min: .7,
                  max: 1.25,
                  onChanged: (value) =>
                      onChanged(draft.copyWith(timerSize: value)),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 28),
        const Text('우리 센터 테마', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '저장한 색상·글씨·배치를 다음 수업에도 적용해요.',
          style: TextStyle(fontSize: 12),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('ai-theme-save'),
              onPressed: state.themeSaving ? null : onSaveTheme,
              icon: Icon(
                state.themeSaved
                    ? Icons.check_rounded
                    : Icons.bookmark_border_rounded,
                size: 18,
              ),
              label: Text(
                state.themeSaving
                    ? '저장 중…'
                    : state.themeSaved
                    ? '테마 저장됨'
                    : '현재 테마 저장',
              ),
            ),
            if (state.theme != null)
              TextButton(
                onPressed: onApplyTheme,
                child: const Text('저장한 테마 적용'),
              ),
          ],
        ),
        if (state.themeError != null)
          AiSlidesNotice(state.themeError!, error: true),
      ],
    );
  }
}
