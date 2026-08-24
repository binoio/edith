# Edith

A native macOS text editor built with Swift and SwiftUI.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Core Editing
- **Multi-document support** with tabbed interface
- **Line number gutter** with click-to-select lines (click, drag, Cmd+click for non-contiguous)
- **Syntax highlighting** for 50+ languages via HighlightSwift
- **Find & Replace** with regex/PCRE support, document selector, and Extract All
- **Session restore** - quit and pick up where you left off: open documents (including untitled ones) and unsaved changes come back on the next launch, with no save dialogs blocking quit
- **Automatic updates** via Sparkle (Settings > Updates)
- **File change detection** with reload/ignore banner

### View Options
- Show/Hide Line Numbers (⇧⌘L)
- Show/Hide Status Bar (⇧⌘/)
- Zoom In/Out (⌘+/⌘-)
- Show invisible characters (spaces, tabs, line endings)

### Settings (⌘,)
- **General**: Document restore, file monitoring, vim mode toggle
- **Text Encodings**: Default encoding for new documents (UTF-8 default)
- **Appearance**: System/Light/Dark mode
- **Editor Defaults**: Font, size, line height, tab width, invisible characters

### Experimental: Vim-like Mode
Enable in Settings > General. Double-tap Esc to toggle.

- **Normal mode**: h/j/k/l navigation, w/b/e word movement, gg/G, 0/$
- **Insert mode**: i/a/I/A/o/O
- **Edit commands**: x, dd, d{motion}, number prefixes (3dd, 2dw)
- **Command mode**: :w, :q, :wq, :s/pattern/replacement/g

Visual indicator: green glow border when in normal/command mode.

## Requirements

- macOS 13.0 or later
- Xcode 15+ (for building)

## Building

```bash
# Build debug version
Scripts/build.sh

# Build release version (unsigned)
Scripts/build.sh --release

# Build and run
Scripts/run.sh

# Run unit tests (add --ui for the UI test suite)
Scripts/test.sh
```

## Installation

### From Source
```bash
git clone https://github.com/binoio/edith.git
cd edith
Scripts/build.sh --release
# App is at build/DerivedData/Build/Products/Release/Edith.app
```

### Releasing (signing, notarization, Sparkle appcast)
```bash
Scripts/release.sh
```
Builds, codesigns, notarizes, publishes the GitHub release, and updates the
Sparkle appcast. Requires an Apple Developer account; see [RELEASE.md](RELEASE.md).

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| New Document | ⌘N |
| Open | ⌘O |
| Save | ⌘S |
| Close | ⌘W |
| Settings | ⌘, |
| Find & Replace | ⌘F |
| Show/Hide Line Numbers | ⇧⌘L |
| Show/Hide Status Bar | ⇧⌘/ |
| Zoom In | ⌘= |
| Zoom Out | ⌘- |
| Actual Size | ⌘0 |
| Help | ⌘? |

## License

MIT License © 2026 Michael Bino

See [LICENSE](LICENSE) for details.
