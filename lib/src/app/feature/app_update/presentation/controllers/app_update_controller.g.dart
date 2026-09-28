// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppUpdateController)
final appUpdateControllerProvider = AppUpdateControllerProvider._();

final class AppUpdateControllerProvider
    extends
        $AsyncNotifierProvider<
          AppUpdateController,
          ({UpdateKind kind, AppRelease release})?
        > {
  AppUpdateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateControllerHash();

  @$internal
  @override
  AppUpdateController create() => AppUpdateController();
}

String _$appUpdateControllerHash() =>
    r'5cb1f948a6d9a6f5ceeddd8ee464847029315a37';

abstract class _$AppUpdateController
    extends $AsyncNotifier<({UpdateKind kind, AppRelease release})?> {
  FutureOr<({UpdateKind kind, AppRelease release})?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<({UpdateKind kind, AppRelease release})?>,
              ({UpdateKind kind, AppRelease release})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<({UpdateKind kind, AppRelease release})?>,
                ({UpdateKind kind, AppRelease release})?
              >,
              AsyncValue<({UpdateKind kind, AppRelease release})?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
