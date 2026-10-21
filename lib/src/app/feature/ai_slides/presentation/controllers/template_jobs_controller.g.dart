// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'template_jobs_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TemplateJobsController)
final templateJobsControllerProvider = TemplateJobsControllerProvider._();

final class TemplateJobsControllerProvider
    extends $NotifierProvider<TemplateJobsController, TemplateJobsState> {
  TemplateJobsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templateJobsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templateJobsControllerHash();

  @$internal
  @override
  TemplateJobsController create() => TemplateJobsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TemplateJobsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TemplateJobsState>(value),
    );
  }
}

String _$templateJobsControllerHash() =>
    r'7e4d23437089d84f9bec2703abb3c5ca4bf76562';

abstract class _$TemplateJobsController extends $Notifier<TemplateJobsState> {
  TemplateJobsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TemplateJobsState, TemplateJobsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TemplateJobsState, TemplateJobsState>,
              TemplateJobsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
