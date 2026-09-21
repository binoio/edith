//
//  FindReplaceState.swift
//  Edith
//

import Foundation
import AppKit

/// Manager for passing extracted content to new documents
@MainActor
final class ExtractedContentManager {
    static let shared = ExtractedContentManager()
    var pendingContent: String?
    private init() {}
}

/// What the find panel should say about the current result set.
/// The view renders only this, so it cannot show an index the match set
/// does not contain.
enum MatchSummary: Equatable {
    case idle
    case invalidPattern(String)
    case noMatches
    case match(index: Int, total: Int)   // index is 1-based, for display
}

/// Observable state for Find & Replace functionality
@MainActor
class FindReplaceState: ObservableObject {
    // Search parameters
    @Published var findText: String = ""
    @Published var replaceText: String = ""
    
    // Options
    @Published var caseSensitive: Bool = false
    @Published var usePCRE: Bool = false
    @Published var selectedTextOnly: Bool = false
    @Published var wrapAround: Bool = true
    
    // Results
    @Published private(set) var matches: [NSRange] = []
    @Published private(set) var currentMatchIndex: Int = -1
    @Published private(set) var patternError: String?
    
    // Reference to the text view for operations
    weak var textView: NSTextView?
    
    /// The selected range when search started (for selected text only mode)
    var initialSelectionRange: NSRange?
    
    /// Set whenever the document is edited behind our back. Match ranges index
    /// into a snapshot of the text; applying them after an edit would address
    /// characters that no longer exist, so they are recomputed before use.
    private var resultsAreStale = true
    
    var totalMatches: Int { matches.count }
    
    var hasMatches: Bool { !matches.isEmpty }
    
    var currentMatch: NSRange? {
        guard currentMatchIndex >= 0 && currentMatchIndex < matches.count else { return nil }
        return matches[currentMatchIndex]
    }
    
    /// The single source of truth for what the panel displays
    var matchSummary: MatchSummary {
        if let patternError { return .invalidPattern(patternError) }
        if findText.isEmpty { return .idle }
        guard !matches.isEmpty else { return .noMatches }
        return .match(index: currentMatchIndex + 1, total: matches.count)
    }
    
    // MARK: - Document change tracking
    
    /// Called when the document text changes outside of find/replace.
    /// Marks the cached ranges unusable without doing the work up front.
    func noteDocumentChanged() {
        resultsAreStale = true
    }
    
    /// Recompute results if the document moved under them
    private func refreshIfStale() {
        if resultsAreStale { performSearch() }
    }
    
    // MARK: - Search
    
