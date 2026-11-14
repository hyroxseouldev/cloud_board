# Run from build/web after building compact_preflight.dart; local-only HTTP evidence.
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse
import json, base64, sys
requests=[]
class Handler(SimpleHTTPRequestHandler):
 def do_GET(self):
  path=urlparse(self.path).path
  if path == '/metrics':
   body=json.dumps(requests).encode(); self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers(); self.wfile.write(body); return
  if path == '/fixture-image.png':
   requests.append(self.path)
   body=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
   self.send_response(200); self.send_header('Content-Type','image/png'); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(body); return
  super().do_GET()
 def end_headers(self):
  self.send_header('Cache-Control','no-store'); super().end_headers()
ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1]) if len(sys.argv) > 1 else 8796),Handler).serve_forever()
