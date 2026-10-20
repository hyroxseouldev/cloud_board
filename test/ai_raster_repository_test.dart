import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/ai_raster_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_raster_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';

import 'support/ai_raster_fakes.dart';

class UnusedFunctions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network allowed');
}

class Source extends AiRasterDataSource {
  Source(this.current, this.bytes, this.brand, this.job)
    : super(UnusedFunctions(), 'local', () => current.value);
  final ({bool value}) current;
  final Uint8List bytes;
  final AiRasterBrand brand;
  final AiRasterJob job;
  bool revoked = false;
  int assets = 0, confirms = 0;
  @override
  bool Function() get isCurrent =>
      () => !revoked && current.value;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!isCurrent()) throw const AiSlidesFailure('revoked');
    if (action == 'confirm') {
      confirms++;
      return {'brand': brand.toJson(), 'job': job.toJson()};
    }
    if (action == 'asset') {
      assets++;
      return {'base64': base64Encode(bytes), 'brandKey': brand.key};
    }
    throw StateError(action);
  }
}

void main() {
  // A deterministic header is sufficient here: the injected final composer is
  // separately covered by real decoder/pixel tests in ai_raster_renderer_test.
  Uint8List png() {
    final bytes = Uint8List(33)..setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
    ByteData.sublistView(bytes)
      ..setUint32(16, 16)
      ..setUint32(20, 9);
    return bytes;
  }

  test('cache hits recheck account scope and final PNG encodes once with fresh confirmation per add', () async {
    final bytes = png();
    final descriptor = AiRasterAsset(
      sha256: sha256.convert(bytes).toString(),
      width: 16,
      height: 9,
      sourceRect: [0, 0, 16, 9],
    );
    final brand = rasterTestBrand.copyWith(
      reference: descriptor,
      logo: descriptor,
    );
    final job = rasterTestJob('one').copyWith(artifact: descriptor);
    final source = Source((value: true), bytes, brand, job);
    var encodes = 0;
    final repository = AiRasterRepositoryImpl(
      source,
      compose: (draft, brand, art, logo) async {
        encodes++;
        return bytes;
      },
    );
    addTearDown(repository.dispose);
    await repository.asset(brand, null, 'logo');
    await repository.asset(brand, null, 'logo');
    expect(source.assets, 1);
    final first = await repository.createModule(job, brand),
        second = await repository.createModule(job, brand);
    expect(encodes, 1);
    expect(source.confirms, 4);
    expect(source.assets, 2);
    expect(first.imageSource, second.imageSource);
    expect(first.text, rasterTestDraft.rawWod);
    expect(first.showTimer, isFalse);
    expect(first.showSets, isFalse);
    expect(first.appearance.showBrand, isFalse);
    source.revoked = true;
    await expectLater(
      repository.asset(brand, null, 'logo'),
      throwsA(isA<AiSlidesFailure>()),
    );
    await expectLater(
      repository.createModule(job, brand),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(encodes, 1);
  });
  test('corrupt/hash-mismatched private bytes never enter cache', () async {
    final bytes = png(),
        brand = rasterTestBrand.copyWith(
          logo: const AiRasterAsset(sha256: 'wrong', width: 16, height: 9),
        );
    final source = Source((value: true), bytes, brand, rasterTestJob('one'));
    final repository = AiRasterRepositoryImpl(source);
    addTearDown(repository.dispose);
    await expectLater(
      repository.asset(brand, null, 'logo'),
      throwsA(isA<AiSlidesFailure>()),
    );
    await expectLater(
      repository.asset(brand, null, 'logo'),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(source.assets, 2);
  });
}
