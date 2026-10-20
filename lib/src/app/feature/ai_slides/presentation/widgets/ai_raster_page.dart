import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/ai_raster_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_raster_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_raster_image_controller.dart';

class AiRasterPage extends HookConsumerWidget {
  const AiRasterPage({super.key, this.guard});
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiRasterControllerProvider);
    final controller = ref.read(aiRasterControllerProvider.notifier);
    final brand = state.brand;
    final warning = brand == null
        ? null
        : rasterLayoutError(state.draft, brand);
    final allowed = state.allowed && state.enabled && state.remaining > 0;
    final showSource = useState(false);
    final adding = useState(false);
    final localGuard = useMemoized(ExitGuard.new);
    final exitGuard = guard ?? localGuard;
    return UnsavedChangesGuard(
      guard: exitGuard,
      dirty:
          !adding.value &&
          brand != null &&
          (state.draft != const AiRasterDraft() ||
              state.busy ||
              state.result != null),
      confirmTitle: '수업에 추가하지 않고 나갈까요?',
      confirmMessage:
          '아직 생성하지 않은 입력은 사라집니다. 접수된 생성 요청과 이전 시안은 다시 열어 확인할 수 있어요.',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('센터 AI 이미지'),
          leading: IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await exitGuard.confirm() && context.mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) Navigator.pop(context);
                });
              }
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (state.loading || state.busy)
                    const LinearProgressIndicator(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        state.error!,
                        key: const ValueKey('raster-error'),
                      ),
                    ),
                  if (brand == null) ...[
                    const Text(
                      '센터의 승인 참고 디자인과 공식 로고가 연결되면 사용할 수 있어요. 기존 템플릿은 계속 사용할 수 있어요.',
                    ),
                    TextButton(
                      onPressed: state.loading ? null : controller.load,
                      child: const Text('다시 확인'),
                    ),
                  ] else ...[
                    Text(
                      '${brand.name} · 승인 디자인 ${brand.revision}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '배경은 AI로 만들고 운동 원문과 공식 로고는 정확하게 합성해요. 타이머는 이미지에 그리지 않아요.',
                    ),
                    TextButton.icon(
                      onPressed: () => showSource.value = !showSource.value,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('승인 참고 이미지 · 공식 로고 보기'),
                    ),
                    if (showSource.value)
                      Row(
                        children: [
                          Expanded(
                            child: _RasterSource(
                              brand: brand,
                              kind: 'reference',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RasterSource(brand: brand, kind: 'logo'),
                          ),
                        ],
                      ),
                    if (state.result != null) ...[
                      const SizedBox(height: 12),
                      AiRasterPreview(brand: brand, job: state.result!),
                      if (state.result!.draft != state.draft)
                        const Text(
                          '표시된 시안은 이전 입력의 결과예요. 아래 수정 내용은 새로 생성한 뒤 반영돼요.',
                        ),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: state.busy || state.history.isEmpty
                                ? null
                                : controller.undo,
                            icon: const Icon(Icons.undo),
                            label: const Text('이전 시안으로 되돌리기'),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('raster-add'),
                            onPressed: state.busy
                                ? null
                                : () async {
                                    final module = await controller.add();
                                    if (module != null && context.mounted) {
                                      adding.value = true;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (context.mounted)
                                              Navigator.pop(context, module);
                                          });
                                    }
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('표시한 시안을 수업에 추가'),
                          ),
                        ],
                      ),
                      const Text('추가 후 수업 편집에서 앱 타이머를 설정하고 저장해 주세요.'),
                    ],
                    const SizedBox(height: 20),
                    _RasterField(
                      key: const ValueKey('raster-title'),
                      value: state.draft.title,
                      label: '수업 제목',
                      maxLength: 60,
                      onChanged: (value) =>
                          controller.edit(state.draft.copyWith(title: value)),
                    ),
                    const SizedBox(height: 12),
                    _RasterField(
                      key: const ValueKey('raster-wod'),
                      value: state.draft.rawWod,
                      label: '오늘의 수업 원문',
                      maxLines: 12,
                      maxLength: 6000,
                      onChanged: controller.raw,
                    ),
                    const SizedBox(height: 12),
                    _RasterField(
                      key: const ValueKey('raster-brief'),
                      value: state.draft.brief,
                      label: '요청 또는 수정 사항 (선택)',
                      maxLines: 3,
                      maxLength: 1000,
                      onChanged: (value) =>
                          controller.edit(state.draft.copyWith(brief: value)),
                    ),
                    TextButton(
                      onPressed: controller.applyRequestedSettings,
                      child: const Text('“3개 그룹 / 글자를 작게” 요청을 설정에 적용'),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('본문 크기'),
                        for (final size in [32.0, 38.0, 42.0])
                          ChoiceChip(
                            label: Text(
                              size == 32
                                  ? '작게'
                                  : size == 38
                                  ? '중간'
                                  : '기본',
                            ),
                            selected: state.draft.bodyFontSize == size,
                            onSelected: (_) => controller.edit(
                              state.draft.copyWith(bodyFontSize: size),
                            ),
                          ),
                        const Text('그룹 수'),
                        for (final count in [1, 2, 3])
                          ChoiceChip(
                            label: Text('$count개'),
                            selected: state.draft.groups.length == count,
                            onSelected: (_) => controller.groupCount(count),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '이번 달 AI ${state.remaining}/${state.limit}회 남음 · 내용 정리 1회 / 이미지 생성 1회',
                      key: const ValueKey('raster-quota'),
                    ),
                    const Text(
                      '버튼을 누를 때만 차감해요. 같은 요청의 상태 확인·수업 저장·재생에는 추가 차감이 없어요.',
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey('raster-organize'),
                        onPressed:
                            state.busy ||
                                !allowed ||
                                state.draft.rawWod.trim().isEmpty
                            ? null
                            : controller.organize,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('AI로 그룹 정리 · 1회'),
                      ),
                    ),
                    const Text('그룹 제목을 수정하거나 원하는 줄 뒤에서 나눠 주세요. 직접 나누기는 무료예요.'),
                    for (final (index, group) in state.draft.groups.indexed)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RasterField(
                                key: ValueKey('raster-group-$index'),
                                value: group.heading,
                                label: '그룹 ${index + 1}',
                                maxLength: 60,
                                onChanged: (value) =>
                                    controller.heading(index, value),
                              ),
                              for (final (lineIndex, line)
                                  in group.lines.indexed)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 5,
                                        ),
                                        child: Text(line),
                                      ),
                                    ),
                                    if (state.draft.groups.length < 3 &&
                                        lineIndex < group.lines.length - 1)
                                      IconButton(
                                        tooltip: '이 줄 뒤에서 그룹 나누기',
                                        icon: const Icon(Icons.call_split),
                                        onPressed: () => controller.split(
                                          index,
                                          lineIndex + 1,
                                        ),
                                      ),
                                  ],
                                ),
                              if (index > 0)
                                TextButton(
                                  onPressed: () => controller.merge(index),
                                  child: const Text('앞 그룹과 합치기'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (warning != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(warning),
                      ),
                    if (state.pendingRequestId != null) ...[
                      const Text(
                        '이 요청은 처리 중이거나 결과 확인이 필요해요. 같은 요청을 다시 생성하지 않습니다.',
                      ),
                      OutlinedButton(
                        key: const ValueKey('raster-status'),
                        onPressed: state.busy ? null : controller.refreshResult,
                        child: const Text('결과 상태 확인 · 추가 차감 없음'),
                      ),
                      if (state.pendingStatus == 'uncertain')
                        TextButton(
                          onPressed: state.busy ? null : controller.newRequest,
                          child: const Text('별도 새 요청으로 전환 (다음 생성은 1회 추가 차감)'),
                        ),
                    ],
                    FilledButton.icon(
                      key: const ValueKey('raster-generate'),
                      onPressed:
                          state.busy ||
                              !allowed ||
                              state.pendingRequestId != null ||
                              warning != null
                          ? null
                          : controller.generate,
                      icon: const Icon(Icons.image),
                      label: Text(
                        state.busy
                            ? '처리 중… 이전 결과는 유지돼요'
                            : '이미지 ${state.result == null ? '생성' : '다시 생성'} · 1회',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RasterField extends HookWidget {
  const _RasterField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
    required this.maxLength,
  });
  final String value, label;
  final ValueChanged<String> onChanged;
  final int maxLines, maxLength;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text != value && !controller.value.composing.isValid) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(
            offset: controller.selection.baseOffset.clamp(0, value.length),
          ),
        );
      }
      return null;
    }, [value]);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _RasterSource extends ConsumerWidget {
  const _RasterSource({required this.brand, required this.kind});
  final AiRasterBrand brand;
  final String kind;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(aiRasterImageProvider(brand, null, kind));
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: rasterColor(brand.backgroundColor),
        child: image.when(
          data: (value) => value == null
              ? const SizedBox.shrink()
              : kind == 'reference'
              ? RawImage(image: value, fit: BoxFit.contain)
              : CustomPaint(painter: _LogoPainter(value, brand)),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(aiRasterImageProvider(brand, null, kind)),
            child: const Text('다시 불러오기'),
          ),
          loading: () => const Center(child: Text('이미지 준비 중…')),
        ),
      ),
    );
  }
}

