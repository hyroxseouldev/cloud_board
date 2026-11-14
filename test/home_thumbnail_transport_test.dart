import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

const project = 'cloud-board-development';
final revision = DateTime.fromMillisecondsSinceEpoch(1794700000000);
String legacySource({String owner = 'owner', String bucketProject = project}) =>
    Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucketProject.firebasestorage.app/o/users%2F$owner%2Fworkouts%2Foriginal%2Fimages%2F${'a' * 64}',
        )
        .replace(
          queryParameters: {
            'alt': 'media',
            'token': 'storage-token-not-forwarded',
          },
        )
        .toString();

Uint8List renditionBytes({int width = 192}) {
  final image = img.Image(width: width, height: 108)
    ..clear(img.ColorRgb8(42, 77, 65));
  img.drawString(
    image,
    'MOVE',
    font: img.arial24,
    x: 12,
    y: 30,
    color: img.ColorRgb8(255, 253, 248),
  );
  return img.encodeJpg(image, quality: 72);
}

ImageUsageDataSource fixtureUsage({
  String owner = 'owner',
  String projectId = project,
  String? Function()? currentActor,
  Future<String> Function()? token,
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? call,
}) => ImageUsageDataSource(
  projectId: projectId,
  actorId: owner,
  currentActorId: currentActor ?? () => owner,
  token: token ?? () async => 'local-fixture-id-token',
  call:
      call ??
      (_, _) async =>
          throw StateError('Legacy thumbnail must not issue a callable'),
  readGate: () async => throw StateError('No admission/gate read on home'),
  send: (_) async => throw StateError('No unbounded shared body transport'),
  preferences: () async => throw StateError('No disk writes on home'),
);

