import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReleaseDataSource {
  Future<Map<String, dynamic>?> load(String platform) async =>
      (await FirebaseFirestore.instance
              .doc('appReleases/$platform')
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 6)))
          .data();
  Future<int> installedBuild() async =>
      int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  Future<int> dismissedUntil(int build) async =>
      (await SharedPreferences.getInstance()).getInt('release_snooze_$build') ??
      0;
  Future<void> dismiss(int build, int until) async {
    await (await SharedPreferences.getInstance()).setInt(
      'release_snooze_$build',
      until,
    );
  }
}
