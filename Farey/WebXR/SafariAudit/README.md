# Mobile Safari package check

This small iOS XCTest host exercises **Mobile Safari**, not a WKWebView substitute. Use only a temporary iPhone simulator: the tests restart Safari in their target. They do not touch the native Vision Pro project, install signing assets or request XR access.

With the package built and its loopback server running on port 8765:

```sh
# In WebXR:
npm run build
python3 serve.py --port 8765 --directory dist

# In a second terminal, in WebXR/SafariAudit:
xcodegen generate
xcodebuild -project FareySafariAudit.xcodeproj -scheme SafariAuditHost \
  -destination 'platform=iOS Simulator,id=YOUR_TEMPORARY_IPHONE_UDID' \
  -derivedDataPath /tmp/farey-safari-audit-build \
  -resultBundlePath /tmp/farey-safari-audit-result.xcresult \
  -parallel-testing-enabled NO -jobs 2 CODE_SIGNING_ALLOWED=NO test
```

Choose an installed iOS runtime with `xcrun simctl list devices available`. The result-bundle path must not already exist. Do not rebuild or replace `dist` while Safari is reading it.

The first test opens a fresh local document, enters 6/10, checks its reduced direction and retained integer point, chooses grid 14, and reloads. The second starts a separate fresh document and checks the 3/5 example, portrait/landscape layout, L, Undo and Reset. It captures screenshots as XCTest attachments.

The field is cleared with ordinary Delete keystrokes and checked before typing. Command-A did not reliably select the field contents in this simulator; one diagnostic run submitted `6/101/1`, which the application correctly rejected. Separating the cases also prevents a focused/magnified document from contaminating the layout test.

Export screenshots after the test finishes:

```sh
xcrun xcresulttool export attachments --path /tmp/farey-safari-audit-result.xcresult \
  --output-path /tmp/farey-safari-audit-shots
```

These are simulator checks. Physical touch, accessibility speech and immersive WebXR remain separate validation steps.
