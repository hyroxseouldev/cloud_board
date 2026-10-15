#!/usr/bin/env python3
"""One-release, owner-authorized promotion of already inspected 1.2.1 files.

This is not a successful Firebase deployment receipt. It cannot select another
commit/run, build an app, change backend state, or upload to a store.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPOSITORY = "hyroxseouldev/cloud_board"
SOURCE_SHA = "5976180f306f561b85bb88ce419070198dfc2669"
PREVIOUS_SHA = "eeb6fcf3a894467bf9ca52b50a15150f34ec18bb"
VERSION = "1.2.1"
PACKAGE = "com.sunmkim.cloudboard"
APPROVAL = ("user explicitly requested mobile uploads before Firebase repair; "
            "backend code/rules unchanged; previous serving revision verified")
BACKEND_PATHS = [
    "functions/src", "functions/tools", "functions/certificates",
    "functions/package.json", "functions/package-lock.json", "functions-legacy",
    "firebase.json", "firebase.legacy-auth.json", "firebase.development.json",
    ".firebaserc", "firestore.rules", "firestore.indexes.json",
    "database.rules.json", "storage.rules",
]
PLATFORMS = {
    "ios": {
        "run": 38671769889, "workflow": ".github/workflows/testflight-main.yml",
        "job": "Build and upload", "suffix": ".ipa",
        "metadata": "ios-release-metadata.json", "platform": "ios",
        "inspection": "Verify actual IPA version, package and native/Dart Firebase binding",
        "upload": "Upload to TestFlight",
        "artifacts": [r"cloudboard-ios-release-([1-9][0-9]*)"],
    },
    "android": {
        "run": 38671773120, "workflow": ".github/workflows/google-play-main.yml",
        "job": "Build and upload to internal testing", "suffix": ".aab",
        "metadata": "android-release-metadata.json", "platform": "android-tv",
        "inspection": "Verify actual AAB version, package and native/Dart Firebase binding",
        "upload": "Upload mobile and TV bundle to internal testing",
        "artifacts": [r"cloudboard-internal-aab-([1-9][0-9]*)",
                      r"cloudboard-android-release-evidence-([1-9][0-9]*)"],
    },
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None


class GitHub:
    def __init__(self, token):
        require(bool(token), "GITHUB_TOKEN is required")
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect)

    def request(self, path):
        require(path.startswith("/") and not path.startswith("//"), "Invalid API path")
        return urllib.request.Request(
            "https://api.github.com" + path,
            headers={"Authorization": "Bearer " + self.token,
                     "Accept": "application/vnd.github+json",
                     "X-GitHub-Api-Version": "2022-11-28"},
        )

    def get(self, path):
        try:
            with self.opener.open(self.request(path), timeout=30) as response:
                data = response.read(10 * 1024 * 1024 + 1)
            require(len(data) <= 10 * 1024 * 1024, "API response too large")
            return json.loads(data)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"GitHub read failed HTTP {error.code}") from None

    def download(self, artifact, destination):
        require(re.fullmatch(r"sha256:[a-f0-9]{64}", artifact.get("digest", "")),
                "Missing artifact digest")
        require(not artifact.get("expired"), "Artifact expired")
        require(isinstance(artifact.get("id"), int) and artifact["id"] > 0,
                "Invalid artifact ID")
        require(0 < artifact.get("size_in_bytes", 0) <= 512 * 1024 * 1024,
                "Artifact size outside allowed range")
        request = self.request(f"/repos/{REPOSITORY}/actions/artifacts/{artifact['id']}/zip")
        try:
            response = self.opener.open(request, timeout=30)
        except urllib.error.HTTPError as error:
            require(error.code in (301, 302, 303, 307, 308),
                    f"Artifact read failed HTTP {error.code}")
            location = error.headers.get("Location", "")
            url = urllib.parse.urlparse(location)
            require(url.scheme == "https" and not url.username and not url.password
                    and url.port in (None, 443)
                    and any((url.hostname or "").endswith(suffix) for suffix in
                            (".blob.core.windows.net", ".actions.githubusercontent.com")),
                    "Unexpected artifact download host")
            # Never forward the GitHub bearer to the artifact storage host.
            response = urllib.request.urlopen(location, timeout=30)
        total, deadline = 0, time.monotonic() + 300
        with response, Path(destination).open("xb") as output:
            os.chmod(destination, 0o600)
            while True:
                require(time.monotonic() < deadline, "Artifact download timed out")
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                require(total <= 512 * 1024 * 1024, "Artifact download too large")
                output.write(chunk)
        require(total == artifact["size_in_bytes"], "Artifact size mismatch")
        require("sha256:" + sha256(destination) == artifact["digest"],
                "Artifact ZIP digest mismatch")


def validate_run(run, spec):
    require(run.get("id") == spec["run"] and run.get("head_sha") == SOURCE_SHA,
            "Build run/source SHA mismatch")
    require(run.get("head_branch") == "main" and run.get("event") == "workflow_dispatch",
            "Build must be the fixed main workflow dispatch")
    require(run.get("path") == spec["workflow"], "Build workflow mismatch")
    require(run.get("head_repository", {}).get("full_name") == REPOSITORY,
            "Build repository mismatch")
    require(isinstance(run.get("run_attempt"), int) and run["run_attempt"] > 0,
            "Missing build attempt")


def validate_jobs(jobs, spec):
    matches = [job for job in jobs if job.get("name") == spec["job"]]
    require(len(matches) == 1 and matches[0].get("conclusion") == "success",
            "Inspected native build job did not pass")
    steps = matches[0].get("steps", [])
    def step(name, conclusion):
        found = [item for item in steps if item.get("name") == name]
        require(len(found) == 1 and found[0].get("conclusion") == conclusion,
                f"Native step must be {conclusion}: {name}")
    step(spec["inspection"], "success")
    step(spec["upload"], "skipped")
    step("Recheck backend before publishing", "skipped")
    if spec["platform"] == "ios":
        step("Inspect exported Apple sign-in permissions", "success")
    gates = [job for job in jobs if job.get("name") == "Wait for verified backend deployment"]
    require(len(gates) == 1 and gates[0].get("conclusion") == "skipped",
            "Source was not a build-only run")


def require_current_main(api):
    require(api.get(f"/repos/{REPOSITORY}/git/ref/heads/main").get("object", {}).get("sha")
            == SOURCE_SHA, "Main advanced; this one-release exception is closed")


def require_backend_parity():
    result = subprocess.run(
        ["git", "diff", "--exit-code", PREVIOUS_SHA, SOURCE_SHA, "--", *BACKEND_PATHS],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    require(result.returncode == 0, "Backend runtime/config/rules differ or source history is unavailable")


def extract_allowed(zip_path, output_dir, allowed_names, extracted):
    with zipfile.ZipFile(zip_path) as archive:
        members = archive.infolist()
        require(len(members) <= 64, "Too many archive members")
        for member in members:
            path = PurePosixPath(member.filename)
            require(member.filename and not path.is_absolute() and ".." not in path.parts
                    and "\\" not in member.filename
                    and not any(ord(char) < 32 for char in member.filename),
                    "Unsafe archive member path")
            kind = stat.S_IFMT(member.external_attr >> 16)
            require(kind in (0, stat.S_IFREG, stat.S_IFDIR), "Non-regular archive member")
            require(not member.flag_bits & 1, "Encrypted archive member")
            if member.is_dir():
                continue
            name = path.name
            require(name in allowed_names and name not in extracted,
                    "Unexpected or duplicate native artifact member")
            limit = 512 * 1024 * 1024 if name.endswith((".ipa", ".aab")) else 1024 * 1024
            require(0 < member.file_size <= limit, "Archive member exceeds size limit")
            target = Path(output_dir) / name
            with archive.open(member) as source, target.open("xb") as output:
                os.chmod(target, 0o600)
                shutil.copyfileobj(source, output, 1024 * 1024)
            require(target.stat().st_size == member.file_size, "Archive member size mismatch")
            extracted[name] = target


def validate_metadata(metadata, spec, build, native_path):
    require(metadata.get("platform") == spec["platform"], "Native platform mismatch")
    require(metadata.get("version") == VERSION and metadata.get("build") == build,
            "Native version/build mismatch")
    require(metadata.get("package") == PACKAGE and metadata.get("firebaseProject") == "cloud-board-stationd"
            and metadata.get("productionBindingVerified") is True,
            "Native production binding was not verified")
    require(metadata.get("artifact") == Path(native_path).name, "Native filename mismatch")
    require(metadata.get("artifactSha256") == sha256(native_path), "Actual native file hash mismatch")


def main(platform):
    require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY, "Uploader repository mismatch")
    uploader_sha = os.environ.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[a-f0-9]{40}", uploader_sha), "Missing uploader workflow SHA")
    require(os.environ.get("GITHUB_ENV"), "GITHUB_ENV is required")
    spec = PLATFORMS[platform]
    api = GitHub(os.environ.get("GITHUB_TOKEN"))
    require_backend_parity()
    deadline = time.monotonic() + 30 * 60
    while True:
        require_current_main(api)
        run = api.get(f"/repos/{REPOSITORY}/actions/runs/{spec['run']}")
        validate_run(run, spec)
        if run.get("status") == "completed":
            require(run.get("conclusion") == "success", "Latest build-only attempt did not succeed")
            break
        require(time.monotonic() < deadline, "Timed out waiting for the inspected native artifact")
        time.sleep(15)
    attempt = run["run_attempt"]
    jobs = api.get(f"/repos/{REPOSITORY}/actions/runs/{spec['run']}/attempts/{attempt}/jobs?per_page=100")
    require(jobs.get("total_count", 0) <= 100, "Unexpected build job pagination")
    validate_jobs(jobs.get("jobs", []), spec)
    artifacts = api.get(f"/repos/{REPOSITORY}/actions/runs/{spec['run']}/artifacts?per_page=100")
    require(artifacts.get("total_count", 0) <= 100, "Unexpected artifact pagination")
    selected, builds = [], []
    for pattern in spec["artifacts"]:
        found = [(artifact, re.fullmatch(pattern, artifact.get("name", "")))
                 for artifact in artifacts.get("artifacts", [])]
        found = [(artifact, match) for artifact, match in found if match and not artifact.get("expired")]
        require(len(found) == 1, "Native artifact missing or ambiguous")
        artifact, match = found[0]
        require(artifact.get("workflow_run", {}).get("head_sha") == SOURCE_SHA,
                "Artifact source mismatch")
        require(artifact.get("created_at", "") >= run.get("run_started_at", "~"),
                "Artifact predates the latest build attempt")
        selected.append(artifact)
        builds.append(match.group(1))
    require(len(set(builds)) == 1, "Native artifacts have different build numbers")
    build = builds[0]
    directory = Path(tempfile.mkdtemp(prefix=f"cloudboard-mobile-first-{platform}-",
                                      dir=os.environ.get("RUNNER_TEMP")))
    extracted = {}
    native_name = "cloud_board.ipa" if platform == "ios" else "app-production-release.aab"
    allowed = {native_name, spec["metadata"]}
    if platform == "android":
        allowed.add("play-build-reservation.json")
    for artifact in selected:
        archive = directory / f"{artifact['id']}.zip"
        api.download(artifact, archive)
        extract_allowed(archive, directory, allowed, extracted)
        archive.unlink()
    require(set(extracted) == allowed, "Required native files are missing")
    metadata = json.loads(extracted[spec["metadata"]].read_text())
    validate_metadata(metadata, spec, build, extracted[native_name])
    if platform == "android":
        reservation = json.loads(extracted["play-build-reservation.json"].read_text())
        require(reservation.get("sourceSha") == SOURCE_SHA and reservation.get("repository") == REPOSITORY
                and str(reservation.get("versionCode")) == build
                and str(reservation.get("githubRunId")) == str(spec["run"])
                and str(reservation.get("githubRunAttempt")) == str(attempt)
                and reservation.get("reservationRef") == f"refs/tags/play-version-code/{build}",
                "Play reservation does not match the inspected artifact/run")
    latest = api.get(f"/repos/{REPOSITORY}/actions/runs/{spec['run']}")
    validate_run(latest, spec)
    require(latest.get("run_attempt") == attempt and latest.get("status") == "completed"
            and latest.get("conclusion") == "success", "Build attempt changed during download")
    require_current_main(api)
    audit = {"format": 1, "decision": "owner-authorized-mobile-first-exception",
             "recordedAt": utc_now(), "approval": APPROVAL,
             "artifactSourceSha": SOURCE_SHA, "uploaderWorkflowSha": uploader_sha,
             "uploaderRunId": os.environ.get("GITHUB_RUN_ID"),
             "uploaderAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
             "version": VERSION, "build": build, "platform": spec["platform"],
             "buildOnlyRunId": spec["run"], "buildOnlyAttempt": attempt,
             "firebaseRepairStatus": "not-completed-by-this-exception",
             "physicalQaPerformed": False,
             "backendParity": {"previousSuccessfulSha": PREVIOUS_SHA, "sourceSha": SOURCE_SHA,
                               "identical": True, "paths": BACKEND_PATHS},
             "previousServingObservation": {
                 "observedAt": "2026-10-15T02:36:34.294Z", "liveRecheckedByThisJob": False,
                 "function": "unpairDisplayConnection", "state": "ACTIVE",
                 "revision": "unpairdisplayconnection-00002-nih", "trafficPercent": 100,
                 "ready": True, "evidence": "read-only Cloud Functions v2 and Cloud Run v2 GET audit"},
             "artifacts": [{"id": a["id"], "name": a["name"], "digest": a["digest"]} for a in selected],
             "nativeArtifactSha256": metadata["artifactSha256"],
             "storeUploadPerformedByThisHelper": False}
    audit_path = directory / "approval.json"
    audit_path.write_text(json.dumps(audit, indent=2) + "\n")
    os.chmod(audit_path, 0o600)
    values = {"NATIVE_ARTIFACT_PATH": extracted[native_name],
              "NATIVE_METADATA_PATH": extracted[spec["metadata"]],
              "NATIVE_BUILD_NUMBER": build, "RELEASE_VERSION_NAME": VERSION,
              "NATIVE_AUDIT_PATH": audit_path, "MOBILE_FIRST_APPROVAL_PATH": audit_path}
    if platform == "android":
        values["PLAY_RESERVATION_PATH"] = extracted["play-build-reservation.json"]
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf8") as output:
        for key, value in values.items():
            require("\n" not in str(value) and "\r" not in str(value), "Invalid environment output")
            output.write(f"{key}={value}\n")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf8") as output:
            output.write(f"Mobile-first owner exception: {platform} {VERSION} ({build}).\n\n"
                         f"{APPROVAL}. Source `{SOURCE_SHA}`; build run `{spec['run']}` attempt `{attempt}`. "
                         "Firebase repair is not marked successful; physical QA was not performed.\n")
    print(f"Verified unchanged {platform} {VERSION} ({build}) artifact for the explicit mobile-first exception.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=PLATFORMS)
    args = parser.parse_args()
    try:
        main(args.platform)
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile) as error:
        # Do not expose request URLs, signed download URLs, bodies or credentials.
        message = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        print(f"Mobile-first artifact verification failed: {message}", file=sys.stderr)
        sys.exit(1)
