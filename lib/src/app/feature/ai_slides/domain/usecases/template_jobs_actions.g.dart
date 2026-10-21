// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_jobs_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(templateJobsActions)
final templateJobsActionsProvider = TemplateJobsActionsProvider._();

final class TemplateJobsActionsProvider
    extends
        $FunctionalProvider<
          TemplateJobsActions,
          TemplateJobsActions,
          TemplateJobsActions
        >
    with $Provider<TemplateJobsActions> {
  TemplateJobsActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateJobsActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateJobsActionsHash();

  @$internal
  @override
  $ProviderElement<TemplateJobsActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TemplateJobsActions create(Ref ref) {
    return templateJobsActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateJobsActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateJobsActions>(value),
    );
  }
}

String _$templateJobsActionsHash() =>
    r'6f56166e8cb540ea86aa19be44723b6d85072569';
