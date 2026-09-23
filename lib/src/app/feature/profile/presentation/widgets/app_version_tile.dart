import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed build metadata, including CI's platform build number.
class AppVersionTile extends HookWidget {
  const AppVersionTile({super.key});

  static Future<PackageInfo> _readBuildInfo() {
    const name = String.fromEnvironment('APP_BUILD_NAME');
    const number = String.fromEnvironment('APP_BUILD_NUMBER');
    // Pin web metadata to the code running in this tab. Fetching version.json
    // after a deployment could otherwise label an old tab as the new build.
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

  @override
  Widget build(BuildContext context) {
    final attempt = useState(0);
    final request = useMemoized(_readBuildInfo, [attempt.value]);
    final info = useFuture(request);
    final value = info.data;
    final version = value == null
        ? null
        : '버전 ${value.version} · 빌드 ${value.buildNumber.isEmpty ? '확인 불가' : value.buildNumber}';
    Future<void> copyVersion() async {
      try {
        await Clipboard.setData(
          ClipboardData(
            text:
                'CloudBoard · ${kIsWeb ? 'Web' : defaultTargetPlatform.name} · $version',
          ),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('버전 정보를 복사했습니다.')));
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('버전 정보를 복사하지 못했습니다.')));
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('앱 버전'),
      subtitle: Text(
        version ?? (info.hasError ? '버전 정보를 불러오지 못했습니다.' : '확인 중…'),
      ),
      onTap: value == null ? null : copyVersion,
      trailing: info.hasError
          ? IconButton(
              tooltip: '버전 정보 다시 확인',
              onPressed: () => attempt.value++,
              icon: const Icon(Icons.refresh_rounded),
            )
          : value == null
          ? null
          : IconButton(
              tooltip: '버전 정보 복사',
              onPressed: copyVersion,
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
    );
  }
}
