"""Loopback-only PNG fixture for workout_image_web_test.dart (no Firebase).

python3 test/support/workout_image_http_fixture.py --origin-file build/image-origin.txt
flutter test --platform chrome --dart-define=WORKOUT_IMAGE_TEST_ORIGIN=<printed origin> test/workout_image_web_test.dart
"""

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import struct
from urllib.parse import urlparse
import zlib


def png(width, height, color):
    def chunk(kind, data):
        return (struct.pack('!I', len(data)) + kind + data +
                struct.pack('!I', zlib.crc32(kind + data)))

    rows = []
    marker = height // 10
    for y in range(height):
        row = bytearray(bytes(color) * width)
        if y < marker or y >= height - marker:
            left, right = ((255, 0, 0), (0, 255, 0)) if y < marker else ((0, 0, 255), (255, 255, 0))
            row[:marker * 3] = bytes(left) * marker
            row[-marker * 3:] = bytes(right) * marker
        rows.append(b'\0' + row)
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b''))


fixtures = {
    f'{ratio}-{tone}.png': png(*size, color)
    for ratio, size in [('exact', (1920, 1080)), ('near', (1672, 941))]
    for tone, color in [('light', (248, 240, 224)), ('dark', (32, 40, 48))]
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = urlparse(self.path).path.strip('/').split('/')
        body = fixtures.get(route[-1]) if len(route) == 2 else None
        self.send_response(200 if body else 404)
        if route[0] == 'cors':
            self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'image/png')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body or b'')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--origin-file', required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    origin = f'http://127.0.0.1:{server.server_port}'
    target = Path(args.origin_file)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(origin)
    print(origin, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
