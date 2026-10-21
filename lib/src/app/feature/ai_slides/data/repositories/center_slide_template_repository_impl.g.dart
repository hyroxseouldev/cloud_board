// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'center_slide_template_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(centerSlideTemplateRepository)
final centerSlideTemplateRepositoryProvider =
    CenterSlideTemplateRepositoryFamily._();

final class CenterSlideTemplateRepositoryProvider
    extends
        $FunctionalProvider<
          CenterSlideTemplateRepository,
          CenterSlideTemplateRepository,
          CenterSlideTemplateRepository
        >
    with $Provider<CenterSlideTemplateRepository> {
  CenterSlideTemplateRepositoryProvider._({
    required CenterSlideTemplateRepositoryFamily super.from,
    required (String, String, Object) super.argument,
  }) : super(
         retry: null,
         name: r'centerSlideTemplateRepositoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$centerSlideTemplateRepositoryHash();

  @override
  String toString() {
    return r'centerSlideTemplateRepositoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<CenterSlideTemplateRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CenterSlideTemplateRepository create(Ref ref) {
    final argument = this.argument as (String, String, Object);
    return centerSlideTemplateRepository(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CenterSlideTemplateRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CenterSlideTemplateRepository>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CenterSlideTemplateRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$centerSlideTemplateRepositoryHash() =>
    r'b23608d5e03227568f435f7c42629a9489f7b5fe';

final class CenterSlideTemplateRepositoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          CenterSlideTemplateRepository,
          (String, String, Object)
        > {
  CenterSlideTemplateRepositoryFamily._()
    : super(
        retry: null,
        name: r'centerSlideTemplateRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CenterSlideTemplateRepositoryProvider call(
    String ownerId,
    String centerId,
    Object lifetime,
  ) => CenterSlideTemplateRepositoryProvider._(
    argument: (ownerId, centerId, lifetime),
    from: this,
  );

  @override
  String toString() => r'centerSlideTemplateRepositoryProvider';
}
