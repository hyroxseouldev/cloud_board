import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_form_factor.g.dart';

class DeviceFormFactorDataSource {
  const DeviceFormFactorDataSource();

  static const _channel = MethodChannel('com.sunmkim.cloudboard/device');

  Future<bool> isAndroidTv() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isAndroidTv') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
Future<bool> androidTv(Ref ref) =>
    const DeviceFormFactorDataSource().isAndroidTv();
