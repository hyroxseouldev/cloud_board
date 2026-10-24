// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'existing_member_access_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(existingMemberAccessRepository)
final existingMemberAccessRepositoryProvider =
    ExistingMemberAccessRepositoryProvider._();

final class ExistingMemberAccessRepositoryProvider
    extends
        $FunctionalProvider<
          ExistingMemberAccessRepository,
          ExistingMemberAccessRepository,
          ExistingMemberAccessRepository
        >
    with $Provider<ExistingMemberAccessRepository> {
  ExistingMemberAccessRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'existingMemberAccessRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$existingMemberAccessRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExistingMemberAccessRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExistingMemberAccessRepository create(Ref ref) {
    return existingMemberAccessRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExistingMemberAccessRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExistingMemberAccessRepository>(
        value,
      ),
    );
  }
}

String _$existingMemberAccessRepositoryHash() =>
    r'039bc2267b70b4dae5d9e79b0cb48aa69b14c24c';
