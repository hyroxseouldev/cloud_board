// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_heartbeat_policy_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(displayHeartbeatPolicyService)
final displayHeartbeatPolicyServiceProvider =
    DisplayHeartbeatPolicyServiceProvider._();

final class DisplayHeartbeatPolicyServiceProvider
    extends
        $FunctionalProvider<
          DisplayHeartbeatPolicyService,
          DisplayHeartbeatPolicyService,
          DisplayHeartbeatPolicyService
        >
    with $Provider<DisplayHeartbeatPolicyService> {
  DisplayHeartbeatPolicyServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayHeartbeatPolicyServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayHeartbeatPolicyServiceHash();

  @$internal
  @override
  $ProviderElement<DisplayHeartbeatPolicyService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DisplayHeartbeatPolicyService create(Ref ref) {
    return displayHeartbeatPolicyService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DisplayHeartbeatPolicyService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DisplayHeartbeatPolicyService>(
        value,
      ),
    );
  }
}

String _$displayHeartbeatPolicyServiceHash() =>
    r'810c2728739a10cecd0a5033b33570cd49c08bec';
