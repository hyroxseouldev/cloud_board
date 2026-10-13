import 'dart:convert';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Workout fixture(int count) =>
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: '', photoUrl: null),
    ).copyWith(
      modules: List.generate(
        count,
        (i) => WorkoutModule.empty('$i').copyWith(
          name: 'STATION $i',
          text: 'Run ${i + 1}00m',
          designTemplate: 'stationd-v2-list',
          showTimer: false,
          showSets: false,
        ),
      ),
    );

class _Reference extends Fake implements Reference {
  _Reference(this.storage, this.fullPath, {this.sourceBucket});
  final String? sourceBucket;
  @override
  final _Firebase storage;
  @override
  final String fullPath;
  @override
  String get bucket => sourceBucket ?? storage.bucket;
  @override
  String get name => fullPath.split('/').last;
  @override
  Future<String> getDownloadURL() async {
    storage.lookups++;
    if (storage.failure != null) {
      throw FirebaseException(plugin: 'storage', code: storage.failure!);
    }
    if (!storage.assets.contains(fullPath)) {
      throw FirebaseException(plugin: 'storage', code: 'object-not-found');
    }
    return 'https://firebasestorage.googleapis.com/v0/b/${storage.bucket}/o/${Uri.encodeComponent(fullPath)}?alt=media';
  }
}

class _Firebase extends Fake implements FirebaseStorage {
  @override
  String get bucket => 'test.appspot.com';
  final assets = <String>{};
  int lookups = 0;
  String? failure;
  @override
  Reference refFromURL(String url) {
    final uri = Uri.parse(url);
    if (uri.host != 'firebasestorage.googleapis.com') {
      throw ArgumentError('external URL');
    }
    return _Reference(
      this,
      Uri.decodeComponent(uri.path.split('/o/').last),
      sourceBucket: uri.pathSegments[2],
    );
  }
}

class _Storage extends WorkoutStorageDataSource {
  _Storage(this.firebase, this.prepared)
    : super(
        firebase,
        prepareDesign: (module) async {
          prepared.add(module.id);
          return module.copyWith(
            imageSource: 'data:image/png;base64,${module.id}',
            designFingerprint: slideDesignFingerprint(module),
          );
        },
      );
  final _Firebase firebase;
  final List<String> prepared;
  int uploads = 0;
  @override
  Future<String> uploadImage(
    String userId,
    String workoutId,
    String source,
  ) async {
    uploads++;
    final id = source.split(',').last.padLeft(64, '0');
    final path = 'users/$userId/workouts/$workoutId/images/$id';
    firebase.assets.add(path);
    return _Reference(firebase, path).getDownloadURL();
  }
}

/// Runs the production painter and sync path; only the remote upload is fake.
class _RenderedStorage extends WorkoutStorageDataSource {
  _RenderedStorage(this.firebase, List<String> prepared)
    : super(
        firebase,
        prepareDesign: (module) async {
          prepared.add(module.id);
          return prepareSlideDesign(module);
        },
      );

  final _Firebase firebase;
  final uploaded = <String, String>{};
  bool failUpload = false;

