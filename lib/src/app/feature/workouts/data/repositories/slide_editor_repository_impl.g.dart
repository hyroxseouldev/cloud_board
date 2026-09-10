// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'slide_editor_repository_impl.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(slideEditorRepository)
final slideEditorRepositoryProvider = SlideEditorRepositoryProvider._();

final class SlideEditorRepositoryProvider
    extends
        $FunctionalProvider<
          SlideEditorRepository,
          SlideEditorRepository,
          SlideEditorRepository
        >
    with $Provider<SlideEditorRepository> {
  SlideEditorRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'slideEditorRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$slideEditorRepositoryHash();

  @$internal
  @override
  $ProviderElement<SlideEditorRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SlideEditorRepository create(Ref ref) {
    return slideEditorRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SlideEditorRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SlideEditorRepository>(value),
    );
  }
}

String _$slideEditorRepositoryHash() =>
    r'd0746cc341e498a6ae8dfe3a7f8d6dc9374f5692';
