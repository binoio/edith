//
//  FindReplaceState.swift
//  Edith
//

import Foundation
import AppKit

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
    @Published var matches: [NSRange] = []
    @Published var currentMatchIndex: Int = -1
    
    // Reference to the text view for operations
    weak var textView: NSTextView?
    
    /// The selected range when search started (for selected text only mode)
    var initialSelectionRange: NSRange?
    
    var totalMatches: Int { matches.count }
    
    var hasMatches: Bool { !matches.isEmpty }
    
    var currentMatch: NSRange? {
        guard currentMatchIndex >= 0 && currentMatchIndex < matches.count else { return nil }
        return matches[currentMatchIndex]
    }
    
    /// Perform search and update matches
    func performSearch() {
        guard let textView = textView, !findText.isEmpty else {
            clearMatchHighlights()
            matches = []
            currentMatchIndex = -1
            return
        }
        
        let text = textView.string
        let searchRange: NSRange?
        
        if selectedTextOnly, let selRange = initialSelectionRange {
            searchRange = selRange
        } else {
            searchRange = nil
        }
        
        matches = SearchEngine.findMatches(
            in: text,
            pattern: findText,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        
        // Reset current match if no matches found
        if matches.isEmpty {
            currentMatchIndex = -1
            clearMatchHighlights()
        } else if currentMatchIndex < 0 {
            // Find the first match after current cursor position
            let cursorPos = textView.selectedRange().location
            currentMatchIndex = matches.firstIndex { $0.location >= cursorPos } ?? 0
        }
        
        highlightCurrentMatch()
    }
    
    /// Find and select the next match
    func findNext() {
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
    
    /// Select and scroll to the current match
    private func highlightCurrentMatch() {
        guard let textView = textView, let match = currentMatch else { return }
        
        // First, clear any previous match highlighting
        clearMatchHighlights()
        
        // Highlight all matches with a subtle background
        highlightAllMatches()
        
        // Select and scroll to current match
        textView.setSelectedRange(match)
        textView.scrollRangeToVisible(match)
    }
    
    /// Highlight all matches with a visible background color
    private func highlightAllMatches() {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }
        
        // Use a high-contrast highlight color
        let matchColor = NSColor.systemYellow.withAlphaComponent(0.4)
        let currentMatchColor = NSColor.systemOrange.withAlphaComponent(0.6)
        
        textStorage.beginEditing()
        
        for (index, match) in matches.enumerated() {
            let color = (index == currentMatchIndex) ? currentMatchColor : matchColor
            textStorage.addAttribute(.backgroundColor, value: color, range: match)
        }
        
        textStorage.endEditing()
    }
    
    /// Clear all match highlighting
    private func clearMatchHighlights() {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.endEditing()
    }
    
    /// Clear highlights when search is cleared
    func clearHighlights() {
        clearMatchHighlights()
    }
    
    /// Replace the current match
    func replaceNext() {
        guard let textView = textView,
              let match = currentMatch else {
            findNext()
            return
        }
        
        // Verify the selection matches what we expect
        guard textView.selectedRange() == match else {
            highlightCurrentMatch()
            return
        }
        
        // For PCRE mode with backreferences, use SearchEngine
        if usePCRE {
            let newText = SearchEngine.replaceMatch(
                in: textView.string,
                at: match,
                with: replaceText,
                pattern: findText,
                usePCRE: true,
                caseSensitive: caseSensitive
            )
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.insertText(newText, replacementRange: fullRange)
        } else {
            // Simple replacement
            textView.insertText(replaceText, replacementRange: match)
        }
        
        // Re-search to update matches after replacement
        performSearch()
        
        // Move to next match
        if hasMatches {
            // The current match was replaced, so the index stays the same
            // but we need to clamp it
            currentMatchIndex = min(currentMatchIndex, matches.count - 1)
            highlightCurrentMatch()
        }
    }
    
    /// Replace all matches
    func replaceAll() {
        guard let textView = textView, hasMatches else { return }
        
        let text = textView.string
        let searchRange: NSRange?
        
        if selectedTextOnly, let selRange = initialSelectionRange {
            searchRange = selRange
        } else {
            searchRange = nil
        }
        
        let newText = SearchEngine.replaceAll(
            in: text,
            pattern: findText,
            replacement: replaceText,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        
        // Replace entire text
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.insertText(newText, replacementRange: fullRange)
        
        // Clear matches
        matches = []
        currentMatchIndex = -1
    }
    
    /// Extract all matches to clipboard
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    /// Highlight all matches (for visual feedback)
    func findAll() {
        performSearch()
        
        guard hasMatches else {
            NSSound.beep()
            return
        }
        
        // Select the first match
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
        initialSelectionRange = nil
    }
}