  @override
  Future<String> uploadImage(
    String userId,
    String workoutId,
    String source,
  ) async {
    if (failUpload) throw StateError('Upload unavailable');
    final digest = sha256.convert(base64Decode(source.split(',').last));
    final path = 'users/$userId/workouts/$workoutId/images/$digest';
    firebase.assets.add(path);
    final url = await _Reference(firebase, path).getDownloadURL();
    uploaded[url] = source;
    return url;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final operation in ['resave', 'duplicate', 'library insertion']) {
    test(
      '$operation refreshes v1 PNGs and preserves explicit user edits',
      () async {
        expect(slideDesignRendererVersion, greaterThan(1));
        final firebase = _Firebase();
        final oldPath = 'users/u/workouts/w/images/${'a' * 64}';
        firebase.assets.add(oldPath);
        final original = fixture(1).modules.single.copyWith(
          text: 'Run 200m\nRest 30s',
          designTemplate: operation == 'resave'
              ? 'stationd-v2-list'
              : 'studio-v1-numbered',
          designStyle: operation == 'resave'
              ? null
              : const SlideDesignStyle(fontFamily: 'serif', titleWeight: 900),
          designFontWeight: 800,
          designItalic: true,
          designSubtitle: 'My coaching cue',
          workSeconds: 40,
          restSeconds: 20,
          sets: 6,
          imageSource: await _Reference(firebase, oldPath).getDownloadURL(),
          designFingerprint: 'v1:${'b' * 64}:${'a' * 64}',
        );
        final input = switch (operation) {
          'duplicate' => original.copyWith(id: 'copied-slide'),
          'library insertion' => replaceSlideWithTemplate(
            WorkoutModule.empty('target-slide'),
            original,
          ),
          _ => original,
        };
        final workout = fixture(1).copyWith(
          id: operation == 'resave' ? 'w' : 'new-workout',
          modules: [input],
        );
        final prepared = <String>[];
        final storage = _RenderedStorage(firebase, prepared);
        final saved = await storage.syncImages('u', workout);
        final slide = saved.modules.single;
        expect(prepared, [input.id]);
        expect(slide.imageSource, isNot(original.imageSource));
        expect(
          slide.designFingerprint,
          startsWith('v$slideDesignRendererVersion:'),
        );
        expect(
          storage.uploaded[slide.imageSource],
          await renderSlideDesign(input),
          reason: 'stored PNG must match the current preview painter',
        );
        expect(
          slide.copyWith(
            imageSource: input.imageSource,
            designFingerprint: input.designFingerprint,
            appearance: slide.appearance.copyWith(
              showTitle: input.appearance.showTitle,
              showBody: input.appearance.showBody,
            ),
          ),
          input,
          reason: 'content, timing and explicit styles are unchanged',
        );
        expect(
          firebase.assets,
          contains(oldPath),
          reason: 'existing playback snapshots may still use the earlier PNG',
        );
        expect(workout.modules.single, input);

        final decoded = WorkoutModel.fromJson(
          WorkoutModel.fromEntity(saved).toJson(),
        ).toEntity();
        clearSlideDesignRenderCache();
        await storage.syncImages('u', decoded);
        expect(prepared, [input.id], reason: 'the upgraded PNG is reusable');
        expect(storage.uploaded.length, 1);
      },
    );
  }

  test(
    'failed v1 PNG refresh leaves the original workout available for retry',
    () async {
      final firebase = _Firebase();
      final original = fixture(1).copyWith(
        modules: [
          fixture(1).modules.single.copyWith(
            imageSource: 'https://example.com/saved-v1.png',
            designFingerprint: 'v1:earlier-render',
          ),
        ],
      );
      final before = WorkoutModel.fromEntity(original).toJson();
      final storage = _RenderedStorage(firebase, [])..failUpload = true;
      await expectLater(storage.syncImages('u', original), throwsStateError);
      expect(WorkoutModel.fromEntity(original).toJson(), before);
      expect(storage.uploaded, isEmpty);
      storage.failUpload = false;
      final retried = await storage.syncImages('u', original);
      expect(
        retried.modules.single.designFingerprint,
        startsWith('v$slideDesignRendererVersion:'),
      );
    },
  );

