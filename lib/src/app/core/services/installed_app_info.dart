import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<PackageInfo> readInstalledAppInfo() {
  const name = String.fromEnvironment('APP_BUILD_NAME');
  const number = String.fromEnvironment('APP_BUILD_NUMBER');
  // An old web tab must keep the identity of its loaded code after deployment.
  if (kIsWeb && name.isNotEmpty && number.isNotEmpty) {
    return Future.value(
      PackageInfo(
        appName: 'CloudBoard',
        packageName: 'cloud_board',
        version: name,
        buildNumber: number,
      ),
    );
  }
  return PackageInfo.fromPlatform();
}
