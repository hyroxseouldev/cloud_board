// Local-only preview using production screens and isolated fixture providers.
// fvm flutter run -d web-server -t tool/main_navigation_preview.dart --web-port 4188
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test/support/main_navigation_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = NavigationPreviewData(
    imageSource: await navigationPreviewImage(),
  );
  runApp(
    UncontrolledProviderScope(
      container: data.container,
      child: const MainNavigationPreview(),
    ),
  );
}
