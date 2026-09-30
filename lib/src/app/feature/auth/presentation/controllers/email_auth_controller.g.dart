// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EmailAuthController)
final emailAuthControllerProvider = EmailAuthControllerProvider._();

final class EmailAuthControllerProvider
    extends $NotifierProvider<EmailAuthController, AsyncValue<String?>> {
  EmailAuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'emailAuthControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$emailAuthControllerHash();

  @$internal
  @override
  EmailAuthController create() => EmailAuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<String?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<String?>>(value),
    );
  }
}

String _$emailAuthControllerHash() =>
    r'f7ee9928eba9699fe77ce3ba3c08dcefc8a7d374';

abstract class _$EmailAuthController extends $Notifier<AsyncValue<String?>> {
  AsyncValue<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, AsyncValue<String?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, AsyncValue<String?>>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
