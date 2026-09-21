//
//  SearchEngine.swift
//  Edith
//

import Foundation

/// Search engine for Find & Replace functionality
/// Supports plain text and PCRE regex matching
struct SearchEngine {
    
    /// Find all matches of a pattern in text
    /// - Parameters:
    ///   - text: The text to search in
    ///   - pattern: The search pattern
    ///   - caseSensitive: Whether the search is case sensitive
    ///   - usePCRE: Whether to interpret pattern as PCRE regex
    ///   - searchRange: Optional range to limit search (for selected text only)
    /// - Returns: Array of matching ranges
    static func findMatches(
        in text: String,
        pattern: String,
        caseSensitive: Bool = false,
        usePCRE: Bool = false,
        searchRange: NSRange? = nil
    ) -> [NSRange] {
        guard !pattern.isEmpty else { return [] }
        
        let nsText = text as NSString
        let requested = searchRange ?? NSRange(location: 0, length: nsText.length)
        
        // A range captured before an edit can outlive the text it described;
        // clamp rather than letting Foundation raise
        guard let fullRange = clamp(requested, to: nsText.length) else { return [] }
        
        if usePCRE {
            return findRegexMatches(in: nsText, pattern: pattern, caseSensitive: caseSensitive, range: fullRange)
        } else {
            return findPlainTextMatches(in: nsText, pattern: pattern, caseSensitive: caseSensitive, range: fullRange)
        }
    }
    
