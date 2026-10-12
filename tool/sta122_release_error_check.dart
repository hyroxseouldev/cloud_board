// Release-only UI evidence harness. No Firebase initialization or server writes.
// flutter build web --release --target tool/sta122_release_error_check.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_load_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:web/web.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final failures = <(String, Object)>[
    (
      'network',
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'TECHNICAL_PRIVATE',
      ),
    ),
    (
      'permission',
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'TECHNICAL_PRIVATE',
      ),
    ),
    (
      'deleted',
      FirebaseException(
        plugin: 'firebase_storage',
        code: 'object-not-found',
        message: 'TECHNICAL_PRIVATE',
      ),
    ),
    ('active class', StateError(workoutPlayingEditMessage)),
    ('unknown', StateError('TECHNICAL_PRIVATE')),
    ('library', const LibraryFailure('TECHNICAL_PRIVATE')),
  ];
  runApp(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: XonTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('STA-129 Release UI verification')),
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final (label, error) in failures) ...[
                  Text(label),
                  SizedBox(
                    height: 180,
                    child: WorkoutLoadFailure(error: error, onRetry: () {}),
                  ),
                ],
                Text(
                  playbackErrorMessage(
                    const PlaybackFailure('unknown', 'TECHNICAL_PRIVATE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Timer(const Duration(milliseconds: 300), () {
      final texts = <String>[];
      void collect(Element element) {
        final widget = element.widget;
        if (widget is Text && widget.data != null) texts.add(widget.data!);
        if (widget is SelectableText && widget.data != null) {
          texts.add(widget.data!);
        }
        element.visitChildElements(collect);
      }

      WidgetsBinding.instance.rootElement!.visitChildElements(collect);
      final evidence = {
        'issue': 'STA-129',
        'buildMode': kReleaseMode
            ? 'release'
            : (kProfileMode ? 'profile' : 'debug'),
        'texts': texts,
        'technicalTextVisible': texts.any(
          (text) =>
              text.contains('TECHNICAL_PRIVATE') ||
              text.contains('cloud_firestore') ||
              text.contains('firebase_storage'),
        ),
        'debugDetailsVisible': texts.any((text) => text == '오류 상세'),
        'retryButtons': texts.where((text) => text == '다시 시도').length,
      };
      web.document.body!.append(
        web.document.createElement('pre')
          ..id = 'release-error-evidence'
          ..textContent = jsonEncode(evidence),
      );
    });
  });
}
