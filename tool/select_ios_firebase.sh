#!/bin/sh
# Select native credentials explicitly; an unflavored Runner build fails closed.
set -eu
case "$CONFIGURATION" in
  *-development)
    firebase_plist="$SRCROOT/../config/firebase/development/GoogleService-Info.plist"
    firebase_project=cloud-board-development
    firebase_bundle=com.sunmkim.cloudboard.dev
    ;;
  *-production)
    firebase_plist="$SRCROOT/Runner/GoogleService-Info.plist"
    firebase_project=cloud-board-stationd
    firebase_bundle=com.sunmkim.cloudboard
    ;;
  *)
    echo 'error: Select the development or production scheme. Unflavored Runner builds are disabled.' >&2
    exit 1
    ;;
esac
firebase_preview=false
case "${FLUTTER_TARGET:-}" in
  lib/main_studio_preview.dart|*/lib/main_studio_preview.dart)
    if [ "$CONFIGURATION" != Debug-development ]; then
      echo 'error: Studio preview requires the development Debug scheme.' >&2
      exit 1
    fi
    firebase_preview=true
    ;;
esac
if [ "$PRODUCT_BUNDLE_IDENTIFIER" != "$firebase_bundle" ] ||
   [ "$(/usr/libexec/PlistBuddy -c 'Print PROJECT_ID' "$firebase_plist")" != "$firebase_project" ] ||
   [ "$(/usr/libexec/PlistBuddy -c 'Print BUNDLE_ID' "$firebase_plist")" != "$firebase_bundle" ]; then
  echo 'error: Native Firebase configuration does not match the selected environment.' >&2
  exit 1
fi
mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
firebase_output="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
cp "$firebase_plist" "$firebase_output"
if [ "$firebase_preview" = true ]; then
  # Only mutate the built app; keep development and production source configs
  # intact while matching the preview's demo Firebase options and namespace.
  /usr/libexec/PlistBuddy -c 'Set PROJECT_ID demo-cloudboard-studio' "$firebase_output"
  /usr/libexec/PlistBuddy -c 'Set STORAGE_BUCKET demo-cloudboard-studio.appspot.com' "$firebase_output"
  /usr/libexec/PlistBuddy -c 'Set DATABASE_URL https://demo-cloudboard-studio-default-rtdb.asia-southeast1.firebasedatabase.app' "$firebase_output"
fi
