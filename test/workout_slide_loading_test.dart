import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_image_usage_provider.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_image_budget.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preview_frame.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
// Existing cached_network_image transitive interfaces for a local transport.
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/ui_layout_evidence.dart';
import 'support/workout_catalog_fixture.dart';

const _evidence = String.fromEnvironment('SLIDE_LOADING_EVIDENCE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ArtworkTransport transport;
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    transport = _ArtworkTransport();
    CachedNetworkImageProvider.defaultCacheManager = transport;
  });

  testWidgets('preview presents artwork and timer together', (tester) async {
    await loadLayoutFonts(tester);
    final key = GlobalKey();
    final module = WorkoutModule.empty('loading-fixture').copyWith(
      imageSource: 'https://fixture.invalid/slide.png?revision=1',
      name: '웜업',
      workSeconds: 600,
      workGaugeColor: '#FF0000',
      showSets: false,
    );
    await _mount(tester, key, module);
    await _until(tester, () => transport.pending.isNotEmpty);
    final bounds = tester.getRect(find.byType(WorkoutSlidePreview));
    final state = tester.state(find.byType(Image));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
    await _capture(tester, key, 'loading');
    expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
    expect(find.text('웜업'), findsNothing);
    await _mount(tester, key, module.copyWith(workSeconds: 599));
    expect(tester.state(find.byType(Image)), same(state));
    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
    transport.pending.single.complete(transport.png);
    await _until(
      tester,
      () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
    );
    expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
    expect(tester.state(find.byType(Image)), same(state));
    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
    expect(tester.getRect(find.byType(WorkoutSlidePreview)), bounds);
    await _capture(tester, key, 'ready');
    await _mount(tester, key, module.copyWith(workSeconds: 598));
    expect(find.text('9:58'), findsOneWidget);
    expect(tester.state(find.byType(Image)), same(state));
    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
    expect(transport.requests, [module.imageSource]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor screen retains preview bounds during loading', (
    tester,
  ) async {
    await loadLayoutFonts(tester);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const WorkoutEditorScreen(workoutId: 'fixture'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          slideEditorRepositoryProvider.overrideWithValue(
            LocalSlideEditorRepository(SlideEditorLocalDataSource()),
          ),
          fixtureWorkoutDetails,
          fixtureSavedSlideOrder,
          workoutControllerProvider.overrideWith(_EditorWorkouts.new),
          workoutImageUsageLoaderProvider('fixture').overrideWith(
            (ref) =>
                () => _NoImageUsage(),
          ),
        ],
        child: MaterialApp.router(
          theme: XonTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(key: key, child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _until(tester, () => transport.pending.isNotEmpty);
    final bounds = tester.getRect(find.byType(WorkoutSlidePreview));
    final state = tester.state(find.byType(Image));
    await _capture(tester, key, 'editor-loading');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.state(find.byType(Image)), same(state));
    transport.pending.single.complete(transport.png);
    await _until(
      tester,
      () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
    );
    expect(tester.getRect(find.byType(WorkoutSlidePreview)), bounds);
    expect(tester.state(find.byType(Image)), same(state));
    expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
    await _capture(tester, key, 'editor-ready');
    expect(transport.requests.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revision replacement ignores the pending old response', (
    tester,
  ) async {
    final key = GlobalKey();
    final first = _remote('0');
    final next = first.copyWith(imageSource: '${first.imageSource}&revision=2');
    await _mount(tester, key, first);
    await _until(tester, () => transport.pending.length == 1);
    await _mount(tester, key, next);
    await _until(tester, () => transport.pending.length == 2);
    final nextState = tester.state(find.byType(Image));
    transport.pending.first.complete(transport.png);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
    expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
    transport.pending.last.complete(transport.png);
    await _until(
      tester,
      () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
    );
    expect(tester.state(find.byType(Image)), same(nextState));
    expect(transport.requests, [first.imageSource, next.imageSource]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('0 to 1 to 0 cached selection has no placeholder or extra read', (
    tester,
  ) async {
    final key = GlobalKey();
    final modules = [_remote('0'), _remote('1')];
    final providers = <ImageProvider>[];
    for (var i = 0; i < 2; i++) {
      await _mount(tester, key, modules[i]);
      await _until(tester, () => transport.pending.length == i + 1);
      transport.pending[i].complete(transport.png);
      await _until(
        tester,
        () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
      );
      providers.add(tester.widget<Image>(find.byType(Image)).image);
    }
    await _mount(tester, key, modules[0]);
    // Assert on the very first frame, not after a settle that could hide a flash.
    expect(find.byType(WorkoutImageSkeleton), findsNothing);
    expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, providers[0]);
    final state = tester.state(find.byType(Image));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    await _mount(tester, key, modules[0].copyWith(workSeconds: 59));
    expect(tester.state(find.byType(Image)), same(state));
    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
    expect(transport.requests.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure replaces the whole preview and one tap retries once', (
    tester,
  ) async {
    await loadLayoutFonts(tester);
    final key = GlobalKey();
    await _mount(tester, key, _remote('failure'));
    await _until(tester, () => transport.pending.length == 1);
    transport.pending.single.completeError(
      StateError('private fixture exception'),
    );
    await _until(
      tester,
      () => find.byType(WorkoutImageFailure).evaluate().isNotEmpty,
    );
    expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
    expect(find.textContaining('private fixture'), findsNothing);
    await _capture(tester, key, 'error');
    await tester.pump(const Duration(seconds: 5));
    expect(transport.requests.length, 1);
    await tester.tap(find.byKey(const ValueKey('workout-image-retry')));
    await _until(tester, () => transport.pending.length == 2);
    expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
    expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
    transport.pending.last.complete(transport.png);
    await _until(
      tester,
      () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
    );
    expect(find.byType(WorkoutImageFailure), findsNothing);
    expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
    expect(transport.requests.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live canvas keeps ticking while artwork is pending', (
    tester,
  ) async {
    final key = GlobalKey();
    final module = _remote('live');
    await _mount(tester, key, module, live: true);
    await _until(tester, () => transport.pending.isNotEmpty);
    final state = tester.state(find.byType(Image));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(find.text('1:00'), findsOneWidget);
    await _mount(tester, key, module.copyWith(workSeconds: 59), live: true);
    expect(find.text('0:59'), findsOneWidget);
    expect(tester.state(find.byType(Image)), same(state));
    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
    transport.pending.single.complete(transport.png);
    await _until(
      tester,
      () => tester.widget<RawImage>(find.byType(RawImage)).image != null,
    );
    expect(transport.requests.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty and vector slides render immediately without media reads',
    (tester) async {
      final key = GlobalKey();
      for (final template in [null, 'stationd-v2-list']) {
        await _mount(
          tester,
          key,
          WorkoutModule.empty('vector').copyWith(
            designTemplate: template,
            // Vector slides must not wait on their saved compatibility raster.
            imageSource: template == null
                ? ''
                : 'https://fixture.invalid/unused.png',
          ),
        );
        expect(find.byType(WorkoutImageSkeleton), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
      }
      expect(transport.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('original artwork loading and retry use preview bounds', (
    tester,
  ) async {
    originalSlidePreviewCache.clear();
    final assets = <Completer<ByteData?>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) {
      expect(
        utf8.decode(message!.buffer.asUint8List()),
        dolpaBrickOriginalAsset,
      );
      final response = Completer<ByteData?>();
      assets.add(response);
      return response.future;
    });
    addTearDown(() {
      messenger.setMockMessageHandler('flutter/assets', null);
      originalSlidePreviewCache.clear();
    });
    final key = GlobalKey();
    final module = WorkoutModule.empty('original').copyWith(
      designTemplate: 'studio-v1-list',
      designStyle: const SlideDesignStyle(
        originalTemplate: dolpaBrickOriginalTemplateId,
      ),
    );
    await _mount(tester, key, module);
    expect(find.byType(WorkoutImageSkeleton), findsOneWidget);
    expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
    assets.single.complete(null);
    await _until(
      tester,
      () => find.byType(WorkoutImageFailure).evaluate().isNotEmpty,
    );
    // Inline retry remains at actual preview size, not scaled from a 1920px artboard.
    expect(
      tester.getSize(find.byType(WorkoutImageFailure)),
      const Size(320, 180),
    );
    await tester.tap(find.byKey(const ValueKey('workout-image-retry')));
    await _until(tester, () => assets.length == 2);
    assets.last.complete(ByteData.sublistView(transport.png));
    await _until(
      tester,
      () => find.byType(WorkoutImageSkeleton).evaluate().isEmpty,
    );
    expect(find.byKey(const ValueKey('slide-timer')), findsOneWidget);
    expect(transport.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

WorkoutModule _remote(String id) =>
    WorkoutModule.empty(id)
        .copyWith(imageSource: 'https://fixture.invalid/$id.png');

Future<void> _mount(
  WidgetTester tester,
  GlobalKey key,
  WorkoutModule module, {
  bool live = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(fontFamily: 'Pretendard'),
    home: Scaffold(
      body: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xfffdfcf6),
          child: Center(
            child: SizedBox(
              width: 320,
              child: live
                  ? WorkoutPreviewFrame(
                      child: WorkoutSlideCanvas(
                        module: module,
                        isRest: false,
                        secondsLeft: module.workSeconds,
                        remainingMs: module.workSeconds * 1000,
                        durationMs: 60000,
                        set: 1,
                        totalSets: 1,
                        isPaused: false,
                        brandL: '',
                        brandR: '',
                        scale: .25,
                      ),
                    )
                  : WorkoutSlidePreview(module: module, isRest: false),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(ready(), isTrue);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (_evidence.isEmpty) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// Controlled local byte transport; exercises the real provider/decode/widgets.
/// Counts below are fixture reads, not HTTP requests or external E2E evidence.
class _ArtworkTransport implements BaseCacheManager {
  final requests = <String>[];
  final pending = <Completer<List<int>>>[];
  final files = MemoryFileSystem();
  final png = img.encodePng(
    img.fill(
      img.Image(width: 640, height: 360),
      color: img.ColorRgb8(235, 227, 203),
    ),
  );
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requests.add(url);
    final response = Completer<List<int>>();
    pending.add(response);
    final bytes = await response.future;
    final file = files.file('/${requests.length}.png')..writeAsBytesSync(bytes);
    yield FileInfo(file, FileSource.Online, DateTime(2100), url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EditorWorkouts extends FixtureWorkoutController {
  @override
  Stream<List<Workout>> fullBuild() => Stream.value([
    Workout.empty(
      'fixture',
      const WorkoutAuthor(id: 'fixture', displayName: '로컬 코치', photoUrl: null),
    ).copyWith(
      name: '슬라이드 로딩 확인',
      modules: [
        _remote('editor').copyWith(
          name: '웜업',
          workSeconds: 600,
          workGaugeColor: '#FF0000',
          showSets: false,
        ),
      ],
    ),
  ]);
}

class _NoImageUsage extends Fake implements WorkoutImageUsageDataSource {
  @override
  Future<WorkoutImageUsage> measure(Workout workout) async => WorkoutImageUsage(
    moduleBytes: {for (final module in workout.modules) module.id: 0},
    countdownBytes: 0,
    knownBytes: 0,
    unknownCount: 0,
  );
}
