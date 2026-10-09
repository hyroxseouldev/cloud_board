"""Temporarily align the native default Firebase app with the debug emulator app.

Use prepare before an iOS preview build and restore afterwards. Never prints
Firebase configuration values. The original is kept outside the repository.
"""
import hashlib
import plistlib
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
target = root / 'ios/Runner/GoogleService-Info.plist'
identity = hashlib.sha256(str(root).encode()).hexdigest()[:16]
backup = Path(tempfile.gettempdir()) / f'cloudboard-studio-plist-{identity}.backup'
if sys.argv[1:] == ['prepare']:
    if not backup.exists():
        backup.write_bytes(target.read_bytes())
        backup.chmod(0o600)
    value = plistlib.loads(backup.read_bytes())
    value['PROJECT_ID'] = 'demo-cloudboard-studio'
    value['STORAGE_BUCKET'] = 'demo-cloudboard-studio.appspot.com'
    value['DATABASE_URL'] = 'https://demo-cloudboard-studio-default-rtdb.asia-southeast1.firebasedatabase.app'
    target.write_bytes(plistlib.dumps(value))
    print('Prepared native Firebase configuration for local preview.')
elif sys.argv[1:] == ['restore']:
    if backup.exists():
        target.write_bytes(backup.read_bytes())
        backup.unlink()
    print('Restored original native Firebase configuration.')
else:
    raise SystemExit('Usage: ios_config.py prepare|restore')
