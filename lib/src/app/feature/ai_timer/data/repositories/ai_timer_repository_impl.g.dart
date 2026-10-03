// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_timer_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiTimerRepository)
final aiTimerRepositoryProvider = AiTimerRepositoryProvider._();

final class AiTimerRepositoryProvider
    extends
        $FunctionalProvider<
          AiTimerRepository,
          AiTimerRepository,
          AiTimerRepository
        >
    with $Provider<AiTimerRepository> {
  AiTimerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiTimerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiTimerRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiTimerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiTimerRepository create(Ref ref) {
    return aiTimerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiTimerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiTimerRepository>(value),
    );
  }
}

String _$aiTimerRepositoryHash() => r'1918276596cee7d570078c2ce51cf34a42c5ff15';
