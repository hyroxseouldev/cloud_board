// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_news_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UpdateNewsController)
final updateNewsControllerProvider = UpdateNewsControllerProvider._();

final class UpdateNewsControllerProvider
    extends $AsyncNotifierProvider<UpdateNewsController, UpdateNewsState> {
  UpdateNewsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateNewsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateNewsControllerHash();

  @$internal
  @override
  UpdateNewsController create() => UpdateNewsController();
}

String _$updateNewsControllerHash() =>
    r'50f2dd1b4862b1197c37dafbf665a8a4a22fb4f7';

abstract class _$UpdateNewsController extends $AsyncNotifier<UpdateNewsState> {
  FutureOr<UpdateNewsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UpdateNewsState>, UpdateNewsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UpdateNewsState>, UpdateNewsState>,
              AsyncValue<UpdateNewsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
