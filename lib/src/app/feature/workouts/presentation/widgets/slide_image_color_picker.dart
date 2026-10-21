import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/image_color_sampling.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

Future<Color?> showSlideImageColorPicker(BuildContext context, String source) =>
    showDialog<Color>(
      context: context,
      builder: (_) =>
          Dialog.fullscreen(child: SlideImageColorPicker(source: source)),
    );

/// Samples original decoded pixels, never the slide renderer or a screen grab.
class SlideImageColorPicker extends HookWidget {
  const SlideImageColorPicker({super.key, required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final pixels = useState<ImageColorPixels?>(null);
    final error = useState<String?>(null);
    final retry = useState(0);
    final selected = useState<Offset?>(null);
    final hint = useState<String?>(null);
    final transform = useMemoized(TransformationController.new);
    useEffect(() => transform.dispose, [transform]);
    useListenable(transform);
    final configuration = createLocalImageConfiguration(context);
    useEffect(() {
      var active = true;
      ImageColorRead? request;
      ImageColorPixels? owned;
      pixels.value = null;
      error.value = null;
      selected.value = null;
      hint.value = null;
      transform.value = Matrix4.identity();
      if (source.trim().isEmpty) {
        error.value = '현재 슬라이드에 이미지가 없어요. 돌아가서 수동으로 색상을 선택해 주세요.';
      } else {
        try {
          request = ImageColorRead(
            workoutImageProvider(source, (
              width: null,
              height: null,
            ), webHtmlElementStrategy: WebHtmlElementStrategy.never),
            configuration,
          );
          request.future.then(
            (value) {
              if (!active) {
                value.dispose();
                return;
              }
              owned = value;
              pixels.value = value;
            },
            onError: (Object _) {
              if (active) {
                error.value = '이미지에서 색상을 읽지 못했어요. 다시 불러오거나 돌아가서 수동으로 선택해 주세요.';
              }
            },
          );
        } catch (_) {
          error.value = '이 이미지는 색상을 읽을 수 없어요. 돌아가서 수동으로 선택해 주세요.';
        }
      }
      return () {
        active = false;
        request?.cancel();
        owned?.dispose();
      };
    }, [source, retry.value, configuration]);
    final image = pixels.value;
    final color = image == null || selected.value == null
        ? null
        : image.colorAt(selected.value!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지에서 색상 뽑기'),
        leading: IconButton(
          tooltip: '색상 추출 취소',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '이미지를 확대·이동한 뒤 원하는 지점을 눌러 주세요.\n색상 선택창에서 최종 적용하기 전에는 변경되지 않아요.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: image == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: error.value == null
                            ? const CircularProgressIndicator()
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      error.value!,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (source.trim().isNotEmpty)
                                      TextButton(
                                        onPressed: () => retry.value++,
                                        child: const Text('다시 불러오기'),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, bounds) {
                        final viewport = bounds.biggest;
                        final rect = containedImageRect(image.size, viewport);
                        final scale = transform.value.getMaxScaleOnAxis();
                        void zoom(double next) {
                          final center = viewport.center(Offset.zero);
                          final scene = transform.toScene(center);
                          transform.value =
                              Matrix4.diagonal3Values(next, next, 1)
                                ..setTranslationRaw(
                                  center.dx - scene.dx * next,
                                  center.dy - scene.dy * next,
                                  0,
                                );
                        }

                        final pixel = selected.value;
                        final marker = pixel == null
                            ? null
                            : Offset(
                                rect.left +
                                    (pixel.dx + .5) *
                                        rect.width /
                                        image.size.width,
                                rect.top +
                                    (pixel.dy + .5) *
                                        rect.height /
                                        image.size.height,
                              );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: GestureDetector(
                                key: const ValueKey('image-color-viewport'),
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (event) {
                                  final pixel = imagePixelAt(
                                    position: event.localPosition,
                                    viewport: viewport,
                                    image: image.size,
                                    transform: transform.value,
                                  );
                                  if (pixel == null) {
                                    hint.value = '이미지 안의 지점을 선택해 주세요. 바깥 여백은 색상을 읽지 않아요.';
                                    selected.value = null;
                                  } else if (image.colorAt(pixel) == null) {
                                    hint.value = '완전히 투명한 픽셀은 사용할 수 없어요. 다른 지점을 선택해 주세요.';
                                    selected.value = null;
                                  } else {
                                    hint.value = null;
                                    selected.value = pixel;
                                  }
                                },
                                child: InteractiveViewer(
                                  transformationController: transform,
                                  minScale: 1,
                                  maxScale: 8,
                                  child: SizedBox.fromSize(
                                    size: viewport,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: RawImage(
                                            image: image.image,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        if (marker != null)
                                          Positioned(
                                            left: marker.dx - 12 / scale,
                                            top: marker.dy - 12 / scale,
                                            child: IgnorePointer(
                                              child: Icon(
                                                Icons.add_circle_outline,
                                                size: 24 / scale,
                                                color: Colors.white,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: '이미지 축소',
                                      onPressed: scale <= 1
                                          ? null
                                          : () =>
                                                zoom((scale / 1.5).clamp(1, 8)),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    IconButton(
                                      tooltip: '이미지 확대',
                                      onPressed: scale >= 8
                                          ? null
                                          : () =>
                                                zoom((scale * 1.5).clamp(1, 8)),
                                      icon: const Icon(Icons.add),
                                    ),
                                    IconButton(
                                      tooltip: '확대 초기화',
                                      onPressed: () =>
                                          transform.value = Matrix4.identity(),
                                      icon: const Icon(Icons.fit_screen),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hint.value != null)
                    Text(hint.value!, textAlign: TextAlign.center),
                  if (color != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          colorHex(color.toARGB32()),
                          key: const ValueKey('image-picked-color'),
                        ),
                      ],
                    )
                  else
                    const Text('선택한 색상이 없어요.'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('image-color-accept'),
                          onPressed: color == null
                              ? null
                              : () => Navigator.pop(context, color),
                          child: const Text('이 색상 사용'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