void main() {
  test('legacy URI hashes exact source; rejects foreign origin, owner, bucket, production and unsafe demo', () {
    Uri? build(
      String source, {
      String owner = 'owner',
      String projectId = project,
      Uri? endpoint,
    }) => homeLegacyThumbnailUri(
      source: source,
      ownerId: owner,
      workoutId: 'copy',
      updatedAt: revision,
      projectId: projectId,
      demoEndpoint: endpoint,
    );
    final source = legacySource();
    final uri = build(source)!;
    expect(uri.host, 'asia-northeast3-$project.cloudfunctions.net');
    expect(uri.queryParameters, {
      'rendition': 'home-v1',
      'workoutId': 'copy',
      'sourceHash': sha256.convert(utf8.encode(source)).toString(),
      'updatedAtMs': revision.millisecondsSinceEpoch.toString(),
    });
    expect(uri.toString(), isNot(contains('storage-token')));
    final historical = source.replaceFirst(
      'images%2F${'a' * 64}',
      'modules%2Fslide-1%2Fbackground',
    );
    expect(build(historical), isNotNull);
    expect(
      build(
        'gs://$project.firebasestorage.app/users/owner/workouts/original/modules/slide-1/background',
      ),
      isNotNull,
    );
    expect(
      build(
        'gs://foreign.appspot.com/users/owner/workouts/original/modules/slide-1/background',
      ),
      isNull,
    );
    expect(
      build(historical.replaceFirst('workouts%2Foriginal%2F', '')),
      isNull,
    );
    expect(build('$source&alt=media'), isNull);
    expect(build('$source&arbitrary=1'), isNull);

    expect(
      build(source.replaceFirst('storage-token-not-forwarded', 'new-token'))!
          .queryParameters['sourceHash'],
      isNot(uri.queryParameters['sourceHash']),
    );
    for (final invalid in [
      source.replaceFirst('https:', 'http:'),
      source.replaceFirst('firebasestorage.googleapis.com', 'evil.invalid'),
      legacySource(owner: 'other'),
      legacySource(bucketProject: 'foreign'),
      source.replaceFirst('%2Fimages%2F', '%2Fsecret%2F'),
    ]) {
      expect(build(invalid), isNull);
    }
    expect(
      build(
        legacySource(bucketProject: 'cloud-board-stationd'),
        projectId: 'cloud-board-stationd',
      ),
      isNull,
    );
    expect(
      build(
        legacySource(bucketProject: 'demo-home'),
        projectId: 'demo-home',
        endpoint: Uri.parse(
          'http://evil.invalid/demo-home/asia-northeast3/cloudboardMedia',
        ),
      ),
      isNull,
    );
  });

  test(
    'legacy GET sends owner bearer only and uses exact summary identity',
    () async {
      final requests = <http.Request>[];
      final bytes = renditionBytes();
      final loader = HomeThumbnailLoader(
        'owner',
        usageFactory: fixtureUsage,
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(loader.dispose);
      expect(
        await loader.load(
          legacySource(),
          workoutId: 'copy',
          updatedAt: revision,
        ),
        bytes,
      );
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], 'Bearer local-fixture-id-token');
      expect(request.headers.containsKey('X-CloudBoard-Media-Lease'), isFalse);
      expect(request.url.queryParameters['workoutId'], 'copy');
      expect(request.url.toString(), isNot(contains('firebasestorage')));
    },
  );

  test('old server, stale, unauthorized, busy, malformed, oversized and redirects have no original fallback', () async {
    final valid = renditionBytes();
    for (final response in [
      http.Response('', 404),
      http.Response('', 401),
      http.Response('', 409),
      http.Response('', 503),
      http.Response('', 302, headers: {'location': legacySource()}),
      http.Response.bytes(valid, 200, headers: {'content-type': 'text/html'}),
      http.Response.bytes(
        [1, 2, 3],
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
      http.Response.bytes(
        Uint8List(homeThumbnailMaxBytes + 1),
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
      http.Response.bytes(
        renditionBytes(width: 193),
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
    ]) {
      var calls = 0;
      final loader = HomeThumbnailLoader(
        'owner',
        usageFactory: fixtureUsage,
        clientFactory: () => MockClient((request) async {
          calls++;
          return response;
        }),
      );
      expect(
        await loader.load(
          legacySource(),
          workoutId: 'copy',
          updatedAt: revision,
        ),
        isNull,
      );
      expect(calls, 1);
      loader.dispose();
    }
  });

  test(
    'stream byte cap, length mismatch and account change discard response',
    () async {
      final bytes = renditionBytes();
      for (final scenario in ['overflow', 'length', 'account', 'disposed']) {
        String? actor = 'owner';
        late HomeThumbnailLoader loader;
        var closed = false;
        loader = HomeThumbnailLoader(
          'owner',
          usageFactory: () => fixtureUsage(currentActor: () => actor),
          clientFactory: () => _StreamClient((request) async {
            Stream<List<int>> body() async* {
              if (scenario == 'account') actor = 'other';
              if (scenario == 'disposed') loader.dispose();
              yield scenario == 'overflow'
                  ? Uint8List(homeThumbnailMaxBytes + 1)
                  : bytes;
            }

            return http.StreamedResponse(
              body(),
              200,
              contentLength: scenario == 'length'
                  ? bytes.length + 1
                  : bytes.length,
              headers: {'content-type': 'image/jpeg'},
            );
          }, () => closed = true),
        );
        final cache = HomeThumbnailCache(loader.load);
        expect(
          await cache.watch(legacySource(), revision, workoutId: 'copy').future,
          isNull,
        );
        expect(closed, isTrue);
        cache.dispose();
        loader.dispose();
      }
    },
  );

  test('account changes before token completion send no request', () async {
    String? actor = 'owner';
    final token = Completer<String>();
    var calls = 0;
    final loader = HomeThumbnailLoader(
      'owner',
      usageFactory: () =>
          fixtureUsage(currentActor: () => actor, token: () => token.future),
      clientFactory: () => MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    final cache = HomeThumbnailCache(loader.load);
    final request = cache.watch(legacySource(), revision, workoutId: 'copy');
    await Future<void>.delayed(Duration.zero);
    actor = null;
    token.complete('old-account-token');
    expect(await request.future, isNull);
    expect(calls, 0);
    cache.dispose();
    loader.dispose();
  });

  test('managed still requires exact generation owner-preview lease', () async {
    const source =
        'https://asia-northeast3-cloud-board-development.cloudfunctions.net/cloudboardMedia?assetId=asset&v=7';
    final calls = <String>[];
    final loader = HomeThumbnailLoader(
      'owner',
      usageFactory: () => fixtureUsage(
        call: (endpoint, input) async {
          calls.add(endpoint);
          expect(input['purpose'], 'preview');
          expect(input['admissionId'], isNull);
          return {
            'leaseId': 'lease',
            'assets': [
              {'source': source, 'generation': '7'},
            ],
          };
        },
      ),
      clientFactory: () => MockClient((request) async {
        expect(request.headers['X-CloudBoard-Media-Lease'], 'lease');
        expect(request.url.queryParameters['v'], '7');
        return http.Response.bytes(
          renditionBytes(),
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }),
    );
    expect(await loader.load(source), isNotNull);
    expect(calls, ['cloudboardMediaLease']);
    loader.dispose();
  });

  testWidgets(
    'real loopback HTTP delivers bounded legacy JPEG without an original GET',
    (tester) async {
      await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final bytes = renditionBytes();
          final requests = <Uri>[];
          server.listen((request) async {
            requests.add(request.uri);
            expect(
              request.headers.value('authorization'),
              'Bearer local-fixture-id-token',
            );
            expect(request.headers.value('x-cloudboard-media-lease'), isNull);
            request.response.headers.contentType = ContentType('image', 'jpeg');
            request.response.contentLength = bytes.length;
            request.response.add(bytes);
            await request.response.close();
          });
          final loader = HomeThumbnailLoader(
            'owner',
            usageFactory: () => fixtureUsage(projectId: 'demo-home'),
            demoEndpoint: Uri.parse(
              'http://127.0.0.1:${server.port}/demo-home/asia-northeast3/cloudboardMedia',
            ),
          );
          try {
            final result = await loader.load(
              legacySource(bucketProject: 'demo-home'),
              workoutId: 'copy',
              updatedAt: revision,
            );
            expect(result, bytes);
            expect(
              requests.single.path,
              '/demo-home/asia-northeast3/cloudboardMedia',
            );
            expect(requests.single.queryParameters['rendition'], 'home-v1');
          } finally {
            loader.dispose();
            await server.close(force: true);
          }
        }, _NativeHttpOverrides()),
      );
    },
  );
}

class _StreamClient extends http.BaseClient {
  _StreamClient(this.respond, this.onClose);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  final void Function() onClose;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      respond(request);
  @override
  void close() => onClose();
}

class _NativeHttpOverrides extends HttpOverrides {}
