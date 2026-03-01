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
        let fullRange = searchRange ?? NSRange(location: 0, length: nsText.length)
        
        if usePCRE {
            return findRegexMatches(in: nsText, pattern: pattern, caseSensitive: caseSensitive, range: fullRange)
        } else {
            return findPlainTextMatches(in: nsText, pattern: pattern, caseSensitive: caseSensitive, range: fullRange)
        }
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
            var options: NSRegularExpression.Options = [.anchorsMatchLines]
            if !caseSensitive {
                options.insert(.caseInsensitive)
            }
            
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let results = regex.matches(in: text as String, options: [], range: range)
            
            return results.map { $0.range }
        } catch {
            // Invalid regex - return empty
            return []
        }
    }
    
    /// Replace all occurrences of pattern with replacement
    /// - Parameters:
    ///   - text: The original text
    ///   - pattern: The search pattern
    ///   - replacement: The replacement string
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
        
        let matches = findMatches(in: text, pattern: pattern, caseSensitive: caseSensitive, usePCRE: usePCRE, searchRange: searchRange)
        
        guard !matches.isEmpty else { return text }
        
        var result = text as NSString
        
        // Replace in reverse order to preserve indices
        for match in matches.reversed() {
            result = result.replacingCharacters(in: match, with: replacement) as NSString
        }
        
        return result as String
    }
    
    /// Replace a single match at the given range
    /// - Parameters:
    ///   - text: The original text
    ///   - range: The range to replace
    ///   - replacement: The replacement string
    /// - Returns: The modified text
    static func replaceMatch(
        in text: String,
        at range: NSRange,
        with replacement: String
    ) -> String {
        let nsText = text as NSString
        guard range.location + range.length <= nsText.length else { return text }
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
