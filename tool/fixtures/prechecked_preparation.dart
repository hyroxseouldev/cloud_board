// Local-only production router + list caller + preparation screen.
// flutter build web --target tool/fixtures/prechecked_preparation.dart --no-web-resources-cdn
// ?scene=ready|mixed|offline|empty|error|request-error&scale=2
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../test/support/main_navigation_fixture.dart';
import '../../test/support/preparation_fixture.dart';

void main() {
  final params = Uri.base.queryParameters;
  final scene = params['scene'] ?? 'ready';
  final fixture = PreparationFixture(
    scene: scene,
    count: scene == 'empty' ? 0 : 3,
  );
  fixture.repository.failRequest = scene == 'request-error';
  final data = NavigationPreviewData(
    active: false,
    count: 12,
    preparationOverrides: fixture.overrides,
  );
  // Counters report only fake local work, never real account or media data.
  var previous = '';
  Timer.periodic(const Duration(seconds: 1), (_) {
    final counts =
        'local fixture: prepare=${fixture.repository.requests}, admissionChecks=${fixture.source.checks}, deviceSubscriptions=${fixture.deviceSubscriptions}';
    if (counts != previous) {
      debugPrint(counts);
      previous = counts;
    }
  });
  runApp(
    UncontrolledProviderScope(
      container: data.container,
      child: MainNavigationPreview(
        textScale: double.tryParse(params['scale'] ?? '') ?? 1,
      ),
    ),
  );
}
