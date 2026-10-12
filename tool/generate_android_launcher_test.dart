// Run: fvm flutter test tool/generate_android_launcher_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'brand_asset_exporter.dart';

void main() {
  test('export v5 platform launcher resources', () async {
    final exporter = await BrandAssetExporter.load();
    try {
      await exporter.exportLaunchers();
    } finally {
      exporter.dispose();
    }
  });
}
