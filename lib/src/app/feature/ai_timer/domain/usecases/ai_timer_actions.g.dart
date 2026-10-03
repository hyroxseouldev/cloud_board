// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_timer_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiTimerActions)
final aiTimerActionsProvider = AiTimerActionsProvider._();

final class AiTimerActionsProvider
    extends $FunctionalProvider<AiTimerActions, AiTimerActions, AiTimerActions>
    with $Provider<AiTimerActions> {
  AiTimerActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiTimerActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiTimerActionsHash();

  @$internal
  @override
  $ProviderElement<AiTimerActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiTimerActions create(Ref ref) {
    return aiTimerActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiTimerActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiTimerActions>(value),
    );
  }
}

String _$aiTimerActionsHash() => r'43638d46cbef883815421ea384321b55f7517c9d';
