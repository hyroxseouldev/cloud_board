import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/feature/ai_slides/data/datasources/center_slide_catalog_data_source.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';

void main() {
  test('private thumbnails share requests and at most three transfers run concurrently', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 16, height: 9)),
    );
    final digest = sha256.convert(bytes).toString();
    final recipes = [
      for (var i = 0; i < 8; i++)
        CenterSlideRecipe(
          templateId: 'item-$i',
          revision: 1,
          centerId: 'center',
          width: 1920,
          height: 1080,
          backgroundColor: 0xff000000,
          fields: [],
          thumbnail: CenterSlideThumbnail(
            path: 'center-templates/center/item-$i/$digest.png',
            sha256: digest,
            revision: 1,
            width: 16,
            height: 9,
          ),
        ),
    ];
    final gate = Completer<void>(), entered = Completer<void>();
    var requests = 0, active = 0, maximum = 0;
    final source = CenterSlideCatalogDataSource(
      projectId: 'demo',
      ownerId: 'owner',
      centerId: 'center',
      bucket: 'demo.test',
      isCurrentIdentity: () => true,
      idToken: () async => 'local-test-token',
      documents: () => const Stream.empty(),
      readServerDocument: () async => CenterSlideDocument(
        fromCache: false,
        data: {
          'schemaVersion': 1,
          'revision': 1,
          'centerName': '',
          'templates': [
            for (final recipe in recipes)
              {
                'id': recipe.templateId,
                'name': 'Preview',
                'description': '',
                'sortOrder': 0,
                'published': true,
                'recipe': recipe.toJson(),
              },
          ],
        },
      ),
      client: MockClient.streaming((request, _) async {
        expect(request.headers['Authorization'], 'Firebase local-test-token');
        requests++;
        active++;
        if (active > maximum) maximum = active;
        if (active == 3 && !entered.isCompleted) entered.complete();
        await gate.future;
        active--;
        return http.StreamedResponse(Stream.value(bytes), 200);
      }),
    );
    addTearDown(source.clear);
    final results = [
      for (final recipe in recipes) source.loadThumbnail('owner', recipe),
    ];
    final duplicate = source.loadThumbnail('owner', recipes.first);
    await entered.future;
    expect(requests, 3);
    gate.complete();
    await Future.wait([...results, duplicate]);
    expect(maximum, 3);
    expect(requests, 8);
  });
}
