# MobileSEO

A Flutter app for auditing individual web pages, organizing client projects, tracking SEO work, and sharing reports. Audit analysis and the saved workspace run on-device.

## App experience

- **Dashboard:** URL validation, cancellable audit stages, early on-page results, independent site-file retries, save recovery, measured and projected scores, prioritized findings, and evidence sheets.
- **Share to MobileSEO (Android):** share a page from Chrome or another app to prepare an audit. Cold-start and warm shares are supported. A single link fills the URL field; multiple links offer a choice. Receiving a share never starts network traffic or cancels an active audit automatically.
- **Guided first audit:** contextual Check → Fix guide → Recheck hints use the existing offline sample and real audit evidence. Only an actual later same-page passing check can complete a verified improvement. Hints can be hidden and restored in Settings.
- **Platform-specific fixes:** bundled WordPress (block editor / Yoast SEO), Shopify and HTML guides for all nine shared findings. The selected platform is remembered. HTML editors preserve drafts while switching guide platforms, and real audits offer a direct published-changes recheck action.
- **Projects:** saved page URLs, editable names, favorites, in-progress fixes, searchable audit history, date/attention filters, and same-page before/after comparisons.
- **Tools:** editable search/social previews, competitor comparison, and a bundled offline sample audit.
- **PageSpeed:** Run PageSpeed opens Google's mobile performance report for the audited URL in the device's default browser, with a copy-link fallback if launching fails.
- **Settings & Help:** system/light/dark appearance, reduced motion, haptics, storage controls, FAQs, SEO glossary, version information, open-source licenses, Privacy Policy, and Terms & Conditions.
- **Client reports:** on-device PDF and UTF-8 CSV exports with project/client names, brand name, notes, workflow status, and optional comparison evidence. PDFs bundle Noto Sans fonts and paginate long notes. CSV exports quote cells and protect against spreadsheet formula prefixes.

Support is available from Settings, Help, and both legal documents: **abiralacharya8@gmail.com**. The email action includes a copy-address fallback.

Horizontal destination and result-tab navigation preserves screen state. Layouts support narrow displays, larger system text, and light/dark themes; reduced motion also respects the operating system's accessibility preference.

A compact **32px MobileSEO logo** stays in screen top bars, including the pinned audit header. Android (including Android 12+), iOS, and web show a centered logo while starting, using light/dark backgrounds that follow the device appearance. The launch screen hands off when Flutter can draw its first frame with the decoded header logo; there is no fixed splash delay.

## Scoring and verification

- The **measured score** is the rounded percentage of six passing core checks: title, meta description, H1, H2, image alt text, and schema presence.
- A **projected score** models selected, failing core checks passing. Extended diagnostics do not add points, and marking work in progress never changes the measured result.
- **Verified** means a previously failing finding passed in a subsequent audit of the same page. Passing findings without earlier failure evidence are labeled **Passed**.
- Historical snapshots are read-only for fix tracking. Edit tasks against the latest audit, publish changes on the website, and re-audit to verify them.
- Page identity ignores URL fragments and normalizes host names and empty root paths. Schemes, non-default ports, paths, and queries remain significant. Different pages cannot be compared as a progress trend.

Results describe the returned HTML and HTTP response. JavaScript-rendered content may be absent. PageSpeed, crawl-file availability, and other extended diagnostics are shown separately from the core score.

## Development

Validated with **Flutter 3.47.9 / Dart 3.13.7**. Install a compatible Flutter SDK and the Android SDK; iOS builds require macOS and Xcode.

```sh
flutter pub get
flutter run
```

No account or API key is required for the core audit. Google PageSpeed Insights is optional and opens on Google's website in the default browser.

### Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Tests cover HTML extraction, URL/share parsing, cold/warm share delivery, guided fixes and rechecks, validation, scoring, projections, verified transitions, storage round trips, serialized mutation races, cancellation/supersession, pending-save recovery, optional network tools, external-browser/share/email calls, license attribution, and narrow-screen workflows with enlarged text in both themes.

Generate report fixtures for independent visual/text inspection:

```sh
flutter test test/services/report_export_test.dart --dart-define=REPORT_TEST_OUTPUT=build/report-inspection
```

The generated PDF/CSV include accented text, lengthy evidence, comparison values, and multi-page notes. Inspection output is ignored under `build/`.

On Windows, some Flutter native-assets hooks fail when the SDK path contains spaces. If a test or build exits with an error such as `'E:\Flutter' is not recognized`, invoke Flutter through a no-space directory junction to the SDK.

### Android builds

```sh
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

If Gradle resolves a junction back to the space-containing SDK path, pass the no-space path explicitly with `-Pflutter.sdk`. A Windows project and Pub cache on different drives can also trigger Kotlin incremental-cache errors; `-Pkotlin.incremental=false` works around that build-tool issue. Direct Gradle builds also need `-Ptree-shake-icons=true` to match Flutter's release icon-font shrinking. For example, from `android/` with your own SDK path:

```powershell
.\gradlew.bat assembleRelease bundleRelease "-Pflutter.sdk=C:/dev/flutter" "-Pkotlin.incremental=false" "-Ptree-shake-icons=true"
```

The Android application ID is `abiral.mobile.seo`. Release builds load their signing configuration from `key/key.properties` in the project root. This file contains `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; `storeFile` is resolved relative to `android/app/`. The local configuration uses `../../key/mobileseo-release.jks` with alias `key 0`. The entire `key/` folder is excluded from Git, and release builds require the signing properties to be present. Set the release version in `pubspec.yaml`. The launcher artwork is in the platform resource directories; the compact in-app asset is `assets/branding/mobileseo_logo.png`.

