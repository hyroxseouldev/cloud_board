// Standalone local fixture for the production home and unchanged navigation.
// No Firebase initialization, login, remote media, or production repository.
// flutter build web --no-pub --target tool/fixtures/home_shadcn.dart --no-web-resources-cdn
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../test/support/main_navigation_fixture.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final data = NavigationPreviewData(
    active: false,
    count: Uri.base.queryParameters['scene'] == 'empty' ? 0 : 6,
  );
  runApp(
    UncontrolledProviderScope(
      container: data.container,
      child: MainNavigationPreview(
        textScale:
            double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1,
      ),
    ),
  );
}
