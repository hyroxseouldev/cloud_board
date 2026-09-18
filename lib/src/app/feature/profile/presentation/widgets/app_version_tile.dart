import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the installed build metadata, including CI's platform build number.
class AppVersionTile extends HookWidget {
  const AppVersionTile({super.key});

  @override
  Widget build(BuildContext context) {
    final attempt = useState(0);
    final request = useMemoized(PackageInfo.fromPlatform, [attempt.value]);
    final info = useFuture(request);
    final value = info.data;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('앱 버전'),
      subtitle: Text(
        value != null
            ? '버전 ${value.version} · 빌드 ${value.buildNumber.isEmpty ? '확인 불가' : value.buildNumber}'
            : info.hasError
            ? '버전 정보를 불러오지 못했습니다.'
            : '확인 중…',
      ),
      trailing: info.hasError
          ? IconButton(
              tooltip: '버전 정보 다시 확인',
              onPressed: () => attempt.value++,
              icon: const Icon(Icons.refresh_rounded),
            )
          : null,
    );
  }
}
