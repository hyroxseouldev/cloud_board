// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_starter_workout.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(importStarterWorkout)
final importStarterWorkoutProvider = ImportStarterWorkoutProvider._();

final class ImportStarterWorkoutProvider
    extends
        $FunctionalProvider<
          AsyncValue<ImportStarterWorkout>,
          ImportStarterWorkout,
          FutureOr<ImportStarterWorkout>
        >
    with
        $FutureModifier<ImportStarterWorkout>,
        $FutureProvider<ImportStarterWorkout> {
  ImportStarterWorkoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importStarterWorkoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importStarterWorkoutHash();

  @$internal
  @override
  $FutureProviderElement<ImportStarterWorkout> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ImportStarterWorkout> create(Ref ref) {
    return importStarterWorkout(ref);
  }
}

String _$importStarterWorkoutHash() =>
    r'e82c8d45c7115fe2fec4363485ac2e6c3581da44';
