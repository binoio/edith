# Edith - Iteration Notes

## Current State: v1.7 Syntax Highlighting ✓

Build and all tests verified. On feature/syntax-highlighting branch.

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
- **Status Bar** with line/column, counts, encoding, line ending, **syntax language picker**
- **Syntax Highlighting** via HighlightSwift:
  - Auto-detects from file extension on open
  - Supports: HTML, CSS, Python, JSON, Markdown, JavaScript, Swift, XML, YAML, SQL, Shell
  - Manual override via status bar picker
  - In-place coloring preserves cursor position
  - Plain text files have no highlighting
  - GitHub theme colors (light/dark)
- Document type registration for all supported file types

## Next Steps
1. Merge feature/syntax-highlighting to main when ready
2. Consider adding more syntax languages (Ruby, Go, Rust, C/C++, Java)
3. Consider adding syntax theme selection in Settings

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
