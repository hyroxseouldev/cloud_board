// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_app_update.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(checkAppUpdate)
final checkAppUpdateProvider = CheckAppUpdateProvider._();

final class CheckAppUpdateProvider
    extends $FunctionalProvider<CheckAppUpdate, CheckAppUpdate, CheckAppUpdate>
    with $Provider<CheckAppUpdate> {
  CheckAppUpdateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkAppUpdateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkAppUpdateHash();

  @$internal
  @override
  $ProviderElement<CheckAppUpdate> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CheckAppUpdate create(Ref ref) {
    return checkAppUpdate(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckAppUpdate value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckAppUpdate>(value),
    );
  }
}

String _$checkAppUpdateHash() => r'd9e6f85c43195265d797a049539344f6e8fd6ced';
