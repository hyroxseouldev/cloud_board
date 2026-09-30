#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fvm flutter test tool/generate_splash_assets_test.dart
fvm dart run flutter_native_splash:create

# The generator keeps the template's black night theme and platform-default
# system bars. Match the app's light startup surface in every resource variant.
python3 - <<'PY'
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

for qualifier in ('values', 'values-night', 'values-v31', 'values-night-v31'):
    path = Path(f'android/app/src/main/res/{qualifier}/styles.xml')
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(path.read_text(), parser=parser)
    for style in root.findall('style'):
        if style.get('name') not in ('LaunchTheme', 'NormalTheme'):
            continue
        style.set('parent', '@android:style/Theme.Light.NoTitleBar')
        values = {
            'android:forceDarkAllowed': 'false',
            'android:windowDrawsSystemBarBackgrounds': 'true',
            'android:statusBarColor': '@android:color/transparent',
            'android:windowLightStatusBar': 'true',
            'android:navigationBarColor': '@android:color/white',
            'android:windowLightNavigationBar': 'true',
        }
        if style.get('name') == 'NormalTheme':
            values['android:windowBackground'] = '@android:color/white'
        for name, value in values.items():
            item = next((i for i in style.findall('item') if i.get('name') == name), None)
            if item is None:
                item = ET.SubElement(style, 'item', {'name': name})
            item.text = value
        # The package removes and appends its own items on each run. Keep the
        # final ordering stable alongside the app's additional system-bar items.
        items = sorted(style.findall('item'), key=lambda item: item.get('name'))
        for item in items:
            style.remove(item)
        style.extend(items)
    ET.indent(root, space='    ')
    path.write_text('<?xml version="1.0" encoding="utf-8"?>\n' + ET.tostring(root, encoding='unicode') + '\n')

path = Path('ios/Runner/Info.plist')
info = plistlib.loads(path.read_bytes())
info['UIUserInterfaceStyle'] = 'Light'
path.write_bytes(plistlib.dumps(info, sort_keys=False))
PY