class AiRasterPreview extends HookConsumerWidget {
  const AiRasterPreview({super.key, required this.brand, required this.job});
  final AiRasterBrand brand;
  final AiRasterJob job;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artwork = ref.watch(aiRasterImageProvider(brand, job, 'artwork'));
    final logo = ref.watch(aiRasterImageProvider(brand, null, 'logo'));
    final warning = rasterLayoutError(job.draft, brand);
    final layout = useMemoized(
      () => warning == null ? AiRasterLayout(job.draft, brand) : null,
      [job.draft, brand],
    );
    useEffect(() => layout?.dispose, [layout]);
    final ready =
        !artwork.isLoading &&
        !logo.isLoading &&
        !artwork.hasError &&
        !logo.hasError &&
        artwork.value != null &&
        logo.value != null;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: rasterColor(brand.backgroundColor),
        child: warning != null
            ? Center(child: Text(warning))
            : ready
            ? CustomPaint(
                key: const ValueKey('raster-direct-preview'),
                painter: _RasterPainter(layout!, artwork.value!, logo.value!),
              )
            : Center(
                child: artwork.hasError || logo.hasError
                    ? TextButton(
                        onPressed: () {
                          ref.invalidate(
                            aiRasterImageProvider(brand, job, 'artwork'),
                          );
                          ref.invalidate(
                            aiRasterImageProvider(brand, null, 'logo'),
                          );
                        },
                        child: const Text('시안 다시 불러오기'),
                      )
                    : const Text('시안 준비 중…'),
              ),
      ),
    );
  }
}

class _RasterPainter extends CustomPainter {
  const _RasterPainter(this.layout, this.artwork, this.logo);
  final AiRasterLayout layout;
  final ui.Image artwork, logo;
  @override
  void paint(Canvas canvas, Size size) =>
      layout.paint(canvas, size, artwork, logo);
  @override
  bool shouldRepaint(_RasterPainter old) =>
      layout != old.layout || artwork != old.artwork || logo != old.logo;
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.image, this.brand);
  final ui.Image image;
  final AiRasterBrand brand;
  @override
  void paint(Canvas canvas, Size size) {
    final crop = brand.logo.sourceRect, scale = image.width / brand.logo.width;
    final height = size.width * crop[3] / crop[2];
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        crop[0] * scale,
        crop[1] * scale,
        crop[2] * scale,
        crop[3] * scale,
      ),
      Rect.fromLTWH(0, (size.height - height) / 2, size.width, height),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      image != old.image || brand != old.brand;
}
