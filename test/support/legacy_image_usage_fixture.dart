import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';

/// Explicit legacy mode for controller/UI fixtures without a Firebase app.
/// Reading the gate is allowed; new callables, persistence and HTTP bodies are
/// forbidden so these regressions cannot silently exercise the enrolled path.
final legacyImageUsageFixture = imageUsageSourceProvider.overrideWith((ref) {
  var enrolledOperations = 0;
  Never unexpected() {
    enrolledOperations++;
    throw StateError('Legacy regression must not invoke enrolled image APIs');
  }

  final source = ImageUsageDataSource(
    projectId: 'demo-legacy-regression',
    actorId: 'fixture-owner',
    currentActorId: () => 'fixture-owner',
    token: () async => unexpected(),
    readGate: () async => {'mode': 'legacy'},
    call: (_, _) async => unexpected(),
    send: (_) async => unexpected(),
    preferences: () async => unexpected(),
  );
  ref.onDispose(() {
    source.dispose();
    expect(
      enrolledOperations,
      0,
      reason: 'Legacy fixtures must not call admission, media or upload APIs',
    );
  });
  return source;
});