    /// Perform search and update matches
    func performSearch() {
        guard let textView = textView, !findText.isEmpty else {
            clearMatchHighlights()
            matches = []
            currentMatchIndex = -1
            patternError = nil
            resultsAreStale = false
            return
        }
        
        patternError = SearchEngine.patternError(for: findText, usePCRE: usePCRE)
        guard patternError == nil else {
            clearMatchHighlights()
            matches = []
            currentMatchIndex = -1
            resultsAreStale = false
            return
        }
        
        let text = textView.string
        let searchRange: NSRange?
        
        if selectedTextOnly, let selRange = initialSelectionRange {
            searchRange = selRange
        } else {
            searchRange = nil
        }
        
        // Where the user's attention is right now: the match they were on if it
        // still exists, otherwise the caret. Captured before `matches` is
        // replaced, because `currentMatch` reads the old set.
        let anchor = currentMatch?.location ?? textView.selectedRange().location
        
        matches = SearchEngine.findMatches(
            in: text,
            pattern: findText,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        resultsAreStale = false
        
        if matches.isEmpty {
            currentMatchIndex = -1
            clearMatchHighlights()
            return
        }
        
        // Re-anchor on every search. Narrowing the pattern shrinks the match
        // set, and an index carried over from the wider set can point past its
        // end -- which is what produced "8 of 7" and left the previous
        // pattern's highlights on screen.
        currentMatchIndex = matches.firstIndex { $0.location >= anchor } ?? 0
        
        highlightCurrentMatch()
    }
    
    /// Find and select the next match
    func findNext() {
        refreshIfStale()
        guard hasMatches else {
            performSearch()
            return
        }
        
        currentMatchIndex += 1
        
        if currentMatchIndex >= matches.count {
            if wrapAround {
                currentMatchIndex = 0
            } else {
                currentMatchIndex = matches.count - 1
                NSSound.beep()
            }
        }
        
        highlightCurrentMatch()
    }
    
    /// Find and select the previous match
    func findPrevious() {
        refreshIfStale()
        guard hasMatches else {
            performSearch()
            return
        }
        
        currentMatchIndex -= 1
        
        if currentMatchIndex < 0 {
            if wrapAround {
                currentMatchIndex = matches.count - 1
            } else {
                currentMatchIndex = 0
                NSSound.beep()
            }
        }
        
        highlightCurrentMatch()
    }
    
    // MARK: - Highlighting
    
    /// Repaint every match and bring the current one into view.
    /// Always repaints, even when there is no valid current match, so stale
    /// highlights from a previous pattern can never survive.
    private func highlightCurrentMatch() {
        clearMatchHighlights()
        highlightAllMatches()
        
        guard let textView = textView,
              let match = currentMatch,
              let valid = validRange(match) else { return }
        
        textView.setSelectedRange(valid)
        textView.scrollRangeToVisible(valid)
    }
    
    /// Backgrounds for matches, as temporary attributes. Light and dark are
    /// spelled out so the text keeps its contrast in both.
    private static let matchHighlightColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.42, green: 0.35, blue: 0.08, alpha: 1.0)
            : NSColor(red: 1.00, green: 0.93, blue: 0.48, alpha: 1.0)
    }
    
    private static let currentMatchHighlightColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.62, green: 0.38, blue: 0.05, alpha: 1.0)
            : NSColor(red: 1.00, green: 0.74, blue: 0.33, alpha: 1.0)
    }
    
    /// Highlight all matches with a visible background color.
    ///
    /// Uses layout-manager temporary attributes rather than writing into the
    /// text storage: they are display-only, so they do not fight the syntax
    /// highlighter for the same attribute, do not mark the document dirty, and
    /// do not invalidate glyph layout on every keystroke.
    private func highlightAllMatches() {
        guard let layoutManager = textView?.layoutManager else { return }
        
        for (index, match) in matches.enumerated() {
            guard let range = validRange(match) else { continue }
            let color = (index == currentMatchIndex) ? Self.currentMatchHighlightColor : Self.matchHighlightColor
            layoutManager.addTemporaryAttributes([.backgroundColor: color], forCharacterRange: range)
        }
    }
    
    /// Clear all match highlighting
    private func clearMatchHighlights() {
        guard let layoutManager = textView?.layoutManager,
              let length = textView?.textStorage?.length else { return }
        
        layoutManager.removeTemporaryAttribute(.backgroundColor,
                                               forCharacterRange: NSRange(location: 0, length: length))
    }
    
    /// Clear highlights when search is cleared
    func clearHighlights() {
        clearMatchHighlights()
    }
    
    /// Trim a cached range to what the document can currently address
    private func validRange(_ range: NSRange) -> NSRange? {
        guard let length = textView?.textStorage?.length,
              let clamped = SearchEngine.clamp(range, to: length),
              clamped.length == range.length else { return nil }
        return clamped
    }
    
    // MARK: - Replace
    
    /// Apply a set of substitutions as one undoable edit.
    ///
    /// Edits run back-to-front so earlier ranges stay valid, and go through
    /// `shouldChangeTextInRanges` / `didChangeText` so undo, the typing
    /// attributes, and the SwiftUI text binding all stay in step. The previous
    /// implementation replaced the entire document with one `insertText`, which
    /// discarded the caret, the scroll position, and undo granularity.
    @discardableResult
    private func applyReplacements(_ edits: [SearchEngine.Replacement]) -> Bool {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return false }
        
        let valid = edits.compactMap { edit -> SearchEngine.Replacement? in
            guard let range = validRange(edit.range) else { return nil }
            return SearchEngine.Replacement(range: range, text: edit.text)
        }
        guard !valid.isEmpty else { return false }
        
        let ranges = valid.map { NSValue(range: $0.range) }
        let strings = valid.map { $0.text }
        guard textView.shouldChangeText(inRanges: ranges, replacementStrings: strings) else { return false }
        
        textStorage.beginEditing()
        for edit in valid.reversed() {
            textStorage.replaceCharacters(in: edit.range, with: edit.text)
        }
        textStorage.endEditing()
        textView.didChangeText()
        
        resultsAreStale = true
        return true
    }
    
    /// Replace the current match
    func replaceNext() {
        refreshIfStale()
        
        guard let textView = textView,
              let match = currentMatch else {
            findNext()
            return
        }
        
        let replacement: String
        if usePCRE {
            replacement = SearchEngine.expandedReplacement(
                for: match,
                in: textView.string,
                pattern: findText,
                replacement: replaceText,
                caseSensitive: caseSensitive
            ) ?? replaceText
        } else {
            replacement = replaceText
        }
        
        let replacedIndex = currentMatchIndex
        guard applyReplacements([SearchEngine.Replacement(range: match, text: replacement)]) else { return }
        
        // Re-search against the edited text, then land on the match that took
        // the replaced one's place (or the last one, if it was the last).
        performSearch()
        
        if hasMatches {
            currentMatchIndex = min(max(replacedIndex, 0), matches.count - 1)
            highlightCurrentMatch()
        }
    }
    
    /// Replace all matches
    func replaceAll() {
        refreshIfStale()
        guard let textView = textView, hasMatches else { return }
        
        let searchRange: NSRange?
        if selectedTextOnly, let selRange = initialSelectionRange {
            searchRange = selRange
        } else {
            searchRange = nil
        }
        
        let edits = SearchEngine.replacements(
            in: textView.string,
            pattern: findText,
            replacement: replaceText,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        
        applyReplacements(edits)
        
        // "Selected text only" was scoped to a range that just changed length
        initialSelectionRange = nil
        selectedTextOnly = false
        
        performSearch()
    }
    
    // MARK: - Other actions
    
    /// Extract all matches to a new document
    func extractAll() {
        guard let textView = textView else { return }
        
        let extracted = SearchEngine.extractAll(
            from: textView.string,
            pattern: findText,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE
        )
        
        guard !extracted.isEmpty else {
            NSSound.beep()
            return
        }
        
        let text = extracted.joined(separator: "\n")
        
        // Store the extracted text for the new document to pick up
        ExtractedContentManager.shared.pendingContent = text
        
        // Create a new document
        NSDocumentController.shared.newDocument(nil)
    }
    
    /// Highlight all matches and jump to the first one
    func findAll() {
        performSearch()
        
        guard hasMatches else {
            NSSound.beep()
            return
        }
        
        currentMatchIndex = 0
        highlightCurrentMatch()
    }
    
    /// Store the current selection for "selected text only" mode
    func captureSelection() {
        guard let textView = textView else { return }
        let selection = textView.selectedRange()
        if selection.length > 0 {
            initialSelectionRange = selection
        } else {
            initialSelectionRange = nil
            selectedTextOnly = false
        }
    }
    
    /// Clear search state
    func clear() {
        clearMatchHighlights()
        findText = ""
        replaceText = ""
        matches = []
        currentMatchIndex = -1
        patternError = nil
        initialSelectionRange = nil
        resultsAreStale = true
    }
}
