"""Carry source entitlements through export of Flutter's unsigned archive.

The temporary ad-hoc signature only transports entitlements. xcodebuild must
replace it with the Apple Distribution signature and provisioning profile.
"""

import argparse
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path


def resolve(value, team_id, bundle_id):
    if isinstance(value, dict):
        return {key: resolve(item, team_id, bundle_id) for key, item in value.items()}
    if isinstance(value, list):
        return [resolve(item, team_id, bundle_id) for item in value]
    if isinstance(value, str):
        replacements = {
            "AppIdentifierPrefix": team_id + ".",
            "CFBundleIdentifier": bundle_id,
        }
        for key, replacement in replacements.items():
            value = value.replace("$(" + key + ")", replacement)
        if re.search(r"\$[({]", value):
            raise ValueError("Unresolved entitlement build setting")
    return value


def prepare(archive, source, team_id, bundle_id):
    app, = (Path(archive) / "Products/Applications").glob("*.app")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != bundle_id:
        raise ValueError("Archived bundle ID does not match the release configuration")
    entitlements = resolve(plistlib.loads(Path(source).read_bytes()), team_id, bundle_id)
    if "Default" not in entitlements.get("com.apple.developer.applesignin", []):
        raise ValueError("Source entitlements must enable Sign in with Apple")
    with tempfile.TemporaryDirectory(prefix="cloudboard-entitlements-") as directory:
        resolved = Path(directory) / "Runner.entitlements"
        resolved.write_bytes(plistlib.dumps(entitlements))
        subprocess.run([
            "codesign", "--force", "--sign", "-", "--entitlements", str(resolved),
            "--generate-entitlement-der", str(app),
        ], check=True)
    signed = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        capture_output=True, check=True,
    )
    if plistlib.loads(signed.stdout) != entitlements:
        raise ValueError("The archive did not preserve the source entitlements")
    print("Source entitlements embedded; Apple Distribution export is still required.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive")
    parser.add_argument("source")
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()
    prepare(args.archive, args.source, args.team_id, args.bundle_id)
