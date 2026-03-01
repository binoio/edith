# Edith - Iteration Notes

## Current State: vim-like branch (experimental)

On `vim-like` branch. Experimental vim modal editing feature.

## What's Done
- File > New Text Document (⌘N)
- Settings window (⌘,) with four tabs: General, Text Encodings, Appearance, Editor Defaults
- General settings: Re-open documents, Restore unsaved changes, Refresh documents changed on disk
- Restore Defaults button in settings
- Line number gutter with proper alignment and styling
- **Line selection via gutter** - click/drag line numbers to select lines, Cmd+click for non-contiguous
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
- **Find & Replace** (Search menu) - fully featured with PCRE, document selector, Extract All

## Experimental: Vim-like Mode (this branch)
- **Double-tap Esc** to toggle between insert and normal mode
- **Green glow border** indicates when in normal/command mode
- **Normal mode navigation**: h/j/k/l, w/b/e, 0/$/^, gg/G
- **Insert mode entry**: i/a/I/A/o/O
- **Edit commands**: x (delete char), dd (delete line)
- **Command mode** (via :): w, q, q!, wq, wq!, line numbers
- **Substitution**: :s/pattern/replacement/g and :%s/pattern/replacement/g

## Next Steps
1. Test vim mode thoroughly (navigation, editing, commands)
2. Add more vim commands: y/p yank/paste, visual mode, / search
3. Consider adding Settings option to enable/disable vim mode
4. Merge to main when stable

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
