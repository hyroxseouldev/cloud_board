import copy
import importlib.util
from pathlib import Path
import struct
import unittest
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('inspect_native', Path(__file__).with_name('inspect_native.py'))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class NativeArtifactTests(unittest.TestCase):
    def test_compiled_binding_rejects_missing_development_and_conflicting_markers(self):
        gate.verify_binding(b'prefix' + gate.MARKER + b'suffix', 'arm64')
        for binary in [b'', gate.MARKER.replace(b'production', b'development'),
                       gate.MARKER + gate.MARKER.replace(b'production', b'development')]:
            with self.assertRaises(ValueError): gate.verify_binding(binary, 'arm64')

    def test_every_macho_architecture_is_inspected(self):
        good = b'\xcf\xfa\xed\xfe' + gate.MARKER
        bad = b'\xcf\xfa\xed\xfeother'
        start = 48
        binary = b'\xca\xfe\xba\xbe' + struct.pack('>I', 2)
        binary += struct.pack('>IIIII', 1, 0, start, len(good), 0)
        binary += struct.pack('>IIIII', 2, 0, start + len(good), len(bad), 0)
        binary += good + bad
        slices = list(gate.macho_slices(binary))
        self.assertEqual(len(slices), 2)
        with self.assertRaises(ValueError):
            for name, code in slices: gate.verify_binding(code, name)

    def test_native_metadata_must_match_version_build_package_and_production_sdk(self):
        info = {'CFBundleIdentifier': gate.PACKAGE, 'CFBundleShortVersionString': '1.1.0', 'CFBundleVersion': '554'}
        firebase = {'BUNDLE_ID': gate.PACKAGE, 'PROJECT_ID': gate.PROJECT, 'GCM_SENDER_ID': '428540903054',
                    'GOOGLE_APP_ID': '1:428540903054:ios:2483df8a16e997ba3d93df',
                    'DATABASE_URL': gate.FIREBASE['firebase_database_url'], 'STORAGE_BUCKET': gate.FIREBASE['google_storage_bucket']}
        gate.check_ios_metadata(info, firebase, '1.1.0', '554')
        for key in info:
            wrong = copy.copy(info); wrong[key] = 'wrong'
            with self.assertRaises(ValueError): gate.check_ios_metadata(wrong, firebase, '1.1.0', '554')
        wrong = {**firebase, 'PROJECT_ID': 'cloud-board-development'}
        with self.assertRaises(ValueError): gate.check_ios_metadata(info, wrong, '1.1.0', '554')

    def test_android_mobile_tv_manifest_and_all_resource_variants(self):
        manifest = ET.fromstring('<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.sunmkim.cloudboard" android:versionName="1.1.0" android:versionCode="66"><uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/><application/><uses-feature android:name="android.software.leanback" android:required="false"/></manifest>')
        gate.check_android_manifest(manifest, '1.1.0', '66')
        with self.assertRaises(ValueError): gate.check_android_manifest(manifest, '1.0.0', '66')
        manifest.find('application').set(gate.ANDROID_NS + 'debuggable', 'true')
        with self.assertRaises(ValueError): gate.check_android_manifest(manifest, '1.1.0', '66')
        # Format taken from bundletool 1.18.3 DumpManagerTest.printResources_withValues.
        dump = 'Package \'com.sunmkim.cloudboard\':\n0x7f010000 - string/project_id\n\t(default) - [STR] "cloud-board-stationd"\n\n'
        gate.check_resource_dump(dump, 'project_id', gate.PROJECT)
        with self.assertRaises(ValueError): gate.check_resource_dump(dump + '\tko - [STR] "cloud-board-development"\n', 'project_id', gate.PROJECT)
        with self.assertRaises(ValueError): gate.check_resource_dump('', 'project_id', gate.PROJECT)
        with self.assertRaises(ValueError): gate.check_resource_dump(dump + '\tko - [REF] 0x7f010001\n', 'project_id', gate.PROJECT)
        with self.assertRaises(ValueError): gate.check_resource_dump(dump.replace('"cloud-board-stationd"', 'cloud-board-stationd'), 'project_id', gate.PROJECT)
        gate.check_resource_dump(dump.replace('[STR]', '[RAW_STR]'), 'project_id', gate.PROJECT)

    def test_development_artifact_cannot_be_confused_with_production(self):
        config = gate.binding('development')
        gate.verify_binding(config['marker'], 'arm64', 'development')
        for code in [gate.MARKER, config['marker'] + gate.MARKER]:
            with self.assertRaises(ValueError): gate.verify_binding(code, 'arm64', 'development')
        info = {'CFBundleIdentifier': config['package'], 'CFBundleShortVersionString': '1.2.2', 'CFBundleVersion': '1'}
        firebase = {'BUNDLE_ID': config['package'], 'PROJECT_ID': config['project'], 'GCM_SENDER_ID': config['sender'],
                    'GOOGLE_APP_ID': config['ios_app'], 'DATABASE_URL': config['database'], 'STORAGE_BUCKET': config['bucket']}
        gate.check_ios_metadata(info, firebase, '1.2.2', '1', 'development')
        with self.assertRaises(ValueError): gate.check_ios_metadata(info, firebase, '1.2.2', '1', 'production')
        for key in firebase:
            wrong = {**firebase, key: 'production-value'}
            with self.assertRaises(ValueError): gate.check_ios_metadata(info, wrong, '1.2.2', '1', 'development')

if __name__ == '__main__': unittest.main()
