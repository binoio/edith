# Edith - Iteration Notes

## Current State: v1.8 Find & Replace (in progress)

On `search-and-process` branch. Feature is implemented with full test coverage.

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
- Session restore on launch
- **Status Bar** with line/column, counts, encoding, line ending, syntax language picker
- **Syntax Highlighting** via HighlightSwift
- Document type registration for all supported file types
- **Find & Replace** (Search menu):
  - Search menu with Find & Replace (⌘F), Find Next (⌘G), Find Previous (⇧⌘G)
  - Find & Replace window with Find/Replace text fields
  - Options: Case Sensitive, PCRE syntax (regex)
  - Search scope: Selected Text Only, Wrap Around
  - Actions: Find Next, Find Previous, Find All, Extract All, Replace Next, Replace All

## Next Steps
1. Manual testing of Find & Replace feature
2. Merge search-and-process to main when confirmed working
3. Consider adding more syntax languages (Ruby, Go, Rust, C/C++, Java)
4. Consider adding syntax theme selection in Settings

## Tests
Run `./scripts/test.sh` to verify all functionality.

## Tech Stack
- SwiftUI + NSTextView wrapper, @AppStorage, DocumentGroup
- HighlightSwift for syntax highlighting
- Target: macOS 13.0+

## Scripts
- `./scripts/build.sh [Debug|Release]` - Build the app
- `./scripts/run.sh` - Build and launch
- `./scripts/test.sh` - Run all tests
- `./scripts/notarize.sh` - Sign and notarize for distribution
