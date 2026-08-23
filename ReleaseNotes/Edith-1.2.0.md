## Edith 1.2.0

### Automatic updates
- Edith now updates itself via Sparkle. Check manually with **Edith ▸ Check for Updates…**, or manage automatic checks and downloads in **Settings ▸ Updates**.

### Quit & Resume
- Quitting no longer interrupts you with save dialogs: open documents — including untitled ones and unsaved changes — are backed up and restored exactly as you left them on the next launch ("hot exit"). Turn this off with **Settings ▸ General ▸ Re-open documents from last session**; with restore disabled, the standard review-changes dialog returns.
- Reopening files across launches now works reliably in the sandbox via security-scoped bookmarks.
- The session is saved continuously while you work, so documents also come back after a crash.
- The stray empty window that could appear next to restored documents is gone.

### Under the hood
- Replaced the ship-it submodule with self-contained build, test, run, and release scripts (`Scripts/`).
