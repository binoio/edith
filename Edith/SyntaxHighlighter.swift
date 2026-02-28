//
//  SyntaxHighlighter.swift
//  Edith
//

import Foundation
import AppKit
import HighlightSwift

/// Wrapper around HighlightSwift for syntax highlighting
/// Uses in-place attribute application to avoid disrupting text input
@MainActor
class SyntaxHighlighter: ObservableObject {
    private let highlight = Highlight()
    
    @Published var detectedLanguage: String?
    @Published var isHighlighting: Bool = false
    
    private var debounceTask: Task<Void, Never>?
    private let debounceDelay: TimeInterval = 0.5
    
    // Track last highlighted state to avoid redundant work
    private var lastHighlightedText: String = ""
    private var lastHighlightedLanguage: SyntaxLanguage = .auto
    
    /// Highlight text with debouncing for typing performance
    func highlightText(
        _ text: String,
        language: SyntaxLanguage,
        textStorage: NSTextStorage,
        baseFont: NSFont
    ) {
        // Cancel any pending debounce
        debounceTask?.cancel()
        
        // Plain text = clear highlighting
        if language == .plain {
            clearHighlighting(textStorage: textStorage, baseFont: baseFont)
            detectedLanguage = nil
            lastHighlightedText = text
            lastHighlightedLanguage = language
            return
        }
        
        // Start debounce - longer delay for smoother typing
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64((self?.debounceDelay ?? 0.5) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.performHighlighting(text: text, language: language, textStorage: textStorage, baseFont: baseFont)
            } catch {
                // Task was cancelled, ignore
            }
        }
    }
    
    /// Immediate highlighting without debounce (for initial load)
    func highlightImmediately(
        _ text: String,
        language: SyntaxLanguage,
        textStorage: NSTextStorage,
        baseFont: NSFont
    ) async {
        // Plain text = skip highlighting entirely
        if language == .plain {
            clearHighlighting(textStorage: textStorage, baseFont: baseFont)
            detectedLanguage = nil
            lastHighlightedText = text
            lastHighlightedLanguage = language
            return
        }
        await performHighlighting(text: text, language: language, textStorage: textStorage, baseFont: baseFont)
    }
    
    private func performHighlighting(
        text: String,
        language: SyntaxLanguage,
        textStorage: NSTextStorage,
        baseFont: NSFont
    ) async {
        // Plain text should not reach here, but guard anyway
        if language == .plain {
            clearHighlighting(textStorage: textStorage, baseFont: baseFont)
            return
        }
        
        // Skip if nothing changed
        if text == lastHighlightedText && language == lastHighlightedLanguage {
            return
        }
        
        guard !text.isEmpty else {
            clearHighlighting(textStorage: textStorage, baseFont: baseFont)
            return
        }
        
        // Verify text storage still has the same content
        guard textStorage.string == text else {
            return
        }
        
        isHighlighting = true
        defer { isHighlighting = false }
        
        do {
            let result: HighlightResult
            let colors = SyntaxHighlighter.colors(for: NSApp.effectiveAppearance)
            
            if let langId = language.highlightLanguage {
                result = try await highlight.request(text, mode: .languageAlias(langId), colors: colors)
            } else {
                result = try await highlight.request(text, mode: .automatic, colors: colors)
            }
            
            // Update detected language
            detectedLanguage = result.languageName
            
            // Verify content hasn't changed during async highlighting
            guard textStorage.string == text else {
                return
            }
            
            // Apply colors in-place
            applyColorsInPlace(from: result.attributedText, to: textStorage, baseFont: baseFont)
            
            lastHighlightedText = text
            lastHighlightedLanguage = language
            
        } catch {
            // On error, just clear colors
            clearHighlighting(textStorage: textStorage, baseFont: baseFont)
        }
    }
    
    /// Apply color attributes from highlighted text to storage without replacing content
    private func applyColorsInPlace(
        from attributedText: AttributedString,
        to textStorage: NSTextStorage,
        baseFont: NSFont
    ) {
        // Convert AttributedString back to NSAttributedString using AppKit scope
        let nsHighlighted: NSAttributedString
        do {
            nsHighlighted = try NSAttributedString(attributedText, including: \.appKit)
        } catch {
            return
        }
        
        // HighlightSwift trims whitespace, so we need to find where the trimmed text
        // starts and ends in the original text storage
        let highlightedText = nsHighlighted.string
        let storageText = textStorage.string
        
        // Find the range in storage that corresponds to the highlighted text
        let trimmedStorage = storageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If texts don't match after trimming, skip highlighting
        guard trimmedStorage == highlightedText else {
            return
        }
        
        // Calculate leading whitespace offset
        var leadingOffset = 0
        for char in storageText {
            if char.isWhitespace || char.isNewline {
                leadingOffset += 1
            } else {
                break
            }
        }
        
        textStorage.beginEditing()
        
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        // First, reset to default color and ensure font
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        textStorage.addAttribute(.font, value: baseFont, range: fullRange)
        
        // Now apply colors from the highlighted text, adjusting for leading whitespace
        let highlightRange = NSRange(location: 0, length: nsHighlighted.length)
        nsHighlighted.enumerateAttribute(.foregroundColor, in: highlightRange, options: []) { value, range, _ in
            if let nsColor = value as? NSColor {
                // Offset the range by leading whitespace
                let adjustedRange = NSRange(location: range.location + leadingOffset, length: range.length)
                // Ensure we don't go past the text storage bounds
                if adjustedRange.location + adjustedRange.length <= textStorage.length {
                    textStorage.addAttribute(.foregroundColor, value: nsColor, range: adjustedRange)
                }
            }
        }
        
        textStorage.endEditing()
    }
    
    /// Clear all highlighting and apply default styling
    private func clearHighlighting(textStorage: NSTextStorage, baseFont: NSFont) {
        guard textStorage.length > 0 else { return }
        
        textStorage.beginEditing()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: fullRange)
        textStorage.addAttribute(.font, value: baseFont, range: fullRange)
        textStorage.endEditing()
    }
}

// MARK: - Theme Colors for Light/Dark Mode
extension SyntaxHighlighter {
    /// Get appropriate HighlightSwift colors for current appearance
    static func colors(for appearance: NSAppearance?) -> HighlightColors {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark(.github) : .light(.github)
    }
}
