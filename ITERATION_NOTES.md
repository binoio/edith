# Edith - Iteration Notes

## Current State: v1.5 Status Bar ✓

Build and all tests verified.

## What's Done
- File > New Text Document (⌘N)
- Settings window (⌘,) with four tabs: General, Text Encodings, Appearance, Editor Defaults
- General settings: Re-open documents, Restore unsaved changes, Refresh documents changed on disk
- Restore Defaults button in settings
- Line number gutter with proper alignment and styling
- View > Show/Hide Line Numbers toggle (⇧⌘L)
- View > Show/Hide Status Bar toggle (⇧⌘/)
- View > Zoom In (⌘=), Zoom Out (⌘-), Actual Size (⌘0)
- Format > Font > Bigger (⇧⌘+), Smaller (⌥⌘-)
- Custom invisible character rendering (·↵△° etc.)
- File change detection with reload/ignore banner
- Help window (⌘?)
- Session restore on launch (re-opens previously open **saved** documents)
- **Status Bar** with:
  - Line and column display (Ln X, Col Y)
  - Character, word, and line count
  - Text encoding pop-up (UTF-8, UTF-16, ASCII, etc.)
  - Line ending pop-up (LF, CR, CRLF)
- 178 unit tests + 33 UI tests

## Tests
Run `./scripts/test.sh` to verify all functionality.

## Next Steps
1. Consider adding unsaved content backup restoration
2. Improve invisible character styling

## Tech Stack
- SwiftUI + NSTextView wrapper, @AppStorage, DocumentGroup
- Target: macOS 13.0+

## Scripts
- `./scripts/build.sh [Debug|Release]` - Build the app
- `./scripts/run.sh` - Build and launch
- `./scripts/test.sh` - Run all tests
- `./scripts/notarize.sh` - Sign and notarize for distribution