  for (final count in [1, 8, 9, 30]) {
    test(
      '$count persisted slides reuse scoped assets after renderer/service restart',
      () async {
        final firebase = _Firebase();
        final firstPrepared = <String>[];
        final first = _Storage(firebase, firstPrepared);
        final saved = await first.syncImages('u', fixture(count));
        expect(firstPrepared.length, count);
        final decoded = WorkoutModel.fromJson(
          WorkoutModel.fromEntity(saved).toJson(),
        ).toEntity();
        clearSlideDesignRenderCache();
        final prepared = <String>[];
        final restarted = _Storage(firebase, prepared);
        final unchanged = await restarted.syncImages(
          'u',
          decoded.copyWith(
            folder: 'Other',
            modules: decoded.modules
                .map((m) => m.copyWith(workSeconds: 120, sets: 4))
                .toList(),
          ),
        );
        expect(prepared, isEmpty);
        expect(restarted.uploads, 0);
        expect(
          unchanged.modules.map((m) => m.imageSource),
          saved.modules.map((m) => m.imageSource),
        );
        await restarted.syncImages(
          'u',
          unchanged.copyWith(
            modules: [
              unchanged.modules.first.copyWith(text: 'Changed exercise'),
              ...unchanged.modules.skip(1),
            ],
          ),
        );
        expect(prepared, ['0']);
        expect(restarted.uploads, 1);
      },
    );
  }
  test('legacy metadata, missing URL, missing object and mismatched scope regenerate', () async {
    final firebase = _Firebase();
    final prepared = <String>[];
    final storage = _Storage(firebase, prepared);
    final saved = await storage.syncImages('u', fixture(1));
    for (final module in [
      saved.modules.single.copyWith(designFingerprint: null),
      saved.modules.single.copyWith(designFingerprint: 'v0:old'),
      saved.modules.single.copyWith(imageSource: ''),
      saved.modules.single.copyWith(
        imageSource: 'https://example.com/foreign.png',
      ),
    ]) {
      prepared.clear();
      await storage.syncImages('u', saved.copyWith(modules: [module]));
      expect(prepared, ['0']);
    }
    prepared.clear();
    final foreignAsset = 'users/u/workouts/w/images/${'f' * 64}';
    firebase.assets.add(foreignAsset);
    await storage.syncImages(
      'u',
      saved.copyWith(
        modules: [
          saved.modules.single.copyWith(
            imageSource: await _Reference(
              firebase,
              foreignAsset,
            ).getDownloadURL(),
          ),
        ],
      ),
    );
    expect(prepared, [
      '0',
    ], reason: 'visual metadata must bind the exact object');
    prepared.clear();
    await storage.syncImages(
      'u',
      saved.copyWith(
        modules: [
          saved.modules.single.copyWith(
            imageSource: saved.modules.single.imageSource.replaceFirst(
              '/b/test.appspot.com/',
              '/b/foreign.appspot.com/',
            ),
          ),
        ],
      ),
    );
    expect(prepared, [
      '0',
    ], reason: 'the Firebase bucket is part of the asset scope');
    firebase.assets.clear();
    prepared.clear();
    await storage.syncImages('u', saved);
    expect(prepared, ['0']);
    prepared.clear();
    await storage.syncImages('another-user', saved);
    expect(prepared, ['0']);
    prepared.clear();
    await storage.syncImages('u', saved.copyWith(id: 'another-workout'));
    expect(prepared, ['0']);
  });
  test(
    'storage permission/network failure propagates without re-render or upload',
    () async {
      final firebase = _Firebase();
      final prepared = <String>[];
      final storage = _Storage(firebase, prepared);
      final saved = await storage.syncImages('u', fixture(1));
      prepared.clear();
      for (final code in ['unauthorized', 'retry-limit-exceeded']) {
        firebase.failure = code;
        await expectLater(
          storage.syncImages('u', saved),
          throwsA(isA<FirebaseException>()),
        );
        expect(prepared, isEmpty);
        expect(storage.uploads, 1);
      }
    },
  );
  test('visual fingerprint changes for all painted input families but ignores duration/identity', () {
    final module = fixture(1).modules.single;
    final original = slideDesignFingerprint(module);
    for (final changed in [
      module.copyWith(name: 'Other'),
      module.copyWith(text: 'Other'),
      module.copyWith(designBackgroundColor: 0xFFFFFFFF),
      module.copyWith(designTextColor: 0xFF000000),
      module.copyWith(designAccentColor: 0xFFFF0000),
      module.copyWith(designLayout: 'columns'),
      module.copyWith(designFontWeight: 500),
      module.copyWith(designItalic: !module.designItalic),
      module.copyWith(designSpacing: 1.2),
      module.copyWith(designHeaderLabel: 'DAY'),
      module.copyWith(designSubtitle: 'SUB'),
      module.copyWith(showTimer: true),
      module.copyWith(showSets: true),
      module.copyWith(appearance: module.appearance.copyWith(timerX: .3)),
      module.copyWith(appearance: module.appearance.copyWith(timerY: .3)),
      module.copyWith(appearance: module.appearance.copyWith(timerSize: .7)),
      module.copyWith(appearance: module.appearance.copyWith(setsSize: 1.3)),
      module.copyWith(appearance: module.appearance.copyWith(setsOffsetY: .2)),
    ]) {
      expect(slideDesignFingerprint(changed), isNot(original));
    }
    expect(
      slideDesignFingerprint(
        module.copyWith(
          id: 'new',
          workSeconds: 20,
          restSeconds: 10,
          sets: 9,
          beep: false,
          favorite: true,
        ),
      ),
      original,
    );
  });
}
