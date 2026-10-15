"""Inspect the built AAB/IPA (not source configuration) before store upload."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

PACKAGE = "com.sunmkim.cloudboard"
PROJECT = "cloud-board-stationd"
MARKER = b"cloudboard-release-binding:env=production;flavor=production;"
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
BUNDLETOOL_SHA256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29"


def binding(environment="production"):
    require(environment in ("production", "development"), "Unknown artifact environment")
    dev = environment == "development"
    project = "cloud-board-development" if dev else PROJECT
    return {
        "package": PACKAGE + (".dev" if dev else ""), "project": project,
        "sender": "1339501332" if dev else "428540903054",
        "android_app": "1:1339501332:android:1afe8ec27a953ed01ef001" if dev else "1:428540903054:android:372a37e13694a69b3d93df",
        "ios_app": "1:1339501332:ios:56b1f0d4a67a4e0c1ef001" if dev else "1:428540903054:ios:2483df8a16e997ba3d93df",
        "database": f"https://{project}-default-rtdb.asia-southeast1.firebasedatabase.app",
        "bucket": f"{project}.firebasestorage.app",
        "marker": f"cloudboard-release-binding:env={environment};flavor={environment};".encode(),
    }


def firebase_resources(environment="production"):
    config = binding(environment)
    return {"project_id": config["project"], "gcm_defaultSenderId": config["sender"],
            "google_app_id": config["android_app"], "firebase_database_url": config["database"],
            "google_storage_bucket": config["bucket"]}


def require(condition, message):
    if not condition:
        raise ValueError(message)


FIREBASE = firebase_resources()

def verify_binding(binary, name, environment="production"):
    marker = binding(environment)["marker"]
    require(marker in binary, f"{name}: compiled Dart {environment} binding is missing")
    markers = re.findall(rb"cloudboard-release-binding:env=[^;\x00]{0,40};flavor=[^;\x00]{0,40};", binary)
    require(set(markers) == {marker}, f"{name}: conflicting Dart environment binding")


def macho_slices(binary):
    magic = binary[:4]
    if magic in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        count, = struct.unpack_from(">I", binary, 4)
        require(0 < count <= 8, "Unexpected Mach-O architecture count")
        wide = magic == b"\xca\xfe\xba\xbf"
        for index in range(count):
            start = 8 + index * (32 if wide else 20)
            cpu, subtype, offset, size = struct.unpack_from(">IIQQ" if wide else ">IIII", binary, start)
            require(offset + size <= len(binary), "Truncated Mach-O architecture")
            yield f"cpu-{cpu}-{subtype}", binary[offset:offset + size]
    else:
        require(magic in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"), "Invalid Mach-O App.framework executable")
        yield "native", binary


def check_ios_metadata(info, firebase, version, build, environment="production"):
    config = binding(environment)
    for key, expected in {"CFBundleIdentifier": config["package"], "CFBundleShortVersionString": version,
                          "CFBundleVersion": str(build)}.items():
        require(info.get(key) == expected, f"IPA {key} mismatch")
    for key, expected in {
        "BUNDLE_ID": config["package"], "PROJECT_ID": config["project"], "GCM_SENDER_ID": config["sender"],
        "GOOGLE_APP_ID": config["ios_app"],
        "DATABASE_URL": config["database"], "STORAGE_BUCKET": config["bucket"],
    }.items():
        require(firebase.get(key) == expected, f"IPA Firebase {key} mismatch")


def inspect_ios(path, version, build, environment="production"):
    with zipfile.ZipFile(path) as archive:
        infos = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        require(len(infos) == 1, "Expected one application in IPA")
        prefix = infos[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(infos[0]))
        firebase = plistlib.loads(archive.read(prefix + "GoogleService-Info.plist"))
        check_ios_metadata(info, firebase, version, build, environment)
        architectures = []
        for architecture, binary in macho_slices(archive.read(prefix + "Frameworks/App.framework/App")):
            verify_binding(binary, architecture, environment)
            architectures.append(architecture)
        return {"platform": "ios", "package": info["CFBundleIdentifier"], "firebaseProject": firebase["PROJECT_ID"],
                "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"], "dartArchitectures": architectures}


def check_android_manifest(manifest, version, build, environment="production"):
    require(manifest.get("package") == binding(environment)["package"], "AAB package mismatch")
    require(manifest.get(ANDROID_NS + "versionName") == version, "AAB versionName mismatch")
    require(manifest.get(ANDROID_NS + "versionCode") == str(build), "AAB versionCode mismatch")
    sdk = manifest.find("uses-sdk")
    require(sdk is not None, "AAB SDK requirements are missing")
    require(sdk.get(ANDROID_NS + "minSdkVersion") == "24", "AAB minSdk must remain 24 for this release")
    require(sdk.get(ANDROID_NS + "targetSdkVersion") == "36", "AAB targetSdk must be 36 for this release")
    application = manifest.find("application")
    require(application is not None, "AAB application missing")
    require(application.get(ANDROID_NS + "debuggable", "false") == "false", "AAB must not be debuggable")
    leanback = [node for node in manifest.findall("uses-feature") if node.get(ANDROID_NS + "name") == "android.software.leanback"]
    require(len(leanback) == 1 and leanback[0].get(ANDROID_NS + "required") == "false", "AAB must support mobile and TV")


def check_resource_dump(dump, name, expected):
    require(f"string/{name}" in dump, f"AAB Firebase resource {name} missing")
    # Pinned bundletool prints protobuf enum names, e.g. [STR] "value".
    # Inspect every configuration, including an unexpected reference/type.
    values = re.findall(r" - \[([^\]]+)\] (.*)$", dump, flags=re.MULTILINE)
    require(values, f"AAB Firebase {name} has no values")
    for kind, raw_value in values:
        require(kind in ("STR", "RAW_STR"), f"AAB Firebase {name} is not a literal string")
        try:
            value = json.loads(raw_value)
        except json.JSONDecodeError as error:
            raise ValueError(f"AAB Firebase {name} has an invalid quoted value") from error
        require(value == expected, f"AAB Firebase {name} mismatch")


def verify_android_signature(path):
    result = subprocess.run(["jarsigner", "-J-Duser.language=en", "-verify", str(path)],
                            capture_output=True, check=True, text=True)
    require("jar verified." in result.stdout, "AAB JAR signature verification failed")
    keystore = os.environ.get("ANDROID_KEYSTORE_PATH")
    alias = os.environ.get("ANDROID_KEY_ALIAS")
    require(keystore and alias and os.environ.get("ANDROID_KEYSTORE_PASSWORD"), "Expected upload-key identity is required")
    def fingerprint(args):
        output = subprocess.run(["keytool", "-J-Duser.language=en", *args],
                                capture_output=True, check=True, text=True).stdout
        matches = re.findall(r"SHA256:\s*([A-F0-9:]{95})", output)
        require(len(set(matches)) == 1, "Expected one upload signing certificate")
        return matches[0]
    expected = fingerprint(["-list", "-v", "-keystore", keystore, "-alias", alias,
                            "-storepass:env", "ANDROID_KEYSTORE_PASSWORD"])
    actual = fingerprint(["-printcert", "-jarfile", str(path)])
    require(actual == expected, "AAB signer differs from configured Play upload key")
    return actual


def inspect_android(path, version, build, bundletool, environment="production"):
    require(bundletool and Path(bundletool).is_file(), "Pinned bundletool is required")
    require(hashlib.sha256(Path(bundletool).read_bytes()).hexdigest() == BUNDLETOOL_SHA256, "bundletool checksum mismatch")
    def dump(*args):
        return subprocess.run(["java", "-jar", str(bundletool), "dump", *args, f"--bundle={path}"],
                              capture_output=True, check=True, text=True).stdout
    signing_certificate = verify_android_signature(path)
    manifest = ET.fromstring(dump("manifest", "--module=base"))
    check_android_manifest(manifest, version, build, environment)
    for name, expected in firebase_resources(environment).items():
        check_resource_dump(dump("resources", f"--resource=string/{name}", "--values"), name, expected)
    with zipfile.ZipFile(path) as archive:
        libraries = [name for name in archive.namelist() if re.fullmatch(r"base/lib/[^/]+/libapp\.so", name)]
        abis = {name.split("/")[2] for name in libraries}
        require(abis == {"armeabi-v7a", "arm64-v8a", "x86_64"}, "Expected all three release Android ABIs")
        for library in libraries:
            verify_binding(archive.read(library), library, environment)
    return {"platform": "android-tv", "package": binding(environment)["package"], "firebaseProject": binding(environment)["project"], "version": version,
            "build": str(build), "minSdk": 24, "targetSdk": 36,
            "dartArchitectures": sorted(abis), "uploadCertificateSha256": signing_certificate}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["ios", "android"])
    parser.add_argument("artifact")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--bundletool")
    parser.add_argument("--environment", choices=["production", "development"], required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"\d+\.\d+\.\d+", args.version), "Invalid marketing version")
    require(re.fullmatch(r"[1-9]\d*", args.build), "Invalid native build number")
    path = Path(args.artifact)
    report = (inspect_ios(path, args.version, args.build, args.environment) if args.platform == "ios"
              else inspect_android(path, args.version, args.build, args.bundletool, args.environment))
    report["artifactSha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    report["artifact"] = path.name
    report["environment"] = args.environment
    report["environmentBindingVerified"] = True
    report["productionBindingVerified"] = args.environment == "production"
    Path(args.output).write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
