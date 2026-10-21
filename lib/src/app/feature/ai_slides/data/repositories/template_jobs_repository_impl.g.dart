// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_jobs_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(templateJobsRepository)
final templateJobsRepositoryProvider = TemplateJobsRepositoryProvider._();

final class TemplateJobsRepositoryProvider
    extends
        $FunctionalProvider<
          TemplateJobsRepository?,
          TemplateJobsRepository?,
          TemplateJobsRepository?
        >
    with $Provider<TemplateJobsRepository?> {
  TemplateJobsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateJobsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateJobsRepositoryHash();

  @$internal
  @override
  $ProviderElement<TemplateJobsRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TemplateJobsRepository? create(Ref ref) {
    return templateJobsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateJobsRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateJobsRepository?>(value),
    );
  }
}

String _$templateJobsRepositoryHash() =>
    r'a41876c29bc257e8b11ee124365f0fd813bbb59b';
