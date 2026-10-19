import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const draft = AiSlideDraft(title: 'Original', layout: 'list', lines: []);
const titleField = CenterSlideField(
  binding: 'title',
  x: .1,
  y: .2,
  width: .8,
  height: .3,
  fontSize: 12,
  color: 0xff000000,
  fontFamily: 'Pretendard',
  fontWeight: 700,
  originalText: 'Original',
  clearColor: 0xffffffff,
);

Future<Uint8List> png(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

Future<Uint8List> pixels(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<ui.Image> sourceImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 160, 90),
    Paint()..color = const Color(0xffffffff),
  );
  canvas.drawRect(
    const Rect.fromLTWH(16, 18, 128, 27),
    Paint()..color = const Color(0xff4466cc),
  );
  canvas.drawRect(
    const Rect.fromLTWH(130, 5, 20, 8),
    Paint()..color = const Color(0xffcc8800),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(160, 90);
  } finally {
    picture.dispose();
  }
}

CenterSlideRecipe recipeFor(Uint8List background) {
  final digest = sha256.convert(background).toString();
  return CenterSlideRecipe(
    templateId: 'example',
    revision: 1,
    centerId: 'center-one',
    width: 160,
    height: 90,
    backgroundColor: 0xffffffff,
    backgroundPath: 'center-templates/center-one/example/$digest.png',
    backgroundSha256: digest,
    fields: [titleField],
  );
}

Future<ui.Image> directSource(ui.Image source) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    const Rect.fromLTWH(0, 0, 160, 90),
    const Rect.fromLTWH(0, 0, 1920, 1080),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(1920, 1080);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image source;
  late Uint8List background;
  late CenterSlideRecipe recipe;
  setUpAll(() async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
        ))
        .load();
    source = await sourceImage();
    background = await png(source);
    recipe = recipeFor(background);
  });
  tearDownAll(() => source.dispose());

  test(
    'unchanged text exports 1920x1080 matching direct source pixels',
    () async {
      final bytes = await renderCenterSlide(
        recipe,
        draft,
        backgroundBytes: background,
      );
      final actual = await decode(bytes);
      final expected = await directSource(source);
      try {
        expect(actual.width, 1920);
        expect(actual.height, 1080);
        expect(
          sha256.convert(await pixels(actual)),
          sha256.convert(await pixels(expected)),
        );
      } finally {
        actual.dispose();
        expected.dispose();
      }
    },
  );

  test(
    'editing a field leaves every pixel outside its slot untouched',
    () async {
      final actual = await decode(
        await renderCenterSlide(
          recipe,
          draft.copyWith(title: 'New title'),
          backgroundBytes: background,
        ),
      );
      final expected = await directSource(source);
      try {
        final before = await pixels(expected);
        final after = await pixels(actual);
        var insideChanges = 0;
        var outsideChanges = 0;
        const editable = Rect.fromLTWH(192, 216, 1536, 324);
        for (var y = 0; y < 1080; y++) {
          for (var x = 0; x < 1920; x++) {
            final index = (y * 1920 + x) * 4;
            if (before[index] == after[index] &&
                before[index + 1] == after[index + 1] &&
                before[index + 2] == after[index + 2] &&
                before[index + 3] == after[index + 3]) {
              continue;
            }
            if (editable.contains(Offset(x.toDouble(), y.toDouble()))) {
              insideChanges++;
            } else {
              outsideChanges++;
            }
          }
        }
        expect(insideChanges, greaterThan(100));
        expect(outsideChanges, 0);
      } finally {
        actual.dispose();
        expected.dispose();
      }
    },
  );

  test(
    'empty lines retain indices instead of shifting later content',
    () async {
      final indexed = recipe.copyWith(
        fields: [
          titleField.copyWith(
            binding: 'line',
            lineIndex: 1,
            originalText: 'Repeat',
          ),
        ],
      );
      final actual = await decode(
        await renderCenterSlide(
          indexed,
          draft.copyWith(lines: ['', 'Repeat']),
          backgroundBytes: background,
        ),
      );
      final expected = await directSource(source);
      try {
        expect(
          sha256.convert(await pixels(actual)),
          sha256.convert(await pixels(expected)),
        );
      } finally {
        actual.dispose();
        expected.dispose();
      }
    },
  );

  test(
    'an emptied field removes its source text without moving other pixels',
    () async {
      final indexed = recipe.copyWith(
        fields: [titleField.copyWith(binding: 'line', lineIndex: 0)],
      );
      final image = await decode(
        await renderCenterSlide(
          indexed,
          draft.copyWith(lines: ['']),
          backgroundBytes: background,
        ),
      );
      try {
        final data = await pixels(image);
        final slotCenter = (300 * 1920 + 500) * 4;
        expect(data.sublist(slotCenter, slotCenter + 4), [255, 255, 255, 255]);
        final logoCenter = (100 * 1920 + 1650) * 4;
        expect(data.sublist(logoCenter, logoCenter + 4), [204, 136, 0, 255]);
      } finally {
        image.dispose();
      }
    },
  );

  test('a recipe without an image can create a plain background', () async {
    final plain = recipe.copyWith(
      backgroundPath: null,
      backgroundSha256: null,
      backgroundColor: 0xff123456,
      fields: [],
    );
    final image = await decode(await renderCenterSlide(plain, draft));
    try {
      expect((await pixels(image)).take(4), [0x12, 0x34, 0x56, 0xff]);
    } finally {
      image.dispose();
    }
  });

  test(
    'rejects missing, extra, modified or differently sized image bytes',
    () async {
      await expectLater(
        renderCenterSlide(recipe, draft),
        throwsFormatException,
      );
      final plain = recipe.copyWith(
        backgroundPath: null,
        backgroundSha256: null,
      );
      await expectLater(
        renderCenterSlide(plain, draft, backgroundBytes: background),
        throwsFormatException,
      );
      final digest = List.filled(64, '0').join();
      await expectLater(
        renderCenterSlide(
          recipe.copyWith(
            backgroundSha256: digest,
            backgroundPath: 'center-templates/center-one/example/$digest.png',
          ),
          draft,
          backgroundBytes: background,
        ),
        throwsFormatException,
      );
      await expectLater(
        renderCenterSlide(
          recipe.copyWith(width: 320, height: 180),
          draft,
          backgroundBytes: background,
        ),
        throwsFormatException,
      );
      await expectLater(
        renderCenterSlide(
          recipe,
          draft,
          backgroundBytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects unreadable shrinkage instead of clipping content', () async {
    final narrow = recipe.copyWith(fields: [titleField.copyWith(width: .02)]);
    await expectLater(
      renderCenterSlide(
        narrow,
        draft.copyWith(title: 'A much longer title'),
        backgroundBytes: background,
      ),
      throwsFormatException,
    );
  });

  test('rejects multiline content and unmapped nonempty lines', () async {
    for (final invalid in [
      draft.copyWith(title: ''),
      draft.copyWith(title: 'one\ntwo'),
      draft.copyWith(lines: ['silently lost content']),
      draft.copyWith(designSubtitle: List.filled(121, 'x').join()),
    ]) {
      await expectLater(
        renderCenterSlide(recipe, invalid, backgroundBytes: background),
        throwsFormatException,
      );
    }
  });
}
