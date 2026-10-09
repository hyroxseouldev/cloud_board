// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'first_class_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(firstClassRepository)
final firstClassRepositoryProvider = FirstClassRepositoryProvider._();

final class FirstClassRepositoryProvider
    extends
        $FunctionalProvider<
          FirstClassRepository,
          FirstClassRepository,
          FirstClassRepository
        >
    with $Provider<FirstClassRepository> {
  FirstClassRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firstClassRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firstClassRepositoryHash();

  @$internal
  @override
  $ProviderElement<FirstClassRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirstClassRepository create(Ref ref) {
    return firstClassRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirstClassRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirstClassRepository>(value),
    );
  }
}

String _$firstClassRepositoryHash() =>
    r'f1701ac6cb247d23a5547aadddcd95a5408059b1';
