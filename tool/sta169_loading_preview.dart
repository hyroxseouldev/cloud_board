// Local browser review harness: renders real production startup/bootstrap widgets
// without initializing Firebase or contacting operational services.
import 'dart:async';

import 'package:cloud_board/src/app/bootstrap.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  final scenario = Uri.base.queryParameters['scenario'] ?? 'pending';
  var attempts = 0;
  runApp(
    AppBootstrap(
      initialize: () async {
        attempts++;
        if (scenario == 'error' && attempts == 1) {
          throw StateError('Preview offline');
        }
        if (scenario == 'ready' || scenario == 'error') {
          return false;
        }
        return Completer<bool>().future;
      },
      builder: (_) => MaterialApp(
        theme: XonTheme.light,
        home: const Scaffold(body: Center(child: Text('초기화 완료'))),
      ),
    ),
  );
}
