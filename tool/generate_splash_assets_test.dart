// Run: fvm flutter test tool/generate_splash_assets_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'brand_asset_exporter.dart';

void main() {
  test('export v5 native splash sources', () async {
    final exporter = await BrandAssetExporter.load();
    try {
      await exporter.exportSplashSources();
    } finally {
      exporter.dispose();
    }
  });
}