Release AABs omit embedded native debug-symbol metadata to reduce the store-upload size. Google Play already excludes this metadata from device APKs. All supported processor architectures, app features, bundled fonts, and standard release shrinking are retained.

To produce a diagnostic build with native symbols, append `-PincludeNativeDebugSymbols=true` to the Gradle command. Save the matching symbols before rebuilding the compact release: APK builds also produce `build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip`, and AAB builds embed them under `BUNDLE-METADATA/com.android.tools.build.debugsymbols/`. The ZIP for a separate Play Console symbol upload should contain the architecture directories at its root. Keep symbols together with their matching release and verify that its native library hashes match; older symbol output directories may contain files from a previous build. Retain the matching native-symbol ZIP, R8 `mapping.txt`, and verification records under `release-diagnostics/<version>/`; this directory is excluded from Git and preserved by `flutter clean`. Build-time comparison archives are kept under `build/release-diagnostics/`.

Validate native share-sheet behavior, email-app launching and clipboard fallback, system insets, back navigation, and enlarged system text on a physical device or emulator before distribution. Unit/widget tests mock platform channels.

### Branding and launch assets

`assets/branding/mobileseo_icon.png` is the original artwork used by reports. Its source encoding is JPEG despite its filename. The separate header and launch assets are actual PNGs with rounded, transparent corners. Regenerate them from the original with Python and Pillow:

```sh
python -m pip install Pillow
python tool/generate_branding.py
```

The generator produces the 32px header's 4x asset, density-specific Android launch images, 1x/2x/3x iOS images, and the web loading image. Android 12+ artwork includes transparent padding within the system icon safe zone. Launch backgrounds are `#F8FAFC` / `#0F172A`, matching the app scaffold colors. Check cold starts in both device appearances on Android and iOS; building and running iOS requires macOS/Xcode.

### Browser preview

```sh
flutter build web --no-web-resources-cdn --no-wasm-dry-run --optimization-level=1
python -m http.server 8000 --directory build/web
```

Open `http://localhost:8000` and choose **Explore sample audit**. The sample requires no website, PageSpeed, favicon, or social-image requests and never enters real projects/history. Its temporary fix selections reset when reloaded.

This preview command uses a faster JavaScript compilation and bundles the renderer locally. Use the default optimization level when preparing a web deployment.

Browser CORS restrictions can prevent direct audits of other websites. Android/iOS are the primary targets for live audits; the web build is useful for interface and offline-sample review.

## Data and request lifecycle

- The workspace stores up to **100 audit snapshots**, projects, task selections, and settings in local shared preferences. Existing v1 storage keys are retained. Malformed saved rows are skipped; unavailable storage presents recovery actions.
- Workspace loads and mutations are serialized so a stale load or concurrent edit cannot silently replace newer state.
- Accepted on-page results save immediately. Site-file results attach to that same snapshot. An attachment never recreates a deleted audit.
- Each audit owns its HTTP clients and generation. Cancelled or superseded network responses are ignored; accepted results finish saving independently of navigation or cancellation.
- Optional link scanning checks up to **25 unique URLs**, with at most **3 concurrent requests**, HEAD-to-GET fallback, timeouts, and cancellation. Unavailable responses are distinguished from confirmed HTTP errors.
- Run PageSpeed opens `https://pagespeed.web.dev/analysis` with the audited URL and mobile form factor in the default browser. The app does not fetch or cache new PageSpeed API results. Settings can clear reports saved by earlier in-app checks.
- PDF/CSV generation uses the shared finding/comparison model. Sharing sends the report to the receiving app selected by the user.

## Code layout

- `lib/main.dart` — app initialization, settings scope, themes, and accessibility preferences.
- `lib/controllers/` — audit request/persistence ownership and serialized workspace operations.
- `lib/screens/` — four destinations, comparison, previews, legal documents, and help.
- `lib/services/` — HTML analysis, diagnostics, PageSpeed, persistence, sample data, and report generation.
- `lib/utils/` — URL validation, normalized page identity, and date formatting.
- `lib/widgets/` — shared surfaces, responsive audit cards, task workflow, editors, and export/support sheets.
- `test/support/` — injectable in-memory storage, deterministic HTTP clients, and app-workflow helpers.
- `assets/fonts/` — bundled report fonts and the SIL Open Font License.
- `tool/generate_branding.py` — regenerates header and launch PNGs from the original logo.

Search Console integration, scheduled audits, and sitemap/multi-page crawling are future extensions. The current workflow is an on-demand, single-page audit workspace.

### Browser sharing and fix guidance

Android handles `ACTION_SEND` for `text/plain` and `text/uri-list` in a `singleTask` `MainActivity`, so warm shares reach the existing Flutter workspace. A small native inbox is drained through `mobile_seo/incoming_share`. Shares received before Flutter starts are retained; notifications received during a drain trigger another pass. Activity recreation restores only unconsumed shares. The URL parser preserves queries, fragments and ports, and handles browser titles and multiple distinct URLs. Returning from a share prepares the Dashboard without dismissing an open editor or report sheet.

Fix guides are bundled in `lib/services/fix_guides.dart` and presented consistently from recommendations, checklist evidence and the corresponding audit cards. They explain changes in the website's editor; MobileSEO does not request CMS credentials or publish changes. The WordPress instructions use the block editor and Yoast SEO where applicable; Shopify metadata instructions follow its admin SEO fields. Menu labels can vary by installed version and theme.

Guide references: [WordPress headings](https://wordpress.org/documentation/article/heading-block/), [WordPress images](https://wordpress.org/documentation/article/image-block/), [Shopify SEO fields](https://help.shopify.com/en/manual/promoting-marketing/seo/adding-keywords), and [Shopify theme SEO](https://shopify.dev/docs/storefronts/themes/seo). These are documentation references, not requests made while exploring the bundled guides.
