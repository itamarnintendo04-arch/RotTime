#!/usr/bin/env bash
# Imports the signing certificate and the five provisioning profiles from GitHub Secrets,
# checks that every profile really grants what RotTime needs, and writes
# build/signing.env (xcodebuild settings) + build/ExportOptions.plist.
#
# Required env: BUILD_CERTIFICATE_BASE64, P12_PASSWORD, APPLE_TEAM_ID, RT_BUNDLE_ID, RT_APP_GROUP,
#               PROVISIONING_PROFILE_{APP,MONITOR,SHIELD_CONFIG,SHIELD_ACTION,REPORT}_BASE64
# Optional env: KEYCHAIN_PASSWORD, EXPORT_METHOD (development | ad-hoc | app-store-connect | release-testing)
set -euo pipefail

: "${BUILD_CERTIFICATE_BASE64:?}" "${P12_PASSWORD:?}" "${APPLE_TEAM_ID:?}" "${RT_BUNDLE_ID:?}" "${RT_APP_GROUP:?}"
EXPORT_METHOD="${EXPORT_METHOD:-development}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(uuidgen)}"
WORK="${RUNNER_TEMP:-/tmp}/rottime-signing"
mkdir -p "$WORK" build
KEYCHAIN="$WORK/rottime.keychain-db"

echo "::group::Import certificate"
echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$WORK/cert.p12"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/cert.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -F'"' '/"/{print $2; exit}')
if [[ -z "$IDENTITY" ]]; then
  echo "::error::No valid code-signing identity found in BUILD_CERTIFICATE_BASE64 (is the .p12 exported with its private key?)."
  exit 1
fi
echo "Signing identity: $IDENTITY"
echo "::endgroup::"

PROFILE_DIRS=("$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles")
for d in "${PROFILE_DIRS[@]}"; do mkdir -p "$d"; done

FAIL=0
declare -A PROFILE_NAMES
install_profile() {
  local var="$1" suffix="$2" setting="$3"
  local b64="${!var:-}"
  local bundle="$RT_BUNDLE_ID$suffix"
  if [[ -z "$b64" ]]; then
    echo "::error::Secret $var is missing (profile for $bundle)."; FAIL=1; return
  fi
  local file="$WORK/$var.mobileprovision" plist="$WORK/$var.plist"
  echo -n "$b64" | base64 --decode > "$file"
  security cms -D -i "$file" > "$plist"
  local name uuid appid fc groups
  name=$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist")
  uuid=$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist")
  appid=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$plist")
  fc=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.family-controls' "$plist" 2>/dev/null || echo missing)
  groups=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' "$plist" 2>/dev/null || echo missing)
  echo "Profile '$name' ($uuid) → $appid"
  [[ "$appid" == "$APPLE_TEAM_ID.$bundle" ]] || { echo "::error::$var is for '$appid' but RotTime needs '$APPLE_TEAM_ID.$bundle'."; FAIL=1; }
  [[ "$fc" == "true" ]] || { echo "::error::$var does not include the Family Controls entitlement. Enable the 'Family Controls (Development)' capability on the App ID (or request distribution approval from Apple) and regenerate the profile."; FAIL=1; }
  [[ "$groups" == *"$RT_APP_GROUP"* ]] || { echo "::error::$var does not include App Group '$RT_APP_GROUP'."; FAIL=1; }
  for d in "${PROFILE_DIRS[@]}"; do cp "$file" "$d/$uuid.mobileprovision"; done
  PROFILE_NAMES[$bundle]="$name"
  echo "$setting=$name" >> build/signing.env.tmp
}

echo "::group::Install provisioning profiles"
rm -f build/signing.env.tmp
install_profile PROVISIONING_PROFILE_APP_BASE64 "" RT_PROFILE_APP
install_profile PROVISIONING_PROFILE_MONITOR_BASE64 ".monitor" RT_PROFILE_MONITOR
install_profile PROVISIONING_PROFILE_SHIELD_CONFIG_BASE64 ".shieldconfig" RT_PROFILE_SHIELD_CONFIG
install_profile PROVISIONING_PROFILE_SHIELD_ACTION_BASE64 ".shieldaction" RT_PROFILE_SHIELD_ACTION
install_profile PROVISIONING_PROFILE_REPORT_BASE64 ".report" RT_PROFILE_REPORT
echo "::endgroup::"

if [[ $FAIL -ne 0 ]]; then
  echo "::error::Signing setup is incomplete – no signed IPA will be produced. See docs/SIGNING.md."
  exit 1
fi

{
  echo "CODE_SIGN_IDENTITY=$IDENTITY"
  echo "KEYCHAIN_PATH=$KEYCHAIN"
  cat build/signing.env.tmp
} > build/signing.env
rm -f build/signing.env.tmp

# ExportOptions.plist
{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$EXPORT_METHOD</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$IDENTITY</string>
  <key>stripSwiftSymbols</key><true/>
  <key>provisioningProfiles</key>
  <dict>
EOF
  for bundle in "${!PROFILE_NAMES[@]}"; do
    printf '    <key>%s</key><string>%s</string>\n' "$bundle" "${PROFILE_NAMES[$bundle]}"
  done
  cat <<EOF
  </dict>
</dict>
</plist>
EOF
} > build/ExportOptions.plist
plutil -lint build/ExportOptions.plist
echo "Signing configured (export method: $EXPORT_METHOD)."
