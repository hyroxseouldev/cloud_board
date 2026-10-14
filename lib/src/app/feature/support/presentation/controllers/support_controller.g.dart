// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supportScreenshotPicker)
final supportScreenshotPickerProvider = SupportScreenshotPickerProvider._();

final class SupportScreenshotPickerProvider
    extends
        $FunctionalProvider<
          SupportScreenshotPicker,
          SupportScreenshotPicker,
          SupportScreenshotPicker
        >
    with $Provider<SupportScreenshotPicker> {
  SupportScreenshotPickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportScreenshotPickerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportScreenshotPickerHash();

  @$internal
  @override
  $ProviderElement<SupportScreenshotPicker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupportScreenshotPicker create(Ref ref) {
    return supportScreenshotPicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupportScreenshotPicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupportScreenshotPicker>(value),
    );
  }
}

String _$supportScreenshotPickerHash() =>
    r'91e6a76e8f36ad6692666162e6b94825bb675dfb';

@ProviderFor(supportAppDiagnostics)
final supportAppDiagnosticsProvider = SupportAppDiagnosticsProvider._();

final class SupportAppDiagnosticsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Object?>>,
          Map<String, Object?>,
          FutureOr<Map<String, Object?>>
        >
    with
        $FutureModifier<Map<String, Object?>>,
        $FutureProvider<Map<String, Object?>> {
  SupportAppDiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportAppDiagnosticsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportAppDiagnosticsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Object?>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Object?>> create(Ref ref) {
    return supportAppDiagnostics(ref);
  }
}

String _$supportAppDiagnosticsHash() =>
    r'171b1cc63272fafa31c3f761a9c23f78835f743b';

@ProviderFor(supportPreparationReceipts)
final supportPreparationReceiptsProvider =
    SupportPreparationReceiptsProvider._();

final class SupportPreparationReceiptsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, DisplayPreparationReceipt>>,
          Map<String, DisplayPreparationReceipt>,
          Stream<Map<String, DisplayPreparationReceipt>>
        >
    with
        $FutureModifier<Map<String, DisplayPreparationReceipt>>,
        $StreamProvider<Map<String, DisplayPreparationReceipt>> {
  SupportPreparationReceiptsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportPreparationReceiptsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportPreparationReceiptsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, DisplayPreparationReceipt>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, DisplayPreparationReceipt>> create(Ref ref) {
    return supportPreparationReceipts(ref);
  }
}

String _$supportPreparationReceiptsHash() =>
    r'49c91984965e78c820c0dd2b3b312c8d647beb89';

@ProviderFor(supportAvailableDiagnostics)
final supportAvailableDiagnosticsProvider =
    SupportAvailableDiagnosticsProvider._();

final class SupportAvailableDiagnosticsProvider
    extends
        $FunctionalProvider<
          Map<String, Object?>,
          Map<String, Object?>,
          Map<String, Object?>
        >
    with $Provider<Map<String, Object?>> {
  SupportAvailableDiagnosticsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportAvailableDiagnosticsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportAvailableDiagnosticsHash();

  @$internal
  @override
  $ProviderElement<Map<String, Object?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Object?> create(Ref ref) {
    return supportAvailableDiagnostics(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Object?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Object?>>(value),
    );
  }
}

String _$supportAvailableDiagnosticsHash() =>
    r'fbd750071f947246c5b42a3bf3f6959effbe9c44';

@ProviderFor(SupportController)
final supportControllerProvider = SupportControllerProvider._();

final class SupportControllerProvider
    extends $NotifierProvider<SupportController, SupportDraft> {
  SupportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportControllerHash();

  @$internal
  @override
  SupportController create() => SupportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupportDraft value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupportDraft>(value),
    );
  }
}

String _$supportControllerHash() => r'a1b5910dda606d2b4faad0d967d15dd1e0093025';

abstract class _$SupportController extends $Notifier<SupportDraft> {
  SupportDraft build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SupportDraft, SupportDraft>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SupportDraft, SupportDraft>,
              SupportDraft,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
