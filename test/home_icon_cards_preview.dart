// Local-only production home screen; no Firebase initialization or user data.
// flutter run -d web-server -t test/home_icon_cards_preview.dart --web-port 8808
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/main_navigation_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = NavigationPreviewData(
    active: false,
    count: 6,
    imageSource: await navigationPreviewImage(),
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
