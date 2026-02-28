# Edith - Iteration Notes

## Current State: v1.3 Session Restore & General Settings ✓

Build and tests verified.

## What's Done
- File > New Text Document (⌘N)
- Settings window (⌘,) with four tabs: General, Text Encodings, Appearance, Editor Defaults
- General settings: Re-open documents, Restore unsaved changes, Refresh documents changed on disk
- Restore Defaults button in settings
- Line number gutter with proper alignment and styling
- View > Show/Hide Line Numbers toggle (⇧⌘L)
- View > Zoom In (⌘=), Zoom Out (⌘-), Actual Size (⌘0)
- Format > Font > Bigger (⇧⌘+), Smaller (⌥⌘-)
- Custom invisible character rendering (·↵△° etc.)
- File change detection with reload/ignore banner
- Help window (⌘?)
- Session restore on launch (re-opens previously open documents)
- 159 unit tests + 26 UI tests

## Tests
Run `./scripts/test.sh` to verify all functionality.
UI tests cover zoom menu states and keyboard shortcuts.

## Recent Changes
- Fixed session restore by reading UserDefaults directly in AppDelegate
- Added SessionRestoreTests with 13 tests

## Next Steps
1. Verify session restore works end-to-end (manual test)
2. Add Help content for new features
3. Consider adding unsaved content backup restoration

## Tech Stack
- SwiftUI + NSTextView wrapper, @AppStorage, DocumentGroup
- Target: macOS 13.0+

## Scripts
- `./scripts/build.sh [Debug|Release]` - Build the app
- `./scripts/run.sh` - Build and launch
- `./scripts/test.sh` - Run all tests
- `./scripts/notarize.sh` - Sign and notarize for distribution
