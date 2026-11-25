#!/usr/bin/env bash
# Validates plists, entitlements, extension points and bundle identifiers.
# Usage: scripts/ci/validate_project.sh <RT_BUNDLE_ID> <RT_APP_GROUP>
set -euo pipefail

BUNDLE_ID="${1:?bundle id required}"
APP_GROUP="${2:?app group required}"
FAIL=0

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  ✅ %s\n' "$*"; }
bad()  { printf '  ❌ %s\n' "$*"; FAIL=1; }

echo "::group::Plist & entitlement syntax"
while IFS= read -r f; do
  if plutil -lint "$f" >/dev/null; then ok "$f"; else bad "$f is not a valid plist"; fi
done < <(find RotTime Extensions -name '*.plist' -o -name '*.entitlements' | sort)
echo "::endgroup::"

echo "::group::Bundle identifiers"
[[ "$BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] && ok "App bundle id '$BUNDLE_ID' is well-formed" || bad "App bundle id '$BUNDLE_ID' contains invalid characters"
[[ "$APP_GROUP" == group.* ]] && ok "App Group '$APP_GROUP' starts with 'group.'" || bad "App Group '$APP_GROUP' must start with 'group.'"

# Ask Xcode what each target will actually be built with.
declare -A EXPECT=(
  [RotTime]="$BUNDLE_ID"
  [RotTimeMonitor]="$BUNDLE_ID.monitor"
  [RotTimeShieldConfiguration]="$BUNDLE_ID.shieldconfig"
  [RotTimeShieldAction]="$BUNDLE_ID.shieldaction"
  [RotTimeReport]="$BUNDLE_ID.report"
)
for target in "${!EXPECT[@]}"; do
  actual=$(xcodebuild -project RotTime.xcodeproj -target "$target" -showBuildSettings \
             RT_BUNDLE_ID="$BUNDLE_ID" RT_APP_GROUP="$APP_GROUP" 2>/dev/null \
           | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER = /{print $2; exit}')
  if [[ "$actual" == "${EXPECT[$target]}" ]]; then
    ok "$target → $actual"
  else
    bad "$target resolved to '$actual', expected '${EXPECT[$target]}'"
  fi
  if [[ "$target" != "RotTime" && "$actual" != "$BUNDLE_ID".* ]]; then
    bad "$target id must be prefixed by the app id ($BUNDLE_ID.)"
  fi
done
echo "::endgroup::"

echo "::group::Entitlements"
for f in RotTime/RotTime.entitlements Extensions/*/*.entitlements; do
  fc=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.family-controls' "$f" 2>/dev/null || echo missing)
  grp=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$f" 2>/dev/null || echo missing)
  [[ "$fc" == "true" ]] && ok "$f has com.apple.developer.family-controls" || bad "$f is missing com.apple.developer.family-controls"
  [[ "$grp" == '$(RT_APP_GROUP)' ]] && ok "$f uses \$(RT_APP_GROUP)" || bad "$f app group is '$grp' (expected \$(RT_APP_GROUP))"
done
echo "::endgroup::"

echo "::group::Extension points"
check_point() {
  local plist="$1" expected="$2" key="$3"
  local actual
  actual=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || echo missing)
  [[ "$actual" == "$expected" ]] && ok "$plist → $expected" || bad "$plist has '$actual', expected '$expected'"
}
check_point Extensions/DeviceActivityMonitor/Info.plist com.apple.deviceactivity.monitor-extension NSExtension:NSExtensionPointIdentifier
check_point Extensions/ShieldConfiguration/Info.plist com.apple.ManagedSettingsUI.shield-configuration-service NSExtension:NSExtensionPointIdentifier
check_point Extensions/ShieldAction/Info.plist com.apple.ManagedSettings.shield-action-service NSExtension:NSExtensionPointIdentifier
check_point Extensions/ActivityReport/Info.plist com.apple.deviceactivityui.report-extension EXAppExtensionAttributes:EXExtensionPointIdentifier
echo "::endgroup::"

if [[ $FAIL -ne 0 ]]; then
  echo "::error::Project validation failed – see the ❌ lines above."
  exit 1
fi
echo "Project validation passed."
