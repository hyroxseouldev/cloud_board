"""Check the final IPA before upload and save non-secret signing diagnostics."""

import argparse
import json
import plistlib
import subprocess
import tempfile
import zipfile
from pathlib import Path


def inspect(ipa):
    with tempfile.TemporaryDirectory(prefix="cloudboard-signing-") as directory:
        app = Path(directory) / "Runner.app"
        app.mkdir()
        with zipfile.ZipFile(ipa) as archive:
            info_name, = [
                name for name in archive.namelist()
                if name.startswith("Payload/") and name.count("/") == 2
                and name.endswith(".app/Info.plist")
            ]
            info = plistlib.loads(archive.read(info_name))
            prefix = info_name.removesuffix("Info.plist")
            executable = info["CFBundleExecutable"]
            if Path(executable).name != executable:
                raise ValueError("Unexpected executable name")
            for name in ["Info.plist", executable, "embedded.mobileprovision"]:
                (app / name).write_bytes(archive.read(prefix + name))
        signed = subprocess.run(
            ["codesign", "-d", "--entitlements", ":-", str(app)],
            capture_output=True, check=True,
        )
        entitlements = plistlib.loads(signed.stdout)
        decoded = subprocess.run(
            ["security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")],
            capture_output=True, check=True,
        )
        profile = plistlib.loads(decoded.stdout)["Entitlements"]
        return {
            "bundleId": info["CFBundleIdentifier"],
            "version": info["CFBundleShortVersionString"],
            "build": info["CFBundleVersion"],
            "signedAppleSignIn": entitlements.get("com.apple.developer.applesignin", []),
            "profileAppleSignIn": profile.get("com.apple.developer.applesignin", []),
            "signedTeam": entitlements.get("com.apple.developer.team-identifier"),
            "signedApplicationId": entitlements.get("application-identifier"),
            "signedKeychainGroups": entitlements.get("keychain-access-groups", []),
            "signedDebuggable": entitlements.get("get-task-allow"),
            "profileTeam": profile.get("com.apple.developer.team-identifier"),
            "profileApplicationId": profile.get("application-identifier"),
        }


def validate(report, team_id, bundle_id):
    errors = []
    for field in ["signedAppleSignIn", "profileAppleSignIn"]:
        if "Default" not in report.get(field, []):
            errors.append(f"{field}: Sign in with Apple entitlement is missing")
    expected_id = team_id + "." + bundle_id
    for field, expected in {
        "bundleId": bundle_id,
        "signedTeam": team_id,
        "profileTeam": team_id,
        "signedApplicationId": expected_id,
        "profileApplicationId": expected_id,
    }.items():
        if report.get(field) != expected:
            errors.append(f"{field}: release signing identity mismatch")
    if expected_id not in report.get("signedKeychainGroups", []):
        errors.append("The app's Firebase Auth keychain access group is missing")
    if report.get("signedDebuggable") is not False:
        errors.append("The IPA must have get-task-allow disabled for distribution")
    return errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa")
    parser.add_argument("output")
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()
    report = inspect(args.ipa)
    report["validationErrors"] = validate(report, args.team_id, args.bundle_id)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    Path(args.output).write_text(text + "\n")
    print(text)
    for error in report["validationErrors"]:
        print("::error::" + error)
    if report["validationErrors"]:
        raise SystemExit(1)
