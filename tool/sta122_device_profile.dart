// Isolated profile harness. Use a separate application ID and example data;
// no Firebase account, network service, or production preferences are accessed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slide_design_studio.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'sta122_catalog_profile.dart';
import 'sta122_storage_profile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        aiSlideDesignOwnerIdProvider.overrideWith((ref) => null),
        aiSlideDesignStoreIdProvider.overrideWith((ref) => null),
        aiSlidesOwnerIdProvider.overrideWith((ref) => null),
      ],
      child: const _ProfileApp(),
    ),
  );
}

class _ProfileApp extends StatefulWidget {
  const _ProfileApp();
  @override
  State<_ProfileApp> createState() => _ProfileAppState();
}

class _ProfileAppState extends State<_ProfileApp> {
  final scroll = ScrollController();
  final frames = <String, List<int>>{};
  bool gallery = false;
  String stage = 'idle';
  String message = 'Preparing controlled profile run';
  int peakRss = 0;
  Timer? sample;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(recordFrames);
    sample = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final value = ProcessInfo.currentRss;
      if (value > peakRss) peakRss = value;
    });
    unawaited(run());
  }

  void recordFrames(List<FrameTiming> timings) {
    (frames[stage] ??= []).addAll(
      timings.map((t) => t.totalSpan.inMicroseconds),
    );
  }

  Map<String, Object> frameSummary(String name) {
    final values = [...?frames[name]]..sort();
    return {
      'count': values.length,
      'over16ms': values.where((v) => v > 16667).length,
      'over33ms': values.where((v) => v > 33333).length,
      'p95Micros': values.isEmpty
          ? 0
          : values[((values.length - 1) * .95).round()],
      'maxMicros': values.isEmpty ? 0 : values.last,
    };
  }

  void report(Map<String, Object?> data) {
    // Kept as stdout JSON for flutter run --profile logs, including profile mode.
    // ignore: avoid_print
    print('STA122_PROFILE ${jsonEncode(data)}');
  }

  Future<void> run() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      report({
        'label': const String.fromEnvironment('BENCH_LABEL'),
        'profile': kProfileMode,
        'os': Platform.operatingSystemVersion,
        'physicalSize': View.of(context).physicalSize.toString(),
        'devicePixelRatio': View.of(context).devicePixelRatio,
      });
      for (var round = 1; round <= 3; round++) {
        final before = ProcessInfo.currentRss;
        peakRss = before;
        stage = 'gallery-$round';
        setState(() {
          gallery = true;
          message = stage;
        });
        await Future<void>.delayed(const Duration(seconds: 5));
        final firstViewRss = ProcessInfo.currentRss;
        if (scroll.hasClients) {
          await scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(seconds: 2),
            curve: Curves.linear,
          );
        }
        await Future<void>.delayed(const Duration(seconds: 3));
        final galleryPeak = peakRss;
        final galleryFrames = frameSummary(stage);
        setState(() {
          gallery = false;
          message = 'closed-$round';
        });
        stage = 'closed-$round';
        await Future<void>.delayed(const Duration(seconds: 3));
        report({
          'stage': 'gallery',
          'round': round,
          'beforeRssBytes': before,
          'firstViewRssBytes': firstViewRss,
          'peakRssBytes': galleryPeak,
          'afterCloseRssBytes': ProcessInfo.currentRss,
          'frames': galleryFrames,
        });
      }
      stage = 'draft';
      setState(() {
        message = '20 draft edits, 5 MiB image';
      });
      final repository = LocalSlideEditorRepository(
        SlideEditorLocalDataSource(),
      );
      const key = 'sta122-benchmark.only.draft';
      await repository.clearDraft(key);
      final bytes = Uint8List.fromList(
        List.generate(5 * 1024 * 1024, (i) => i % 251),
      );
      final image = 'data:image/png;base64,${base64Encode(bytes)}';
      final module = WorkoutModule.empty('draft').copyWith(imageSource: image);
      final writes = <int>[];
      for (var i = 0; i <= 20; i++) {
        final watch = Stopwatch()..start();
        await repository.saveDraft(
          key,
          module.copyWith(text: 'Edit $i', workSeconds: 30 + i),
        );
        writes.add(watch.elapsedMicroseconds);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      report({
        'stage': 'draft',
        'imageBytes': bytes.length,
        'writes': writes.length,
        'firstWriteMicros': writes.first,
        'editWritesMicros': writes.skip(1).toList(),
        'totalWriteMicros': writes.reduce((a, b) => a + b),
        'frames': frameSummary(stage),
      });
      await repository.clearDraft(key);
      stage = 'png';
      setState(() {
        message = '30-slide save and unchanged save';
      });
      report({
        'stage': 'png',
        ...await profileDesignSaves(),
        'frames': frameSummary(stage),
      });
      stage = 'catalog';
      setState(() {
        message = '24 / 100 / 500 workout catalog';
      });
      report({'stage': 'catalog', ...await profileCatalog()});
      stage = 'done';
      setState(() {
        message = 'Profile run complete';
      });
      report({'stage': 'complete'});
    } catch (error, stack) {
      report({'stage': 'failed', 'error': '$error', 'stack': '$stack'});
      if (mounted) {
        setState(() {
          message = 'Profile failed: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    home: Scaffold(
      appBar: AppBar(title: Text(message)),
      body: gallery
          ? SingleChildScrollView(
              controller: scroll,
              child: AiSlideDesignStudio(
                section: AiSlideDesignStudioSection.templates,
                onSelected: (_) {},
              ),
            )
          : Center(
              child: stage == 'done'
                  ? const Text('Complete')
                  : const CircularProgressIndicator(),
            ),
    ),
  );

  @override
  void dispose() {
    sample?.cancel();
    WidgetsBinding.instance.removeTimingsCallback(recordFrames);
    scroll.dispose();
    super.dispose();
  }
}
