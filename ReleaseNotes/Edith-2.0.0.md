## Edith 2.0.0

### Requires macOS 15.0 or later
- Edith now requires macOS 15.0 (Sequoia) or later. Macs running macOS 14 or earlier stay on Edith 1.4.1 and will not be offered this update.

### Find & Replace is now a floating panel
- Find & Replace floats above the document instead of taking over as the active window, so the editor stays visible and usable behind it.
- Compact single-line Find and Replace fields replace the oversized text boxes, with working placeholder text.
- Inline previous/next/find-all controls sit beside the Find field; Return finds the next match and Shift+Return the previous.
- Options are a single row of labelled checkboxes (Aa, .\*, Sel, Wrap) with tooltips, and the match count no longer shifts the layout as you type.
- Actions are disabled when there is nothing to act on, and the document picker is hidden unless more than one document is open.

### Fixed: incorrect match count and stale highlighting
- Narrowing a search no longer reports an impossible count such as "8 of 7". The current match is re-anchored every time the match set changes.
- Highlights from a previous, wider search no longer linger. Searching for "Cloud" highlights the seven whole words rather than leaving every letter "c" highlighted.
- An invalid regular expression is now reported as "Invalid pattern" rather than silently finding nothing.
- Patterns that can match the empty string, such as `x*`, no longer produce matches that highlight nothing and stall Find Next.

### Fixed: stray line number in the gutter
- Starting a search could print an extra line number partway down the gutter, out of sequence with the lines around it. The trailing line number is now drawn only when the end of the document is actually on screen.
- Wrapped paragraphs no longer duplicate or skip line numbers.
- Clicking a line number in the gutter now selects the line it sits on; previously a click could select the line above.

### Editing and performance
- Replace and Replace All now edit only the matched ranges instead of rewriting the whole document, preserving the cursor, the scroll position, and single-step undo.
- Find highlighting is drawn as a display-only overlay, so it no longer marks the document as edited or interferes with syntax highlighting.
- Incremental search is debounced and the gutter keeps a cached line index, keeping large documents responsive while typing a search.
