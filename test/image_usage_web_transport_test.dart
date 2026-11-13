@TestOn('browser')
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_data_source.dart';

const origin = String.fromEnvironment('IMAGE_USAGE_HTTP_TEST_ORIGIN');
const source =
    'https://asia-northeast3-demo-browser.cloudfunctions.net/cloudboardMedia?assetId=browser-asset&v=123';
void main() {
  testWidgets(
    'browser sends authenticated cross-origin bytes after lease/reservation and renders without HTML fallback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=',
      );
      final asset = {
        'assetId': 'browser-asset',
        'source': source,
        'generation': '123',
        'sizeBytes': png.length,
        'contentType': 'image/png',
        'sha256': sha256.convert(png).toString(),
      };
      var leased = false, reserved = false;
      final transport = http.Client();
      addTearDown(transport.close);
      final client = ImageUsageDataSource(
        projectId: 'demo-browser',
        actorId: 'owner',
        currentActorId: () => 'owner',
        token: () async => 'synthetic-test-token',
        readGate: () async => {'mode': 'enrolled'},
        preferences: SharedPreferences.getInstance,
        call: (endpoint, input) async {
          if (endpoint == 'cloudboardMediaLease') {
            leased = true;
            return {
              'schemaVersion': 1,
              'leaseId': 'synthetic-lease',
              'expiresAtMs': 90000,
              'assets': [asset],
              'sessionId': null,
              'epoch': null,
            };
          }
          expect(endpoint, 'cloudboardImageUpload');
          expect(input['action'], 'reserve');
          reserved = true;
          return {
            'schemaVersion': 1,
            'uploadId': 'browser-upload',
            'expiresAtMs': 90000,
            'status': 'reserved',
            'asset': null,
            'uploadUrl': 'https://asia-northeast3-demo-browser.cloudfunctions.net/cloudboardImageUploadBody',
          };
        },
        send: (request) async {
          expect(request.method == 'GET' ? leased : reserved, isTrue);
          final uri = Uri.parse(origin).replace(
            path: request.url.path,
            query: request.url.hasQuery ? request.url.query : null,
          );
          final actual = http.Request(request.method, uri)
            ..headers.addAll(request.headers)
            ..bodyBytes = request.bodyBytes
            ..followRedirects = false;
          return http.Response.fromStream(await transport.send(actual));
        },
      );
      addTearDown(client.dispose);
      final body = await tester.runAsync(() => client.media(source));
      expect(body, png);
      await tester.pumpWidget(
        MaterialApp(home: Image(image: MemoryImage(body!))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HtmlElementView), findsNothing);
      expect(tester.takeException(), isNull);
      final stored = await tester.runAsync(
        () => client.upload(
          bytes: png,
          contentType: 'image/png',
          purpose: 'profile',
        ),
      );
      expect(stored, source);
    },
    skip: origin.isEmpty,
  );
}
