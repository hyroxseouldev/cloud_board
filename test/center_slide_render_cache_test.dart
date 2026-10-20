import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/center_slide_catalog_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/center_slide_template_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

const _recipe = CenterSlideRecipe(
  templateId: 'custom',
  revision: 1,
  centerId: 'center',
  width: 16,
  height: 9,
  backgroundColor: 0xff000000,
  fields: [],
);
const _draft = AiSlideDraft(
  title: 'Workout',
  layout: 'list',
  lines: ['Row'],
  centerRecipe: _recipe,
  workSeconds: 60,
  restSeconds: 0,
  sets: 1,
);
Matcher _failure(String code) =>
    isA<AiSlidesFailure>().having((error) => error.code, 'code', code);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _Fixture {
  _Fixture({CenterSlideDraftRenderer? renderer}) {
    source = CenterSlideCatalogDataSource(
      projectId: 'demo',
      ownerId: 'owner',
      centerId: 'center',
      bucket: 'demo.appspot.com',
      isCurrentIdentity: () => current,
      idToken: () async => 'unused',
      documents: () => events.stream,
      readServerDocument: () async {
        authorityReads++;
        if (authorityError != null) throw authorityError!;
        return document();
      },
      now: () => now,
      client: MockClient(
        (_) => throw StateError('No background download needed'),
      ),
    );
    repository = CenterSlideTemplateRepositoryImpl(
      source,
      renderer: (recipe, draft, {backgroundBytes}) async {
        renders++;
        if (renderer != null) {
          return renderer(recipe, draft, backgroundBytes: backgroundBytes);
        }
        return Uint8List.fromList([renders, 2, 3]);
      },
    );
    subscription = repository.watchCatalog('owner', 'center').listen((_) {});
  }
  final events = StreamController<CenterSlideDocument>.broadcast();
  late final CenterSlideCatalogDataSource source;
  late final CenterSlideTemplateRepositoryImpl repository;
  late final StreamSubscription<Object> subscription;
  CenterSlideRecipe recipe = _recipe;
  int revision = 1, renders = 0, authorityReads = 0;
  bool current = true, published = true;
  Object? authorityError;
  DateTime now = DateTime.utc(2026, 10, 20);
  CenterSlideDocument document() => CenterSlideDocument(
    fromCache: false,
    data: {
      'schemaVersion': 1,
      'revision': revision,
      'centerName': '',
      'templates': [
        {
          'id': recipe.templateId,
          'name': 'Template',
          'description': '',
          'sortOrder': 0,
          'published': published,
          'recipe': recipe.toJson(),
        },
      ],
    },
  );
  Future<Uint8List> render([AiSlideDraft draft = _draft]) =>
      repository.renderDraft('owner', draft);
  Future<void> update() async {
    events.add(document());
    await _flush();
  }

  Future<void> close() async {
    repository.clear();
    await subscription.cancel();
    await events.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unchanged preview and Add reuse one PNG with independent returned bytes',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      final preview = await f.render();
      preview[0] = 99;
      final added = await f.render();
      expect(added, [1, 2, 3]);
      expect(f.renders, 1);
      expect(f.authorityReads, 1);
    },
  );

  test('Add shares the exact preview currently rendering', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final f = _Fixture(
      renderer: (_, draft, {backgroundBytes}) async {
        entered.complete();
        await release.future;
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    addTearDown(f.close);
    final preview = f.render();
    await entered.future;
    final added = f.render();
    await _flush();
    expect(f.renders, 1);
    release.complete();
    final result = await Future.wait([preview, added]);
    expect(result[0], result[1]);
    expect(identical(result[0], result[1]), isFalse);
  });

  for (final changed in [
    _draft.copyWith(title: 'Edited'),
    _draft.copyWith(lines: ['Bike']),
    _draft.copyWith(designSubtitle: 'Team'),
    _draft.copyWith(workSeconds: 120),
    _draft.copyWith(restSeconds: 15),
    _draft.copyWith(sets: 3),
  ]) {
    test('draft change invalidates the retained result: $changed', () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.render();
      await f.render(changed);
      await f.render();
      expect(f.renders, 3); // Only the latest draft is retained.
    });
  }

  test(
    'caller mutation of a draft list cannot change the cached key',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      final lines = ['Row'];
      final draft = _draft.copyWith(lines: lines);
      await f.render(draft);
      lines[0] = 'Bike';
      await f.render(draft);
      expect(f.renders, 2);
    },
  );

  test(
    'catalog generation and recipe revision invalidate completed PNGs',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.render();
      f.revision++;
      await f.update();
      await f.render();
      expect(f.renders, 2);
      f.revision++;
      f.recipe = f.recipe.copyWith(revision: 2);
      await f.update();
      await expectLater(
        f.render(),
        throwsA(_failure('center_recipe_unavailable')),
      );
      await f.render(_draft.copyWith(centerRecipe: f.recipe));
      expect(f.renders, 3);
    },
  );

  test(
    'unpublished or permission-denied catalog cannot reuse cached PNG',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.render();
      f.published = false;
      f.revision++;
      await f.update();
      await expectLater(
        f.render(),
        throwsA(_failure('center_recipe_unavailable')),
      );
      f.published = true;
      f.revision++;
      await f.update();
      await f.render();
      expect(f.renders, 2);
      f.authorityError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      f.events.addError(f.authorityError!);
      await _flush();
      await expectLater(f.render(), throwsA(isA<FirebaseException>()));
      f.authorityError = null;
      await f.render();
      expect(f.renders, 3);
    },
  );

  test(
    'authority expiry rechecks the server and drops even an unchanged result',
    () async {
      final f = _Fixture();
      addTearDown(f.close);
      await f.render();
      f.now = f.now.add(centerSlideAuthorityLifetime);
      await f.render();
      expect(f.authorityReads, 2);
      expect(f.renders, 2);
    },
  );

  test('account and center mismatches never return retained PNG', () async {
    final f = _Fixture();
    addTearDown(f.close);
    await f.render();
    await expectLater(
      f.repository.renderDraft('other', _draft),
      throwsA(_failure('center_scope_changed')),
    );
    await expectLater(
      f.render(
        _draft.copyWith(centerRecipe: _recipe.copyWith(centerId: 'other')),
      ),
      throwsA(_failure('center_scope_changed')),
    );
    f.current = false;
    await expectLater(f.render(), throwsA(_failure('center_scope_changed')));
    expect(f.renders, 1);
  });

  for (final dispose in [false, true]) {
    test(
      'late rendering cannot return bytes after ${dispose ? 'dispose' : 'catalog revocation'}',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        final f = _Fixture(
          renderer: (_, draft, {backgroundBytes}) async {
            entered.complete();
            await release.future;
            return Uint8List(3);
          },
        );
        addTearDown(f.close);
        final rejected = expectLater(
          f.render(),
          throwsA(_failure('center_scope_changed')),
        );
        await entered.future;
        if (dispose) {
          f.repository.clear();
        } else {
          f.events.add(const CenterSlideDocument(data: null, fromCache: false));
          await _flush();
        }
        release.complete();
        await rejected;
      },
    );
  }

  test(
    'an older draft completion cannot overwrite the latest retained PNG',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final f = _Fixture(
        renderer: (_, draft, {backgroundBytes}) async {
          if (draft.title == _draft.title) {
            entered.complete();
            await release.future;
          }
          return Uint8List.fromList([draft.title.length]);
        },
      );
      addTearDown(f.close);
      final old = f.render();
      await entered.future;
      final newer = _draft.copyWith(title: 'New');
      final expected = await f.render(newer);
      release.complete();
      await old;
      expect(await f.render(newer), expected);
      expect(f.renders, 2);
    },
  );

  test('oversized rendered PNG is returned but never retained', () async {
    final f = _Fixture(
      renderer: (_, draft, {backgroundBytes}) async =>
          Uint8List(centerSlideRenderedCacheMaxBytes + 1),
    );
    addTearDown(f.close);
    expect((await f.render()).length, centerSlideRenderedCacheMaxBytes + 1);
    await f.render();
    expect(f.renders, 2);
  });

  test('failed rendering is not cached and can be retried', () async {
    var fail = true;
    final f = _Fixture(
      renderer: (_, draft, {backgroundBytes}) async {
        if (fail) throw const FormatException('Overflow');
        return Uint8List(3);
      },
    );
    addTearDown(f.close);
    await expectLater(f.render(), throwsA(_failure('center_recipe_content')));
    fail = false;
    await f.render();
    expect(f.renders, 2);
  });

  test('real renderer preview/Add preserve the full 1920x1080 PNG', () async {
    final f = _Fixture(renderer: renderCenterSlide);
    addTearDown(f.close);
    final plain = _draft.copyWith(lines: []);
    final first = await f.render(plain);
    final second = await f.render(plain);
    expect(first.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(ByteData.sublistView(second).getUint32(16), 1920);
    expect(ByteData.sublistView(second).getUint32(20), 1080);
    expect(second, first);
    expect(f.renders, 1);
  });
}
