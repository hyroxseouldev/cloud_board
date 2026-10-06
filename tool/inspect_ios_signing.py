"""Record the entitlements of the actual exported IPA, without credentials."""

import json
import plistlib
import subprocess
import sys
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
        }


if __name__ == "__main__":
    report = inspect(sys.argv[1])
    text = json.dumps(report, ensure_ascii=False, indent=2)
    Path(sys.argv[2]).write_text(text + "\n")
    print(text)
    if "Default" not in report["signedAppleSignIn"]:
        print("::warning::Exported IPA is missing the Sign in with Apple entitlement")