    /// Describe why a pattern cannot be used, or nil when it is usable.
    /// Plain-text patterns are always usable; only PCRE can fail to compile.
    static func patternError(for pattern: String, usePCRE: Bool) -> String? {
        guard usePCRE, !pattern.isEmpty else { return nil }
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            return nil
        } catch {
            return (error as NSError).localizedDescription
        }
    }
    
    /// Trim a range to what the text can actually address, or nil if it lies entirely outside
    static func clamp(_ range: NSRange, to length: Int) -> NSRange? {
        guard range.location != NSNotFound, range.location >= 0, range.location <= length else { return nil }
        return NSRange(location: range.location, length: min(range.length, length - range.location))
    }
    
    /// Find matches using plain text search
    private static func findPlainTextMatches(
        in text: NSString,
        pattern: String,
        caseSensitive: Bool,
        range: NSRange
    ) -> [NSRange] {
        var matches: [NSRange] = []
        var searchStart = range.location
        let searchEnd = range.location + range.length
        
        let options: NSString.CompareOptions = caseSensitive ? [] : .caseInsensitive
        
        while searchStart < searchEnd {
            let remainingRange = NSRange(location: searchStart, length: searchEnd - searchStart)
            let foundRange = text.range(of: pattern, options: options, range: remainingRange)
            
            if foundRange.location == NSNotFound {
                break
            }
            
            matches.append(foundRange)
            searchStart = foundRange.location + foundRange.length
        }
        
        return matches
    }
    
    /// Find matches using PCRE regex
    private static func findRegexMatches(
        in text: NSString,
        pattern: String,
        caseSensitive: Bool,
        range: NSRange
    ) -> [NSRange] {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: regexOptions(caseSensitive: caseSensitive))
            let results = regex.matches(in: text as String, options: [], range: range)
            
            // Patterns like `a*` match the empty string at every position. Those
            // ranges highlight nothing and leave Find Next with nowhere to go, so
            // they are not offered as matches.
            return results.map { $0.range }.filter { $0.length > 0 }
        } catch {
            // Invalid regex - patternError(for:usePCRE:) reports the reason
            return []
        }
    }
    
    private static func regexOptions(caseSensitive: Bool) -> NSRegularExpression.Options {
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if !caseSensitive {
            options.insert(.caseInsensitive)
        }
        return options
    }
    
    /// Convert \1, \2, etc. to $1, $2 (NSRegularExpression template format)
    private static func normalizedTemplate(_ replacement: String) -> String {
        replacement.replacingOccurrences(of: "\\\\([0-9]+)", with: "\\$$1", options: .regularExpression)
    }
    
    /// Expand a replacement template against a single match, resolving $1/\1 backreferences.
    /// Returns the literal text that should be substituted for `range`.
    /// - Returns: The expanded replacement, or nil if the pattern does not compile
    static func expandedReplacement(
        for range: NSRange,
        in text: String,
        pattern: String,
        replacement: String,
        caseSensitive: Bool
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions(caseSensitive: caseSensitive)),
              let match = regex.firstMatch(in: text, options: [.anchored], range: range),
              match.range == range else { return nil }
        
        let template = normalizedTemplate(replacement)
        return regex.replacementString(for: match, in: text, offset: 0, template: template)
    }
    
    /// Replace all occurrences of pattern with replacement
    /// - Parameters:
    ///   - text: The original text
    ///   - pattern: The search pattern
    ///   - replacement: The replacement string (supports $1, $2 or \1, \2 for capture groups in PCRE mode)
    ///   - caseSensitive: Whether the search is case sensitive
    ///   - usePCRE: Whether to interpret pattern as PCRE regex
    ///   - searchRange: Optional range to limit replacement
    /// - Returns: The modified text
    static func replaceAll(
        in text: String,
        pattern: String,
        replacement: String,
        caseSensitive: Bool = false,
        usePCRE: Bool = false,
        searchRange: NSRange? = nil
    ) -> String {
        guard !pattern.isEmpty else { return text }
        
        let edits = replacements(
            in: text,
            pattern: pattern,
            replacement: replacement,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        
        guard !edits.isEmpty else { return text }
        
        var result = text as NSString
        
        // Replace in reverse order to preserve indices
        for edit in edits.reversed() {
            result = result.replacingCharacters(in: edit.range, with: edit.text) as NSString
        }
        
        return result as String
    }
    
    /// One concrete substitution: the range to overwrite and the literal text to put there
    struct Replacement {
        let range: NSRange
        let text: String
    }
    
    /// Resolve every match into a literal edit, expanding backreferences in PCRE mode.
    /// Callers apply these in reverse order so earlier ranges stay valid.
    static func replacements(
        in text: String,
        pattern: String,
        replacement: String,
        caseSensitive: Bool = false,
        usePCRE: Bool = false,
        searchRange: NSRange? = nil
    ) -> [Replacement] {
        let matches = findMatches(
            in: text,
            pattern: pattern,
            caseSensitive: caseSensitive,
            usePCRE: usePCRE,
            searchRange: searchRange
        )
        
        return matches.map { match in
            guard usePCRE else { return Replacement(range: match, text: replacement) }
            let expanded = expandedReplacement(
                for: match,
                in: text,
                pattern: pattern,
                replacement: replacement,
                caseSensitive: caseSensitive
            )
            return Replacement(range: match, text: expanded ?? replacement)
        }
    }
    
    /// Replace a single match at the given range
    /// - Parameters:
    ///   - text: The original text
    ///   - range: The range to replace
    ///   - replacement: The replacement string (supports $1, $2 or \1, \2 for capture groups in PCRE mode)
    ///   - pattern: The original search pattern (needed for backreference support)
    ///   - usePCRE: Whether PCRE mode is enabled
    ///   - caseSensitive: Whether the search is case sensitive
    /// - Returns: The modified text
    static func replaceMatch(
        in text: String,
        at range: NSRange,
        with replacement: String,
        pattern: String? = nil,
        usePCRE: Bool = false,
        caseSensitive: Bool = false
    ) -> String {
        let nsText = text as NSString
        guard range.location + range.length <= nsText.length else { return text }
        
        // For PCRE with backreferences, expand the template against this match only
        if usePCRE, let pattern = pattern,
           let expanded = expandedReplacement(
                for: range,
                in: text,
                pattern: pattern,
                replacement: replacement,
                caseSensitive: caseSensitive
           ) {
            return nsText.replacingCharacters(in: range, with: expanded)
        }
        
        return nsText.replacingCharacters(in: range, with: replacement)
    }
    
    /// Extract all matches as an array of strings
    /// - Parameters:
    ///   - text: The text to search in
    ///   - pattern: The search pattern
    ///   - caseSensitive: Whether the search is case sensitive
    ///   - usePCRE: Whether to interpret pattern as PCRE regex
    /// - Returns: Array of matched strings
    static func extractAll(
        from text: String,
        pattern: String,
        caseSensitive: Bool = false,
        usePCRE: Bool = false
    ) -> [String] {
        let matches = findMatches(in: text, pattern: pattern, caseSensitive: caseSensitive, usePCRE: usePCRE)
        let nsText = text as NSString
        
        return matches.map { nsText.substring(with: $0) }
    }
}
