// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_operations_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(audienceBrandingMemory)
final audienceBrandingMemoryProvider = AudienceBrandingMemoryFamily._();

final class AudienceBrandingMemoryProvider
    extends
        $FunctionalProvider<
          AudienceBrandingMemory,
          AudienceBrandingMemory,
          AudienceBrandingMemory
        >
    with $Provider<AudienceBrandingMemory> {
  AudienceBrandingMemoryProvider._({
    required AudienceBrandingMemoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'audienceBrandingMemoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audienceBrandingMemoryHash();

  @override
  String toString() {
    return r'audienceBrandingMemoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AudienceBrandingMemory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudienceBrandingMemory create(Ref ref) {
    final argument = this.argument as String;
    return audienceBrandingMemory(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudienceBrandingMemory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudienceBrandingMemory>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudienceBrandingMemoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audienceBrandingMemoryHash() =>
    r'307656737973a276b2c75e1275f09f12a9f910bb';

final class AudienceBrandingMemoryFamily extends $Family
    with $FunctionalFamilyOverride<AudienceBrandingMemory, String> {
  AudienceBrandingMemoryFamily._()
    : super(
        retry: null,
        name: r'audienceBrandingMemoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  AudienceBrandingMemoryProvider call(String ownerId) =>
      AudienceBrandingMemoryProvider._(argument: ownerId, from: this);

  @override
  String toString() => r'audienceBrandingMemoryProvider';
}

@ProviderFor(storeOperationsRepository)
final storeOperationsRepositoryProvider = StoreOperationsRepositoryProvider._();

final class StoreOperationsRepositoryProvider
    extends
        $FunctionalProvider<
          StoreOperationsRepository,
          StoreOperationsRepository,
          StoreOperationsRepository
        >
    with $Provider<StoreOperationsRepository> {
  StoreOperationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storeOperationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storeOperationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<StoreOperationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StoreOperationsRepository create(Ref ref) {
    return storeOperationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StoreOperationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StoreOperationsRepository>(value),
    );
  }
}

String _$storeOperationsRepositoryHash() =>
    r'cbd8c78d82cb1841fcb9e58961962b0558e0b813';
