# Signing & installing RotTime (no Mac required)

Every push runs **iOS Build** on a GitHub-hosted macOS runner. Without secrets it builds the
app and all four extensions **unsigned**, runs the unit tests and uploads
`RotTime-unsigned-ipa`. With the secrets below it also archives and exports a **signed IPA**.

> ⚠️ RotTime's blocking only works with the **Family Controls** entitlement
> (`com.apple.developer.family-controls`). Apple grants it like this:
>
> | Use | What you need |
> |-----|---------------|
> | Installing on your own devices (development / ad-hoc) | A **paid** Apple Developer Program account. Enable *Family Controls (Development)* on each App ID. |
> | TestFlight / App Store | Apple's separate **distribution approval** — request it at <https://developer.apple.com/contact/request/family-controls-distribution>. Without it, distribution profiles can't include the entitlement. |
>
> Free Apple accounts (e.g. sideloading with a personal team) **cannot** get this entitlement, so
> the shields would not work in such a build. The CI checks each profile and fails with a clear
> error instead of producing an IPA that silently can't block.

## 1. Choose your identifiers

Pick a reverse-DNS id you own, e.g. `com.yourname.rottime`. RotTime uses five bundle ids and one App Group:

| Target | Bundle ID |
|--------|-----------|
| App | `com.yourname.rottime` |
| DeviceActivityMonitor extension | `com.yourname.rottime.monitor` |
| ShieldConfiguration extension | `com.yourname.rottime.shieldconfig` |
| ShieldAction extension | `com.yourname.rottime.shieldaction` |
| DeviceActivityReport extension | `com.yourname.rottime.report` |
| App Group (all five) | `group.com.yourname.rottime` |

Set them as **repository variables** (Settings → Secrets and variables → Actions → *Variables*):

| Variable | Example |
|----------|---------|
| `RT_BUNDLE_ID` | `com.yourname.rottime` |
| `RT_APP_GROUP` | `group.com.yourname.rottime` |
| `EXPORT_METHOD` (optional) | `development` (default), `ad-hoc`, `release-testing`, `app-store-connect` |

## 2. Apple Developer portal (works from any browser)

1. **Identifiers → App Groups**: create `group.com.yourname.rottime`.
2. **Identifiers → App IDs**: create the five App IDs above. On *each* one enable:
   - **App Groups** → select your group
   - **Family Controls (Development)** (or the distribution variant once Apple approves you)
3. **Certificates**: create an *Apple Development* (or *Apple Distribution*) certificate.
   Without a Mac, generate the CSR with OpenSSL:
   ```bash
   openssl req -new -newkey rsa:2048 -nodes -keyout rottime.key -out rottime.csr \
     -subj "/emailAddress=you@example.com/CN=Your Name/C=US"
   # upload rottime.csr, download the .cer, then:
   openssl x509 -inform DER -in development.cer -out cert.pem
   openssl pkcs12 -export -legacy -inkey rottime.key -in cert.pem -out cert.p12 -passout pass:YOURPASSWORD
   ```
   (Drop `-legacy` on OpenSSL 1.x.)
4. **Devices**: register your iPhone's UDID (needed for development/ad-hoc).
5. **Profiles**: create one profile **per App ID** (five total) of the matching type
   (iOS App Development or Ad Hoc), selecting the certificate and device.

## 3. Repository secrets

Settings → Secrets and variables → Actions → *Secrets*:

| Secret | Value |
|--------|-------|
| `APPLE_TEAM_ID` | 10-character Team ID (Membership page) |
| `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12` |
| `P12_PASSWORD` | password used when exporting the .p12 |
| `KEYCHAIN_PASSWORD` | any random string (optional) |
| `PROVISIONING_PROFILE_APP_BASE64` | `base64 -i RotTime.mobileprovision` |
| `PROVISIONING_PROFILE_MONITOR_BASE64` | profile for `.monitor` |
| `PROVISIONING_PROFILE_SHIELD_CONFIG_BASE64` | profile for `.shieldconfig` |
| `PROVISIONING_PROFILE_SHIELD_ACTION_BASE64` | profile for `.shieldaction` |
| `PROVISIONING_PROFILE_REPORT_BASE64` | profile for `.report` |

On Linux/Windows use `base64 -w0 file` (GNU) to avoid line breaks.

## 4. Run it

Push a commit, or run the workflow manually (Actions → iOS Build → *Run workflow*, choose an
export method). The job:

1. Generates the Xcode project with XcodeGen.
2. Validates bundle ids, plists, entitlements and extension point identifiers.
3. Builds the app + 4 extensions for device (unsigned) and checks they are embedded.
4. Runs unit tests on an iOS simulator.
5. With secrets: imports the certificate, **verifies each profile's bundle id, Family Controls
   entitlement and App Group**, archives with manual signing, exports the IPA and prints its
   signed entitlements.
6. Uploads `RotTime-signed-ipa`, `RotTime-unsigned-ipa` and `build-logs`.

Install the development/ad-hoc IPA with Apple Configurator, Xcode on a friend's Mac, or a
service that installs already-signed IPAs. For TestFlight, use `app-store-connect` and upload the
IPA with Transporter (requires the distribution entitlement approval).

## Troubleshooting

| Error | Fix |
|-------|-----|
| `does not include the Family Controls entitlement` | Enable Family Controls on that App ID, then **regenerate** the profile. |
| `is for 'X' but RotTime needs 'Y'` | The profile's App ID doesn't match `RT_BUNDLE_ID` + suffix. |
| `does not include App Group` | Add the group to that App ID and regenerate the profile. |
| `No valid code-signing identity` | The .p12 must contain the private key. Re-export it. |
| Shields never appear on device | Make sure Screen Time is on, you tapped *Allow* in RotTime, and the device isn't managed by another Screen Time parent account. |
