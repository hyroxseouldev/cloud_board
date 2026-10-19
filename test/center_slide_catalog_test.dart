import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/center_slide_catalog_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

CenterSlideRecipe _recipe([Uint8List? bytes]) {
  final digest = bytes == null ? null : sha256.convert(bytes).toString();
  return CenterSlideRecipe(
    templateId: 'custom',
    revision: 1,
    centerId: 'center-a',
    width: 16,
    height: 9,
    backgroundColor: 0xff000000,
    fields: const [],
    backgroundPath: digest == null
        ? null
        : 'center-templates/center-a/custom/$digest.png',
    backgroundSha256: digest,
  );
}

Map<String, dynamic> _entry({
  String id = 'original',
  int order = 0,
  bool published = true,
  CenterSlideRecipe? recipe,
}) => {
  'id': recipe?.templateId ?? id,
  'name': '우리 수업',
  'description': '',
  'sortOrder': order,
  'published': published,
  if (recipe == null) 'originalTemplateId': 'stationd-mon-v1',
  if (recipe != null) 'recipe': recipe.toJson(),
};
Map<String, dynamic> _catalog(
  List<Map<String, dynamic>> entries, {
  int revision = 1,
}) => {
  'schemaVersion': 1,
  'revision': revision,
  'centerName': '',
  'templates': entries,
};
CenterSlideCatalogModel _parse(
  Map<String, dynamic> json, {
  bool strict = false,
}) => CenterSlideCatalogModel.fromJson(
  json,
  centerId: 'center-a',
  rejectInvalidItems: strict,
);
Matcher _failure(String code) =>
    isA<AiSlidesFailure>().having((error) => error.code, 'code', code);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('concurrent previews share one image fetch and receive independent bytes', () async {
    final gate = Completer<void>();
    final entered = Completer<void>();
    final fixture = _Fixture(beforeResponse: () async {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    });
    addTearDown(fixture.close);
    final first = fixture.source.loadBackground('owner-a', fixture.recipe);
    final second = fixture.source.loadBackground('owner-a', fixture.recipe);
    await entered.future;
    await _flush();
    expect(fixture.requests, 1);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(results[0], fixture.bytes);
    expect(results[1], fixture.bytes);
    results[0]![0] = 0;
    expect(results[1], fixture.bytes);
  });

  test('catalog generation change never shares the old in-flight transfer', () async {
    final gate = Completer<void>();
    final entered = Completer<void>();
    var responses = 0;
    final fixture = _Fixture(beforeResponse: () async {
      responses++;
      if (responses == 1) {
        entered.complete();
        await gate.future;
      }
    });
    addTearDown(fixture.close);
    final subscription = fixture.source.watchCatalog('owner-a', 'center-a').listen((_) {});
    addTearDown(subscription.cancel);
    final stale = expectLater(fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_scope_changed')));
    await entered.future;
    fixture.events.add(CenterSlideDocument(
      data: _catalog([_entry(recipe: fixture.recipe)], revision: 2), fromCache: false));
    await _flush();
    final current = await fixture.source.loadBackground('owner-a', fixture.recipe);
    expect(current, fixture.bytes);
    expect(fixture.requests, 2);
    gate.complete();
    await stale;
  });

  test('failed shared image request is removed so a later attempt can retry', () async {
    final gate = Completer<void>();
    final entered = Completer<void>();
    final fixture = _Fixture(tamper: true, beforeResponse: () async {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    });
    addTearDown(fixture.close);
    final first = expectLater(fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_asset_integrity')));
    final second = expectLater(fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_asset_integrity')));
    await entered.future;
    await _flush();
    expect(fixture.requests, 1);
    gate.complete();
    await Future.wait([first, second]);
    await expectLater(fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_asset_integrity')));
    expect(fixture.requests, 2);
  });

  test(
    'omitted remote sample preserves source text and sparse line positions',
    () {
      const field = CenterSlideField(
        binding: 'title',
        x: 0,
        y: 0,
        width: 1,
        height: 0.1,
        fontSize: 24,
        color: 0xffffffff,
        fontFamily: 'Pretendard',
        fontWeight: 700,
      );
      final recipe = _recipe().copyWith(
        fields: [
          field.copyWith(originalText: 'Team of 3'),
          field.copyWith(binding: 'subtitle', originalText: '원본 부제'),
          field.copyWith(binding: 'header', originalText: '원본 안내'),
          field.copyWith(
            binding: 'line',
            lineIndex: 3,
            originalText: '  20 REPS  ',
          ),
          field.copyWith(binding: 'line', lineIndex: 1, originalText: 'SQUAT'),
          field.copyWith(binding: 'line', lineIndex: 5),
        ],
      );
      final model = _parse(_catalog([_entry(recipe: recipe)]), strict: true);
      final sample = model.toEntity().templates.single.sample!;
      expect(sample.title, 'Team of 3');
      expect(sample.designSubtitle, '원본 부제');
      expect(sample.designHeaderLabel, '원본 안내');
      expect(sample.lines, ['', 'SQUAT', '', '  20 REPS  ', '', '']);
      expect(sample.centerRecipe, recipe);
      // Derivation does not change the operator's source JSON contract.
      expect(
        (model.toJson()['templates'] as List).single.containsKey('sample'),
        false,
      );
    },
  );

  test('explicit remote sample wins over original text defaults', () {
    const title = CenterSlideField(
      binding: 'title',
      x: 0,
      y: 0,
      width: 1,
      height: 0.1,
      fontSize: 24,
      color: 0xffffffff,
      fontFamily: 'Pretendard',
      fontWeight: 700,
      originalText: '원본 제목',
    );
    final recipe = _recipe().copyWith(fields: [title]);
    final entry = {
      ..._entry(recipe: recipe),
      'sample': {
        'title': '운영자 샘플',
        'lines': ['운영자 내용'],
      },
    };
    final sample = _parse(
      _catalog([entry]),
      strict: true,
    ).toEntity().templates.single.sample!;
    expect(sample.title, '운영자 샘플');
    expect(sample.lines, ['운영자 내용']);
  });

  test('empty catalog never falls back to the seven bundled originals', () {
    final result = _parse(_catalog([]), strict: true);
    expect(result.toEntity().templates, isEmpty);
    expect(result.toEntity().centerName, '');
  });

  test('canonical output retains unpublished entries while UI hides them', () {
    final result = _parse(_catalog([_entry(published: false)]), strict: true);
    expect(result.toEntity().templates, isEmpty);
    expect((result.toJson()['templates'] as List).single['published'], false);
  });

  test('app filters malformed items, operator rejects the entire input', () {
    final input = _catalog([
      _entry(id: 'z', order: 1),
      _entry(id: 'a', order: 1),
      {..._entry(id: 'bad'), 'sortOrder': 0.5},
      {..._entry(id: 'unknown'), 'originalTemplateId': 'private-unknown'},
    ]);
    expect(_parse(input).toEntity().templates.map((item) => item.id), [
      'a',
      'z',
    ]);
    expect(() => _parse(input, strict: true), throwsFormatException);
  });

  test(
    'wrong center, duplicate ids and mixed rendering contracts are rejected',
    () {
      for (final entries in <List<Map<String, dynamic>>>[
        [_entry(recipe: _recipe().copyWith(centerId: 'other'))],
        [_entry(), _entry()],
        [
          {
            ..._entry(recipe: _recipe()),
            'originalTemplateId': 'stationd-mon-v1',
          },
        ],
        [
          {..._entry(recipe: _recipe()), 'id': 'mismatch'},
        ],
      ]) {
        expect(
          () => _parse(_catalog(entries), strict: true),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'remote entity keeps recipe in theme and sample with no legacy style',
    () {
      final recipe = _recipe();
      final entity = _parse(
        _catalog([_entry(recipe: recipe)]),
        strict: true,
      ).toEntity().templates.single;
      expect(entity.theme.centerRecipe, recipe);
      expect(entity.theme.designStyle, isNull);
      expect(entity.sample!.centerRecipe, recipe);
    },
  );

  test(
    'cached Firestore snapshot cannot establish or extend six-hour authority',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final values = <CenterSlideCatalog>[];
      final subscription = fixture.source
          .watchCatalog('owner-a', 'center-a')
          .listen(values.add);
      addTearDown(subscription.cancel);
      fixture.events.add(
        CenterSlideDocument(data: fixture.document, fromCache: true),
      );
      await _flush();
      expect(values.last.templates, isEmpty);
      fixture.events.add(
        CenterSlideDocument(data: fixture.document, fromCache: false),
      );
      await _flush();
      expect(values.last.templates, hasLength(1));
      fixture.clock = fixture.clock.add(const Duration(hours: 5));
      fixture.events.add(
        CenterSlideDocument(data: fixture.document, fromCache: true),
      );
      await _flush();
      expect(values.last.templates, hasLength(1));
      fixture.clock = fixture.clock.add(const Duration(hours: 1));
      fixture.events.add(
        CenterSlideDocument(data: fixture.document, fromCache: true),
      );
      await _flush();
      expect(values.last.templates, isEmpty);
    },
  );

  test(
    'private HTTP uses authorization header, validates bytes, and copies cache',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final first = (await fixture.source.loadBackground(
        'owner-a',
        fixture.recipe,
      ))!;
      expect(first, fixture.bytes);
      expect(fixture.lastRequest!.url.scheme, 'https');
      expect(fixture.lastRequest!.url.host, 'firebasestorage.googleapis.com');
      expect(fixture.lastRequest!.url.queryParameters, {'alt': 'media'});
      expect(
        fixture.lastRequest!.headers['Authorization'],
        'Firebase test-id-token',
      );
      expect(fixture.lastRequest!.followRedirects, false);
      first[0] = 0;
      final second = (await fixture.source.loadBackground(
        'owner-a',
        fixture.recipe,
      ))!;
      expect(second, fixture.bytes);
      expect(fixture.requests, 1);
    },
  );

  test('permission denial clears image and catalog authority', () async {
    final fixture = _Fixture();
    addTearDown(fixture.close);
    final values = <CenterSlideCatalog>[];
    final subscription = fixture.source
        .watchCatalog('owner-a', 'center-a')
        .listen(values.add);
    addTearDown(subscription.cancel);
    await fixture.source.loadBackground('owner-a', fixture.recipe);
    await _flush();
    fixture.events.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await _flush();
    expect(values.last.templates, isEmpty);
    fixture.serverError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await expectLater(
      fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(isA<FirebaseException>()),
    );
    expect(fixture.requests, 1);
  });

  test(
    'unpublished recipe cannot render through an old selected draft',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final subscription = fixture.source
          .watchCatalog('owner-a', 'center-a')
          .listen((_) {});
      addTearDown(subscription.cancel);
      await fixture.source.loadBackground('owner-a', fixture.recipe);
      fixture.events.add(
        CenterSlideDocument(data: _catalog([], revision: 2), fromCache: false),
      );
      await _flush();
      await expectLater(
        fixture.source.loadBackground('owner-a', fixture.recipe),
        throwsA(_failure('center_recipe_unavailable')),
      );
      expect(fixture.requests, 1);
    },
  );

  test('late HTTP response after account switch is rejected', () async {
    final gate = Completer<void>();
    final entered = Completer<void>();
    final fixture = _Fixture(
      beforeResponse: () async {
        entered.complete();
        await gate.future;
      },
    );
    addTearDown(fixture.close);
    final pending = fixture.source.loadBackground('owner-a', fixture.recipe);
    final expectation = expectLater(
      pending,
      throwsA(_failure('center_scope_changed')),
    );
    await entered.future;
    fixture.current = false;
    gate.complete();
    await expectation;
  });

  test('tampered bytes are never accepted or cached', () async {
    final fixture = _Fixture(tamper: true);
    addTearDown(fixture.close);
    await expectLater(
      fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_asset_integrity')),
    );
    await expectLater(
      fixture.source.loadBackground('owner-a', fixture.recipe),
      throwsA(_failure('center_asset_integrity')),
    );
    expect(fixture.requests, 2);
  });

  test(
    'closed scope cannot be reused even when the same account returns',
    () async {
      final fixture = _Fixture();
      fixture.source.clear();
      addTearDown(fixture.close);
      await expectLater(
        fixture.source.loadBackground('owner-a', fixture.recipe),
        throwsA(_failure('center_scope_changed')),
      );
    },
  );
}

class _Fixture {
  _Fixture({Future<void> Function()? beforeResponse, bool tamper = false}) {
    bytes = Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 9)));
    recipe = _recipe(bytes);
    document = _catalog([_entry(recipe: recipe)]);
    source = CenterSlideCatalogDataSource(
      projectId: 'test-project',
      ownerId: 'owner-a',
      centerId: 'center-a',
      bucket: 'test-project.firebasestorage.app',
      isCurrentIdentity: () => current,
      idToken: () async => 'test-id-token',
      documents: () => events.stream,
      readServerDocument: () async {
        if (serverError != null) throw serverError!;
        return CenterSlideDocument(data: document, fromCache: false);
      },
      now: () => clock,
      client: MockClient.streaming((request, _) async {
        requests++;
        lastRequest = request;
        await beforeResponse?.call();
        final response = Uint8List.fromList(bytes);
        if (tamper) response[response.length - 1] ^= 1;
        return http.StreamedResponse(
          Stream.value(response),
          200,
          contentLength: response.length,
        );
      }),
    );
  }
  final events = StreamController<CenterSlideDocument>.broadcast(sync: true);
  DateTime clock = DateTime.utc(2026, 10, 19);
  bool current = true;
  Object? serverError;
  int requests = 0;
  http.BaseRequest? lastRequest;
  late final Uint8List bytes;
  late final CenterSlideRecipe recipe;
  late final Map<String, dynamic> document;
  late final CenterSlideCatalogDataSource source;
  Future<void> close() async {
    source.clear();
    await events.close();
  }
}
