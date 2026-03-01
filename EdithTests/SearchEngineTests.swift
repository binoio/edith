//
//  SearchEngineTests.swift
//  EdithTests
//

import XCTest
@testable import Edith

final class SearchEngineTests: XCTestCase {
    
    // MARK: - Plain Text Search Tests
    
    func testFindPlainTextMatchesSingle() {
        let text = "Hello World"
        let matches = SearchEngine.findMatches(in: text, pattern: "World")
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 6)
        XCTAssertEqual(matches[0].length, 5)
    }
    
    func testFindPlainTextMatchesMultiple() {
        let text = "cat dog cat bird cat"
        let matches = SearchEngine.findMatches(in: text, pattern: "cat")
        
        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].location, 0)
        XCTAssertEqual(matches[1].location, 8)
        XCTAssertEqual(matches[2].location, 17)
    }
    
    func testFindPlainTextNoMatches() {
        let text = "Hello World"
        let matches = SearchEngine.findMatches(in: text, pattern: "xyz")
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testFindPlainTextEmptyPattern() {
        let text = "Hello World"
        let matches = SearchEngine.findMatches(in: text, pattern: "")
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testFindPlainTextCaseInsensitive() {
        let text = "Hello HELLO hello"
        let matches = SearchEngine.findMatches(in: text, pattern: "hello", caseSensitive: false)
        
        XCTAssertEqual(matches.count, 3)
    }
    
    func testFindPlainTextCaseSensitive() {
        let text = "Hello HELLO hello"
        let matches = SearchEngine.findMatches(in: text, pattern: "hello", caseSensitive: true)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 12)
    }
    
    // MARK: - PCRE Regex Search Tests
    
    func testFindRegexSimplePattern() {
        let text = "cat123 dog456 cat789"
        let matches = SearchEngine.findMatches(in: text, pattern: "cat\\d+", usePCRE: true)
        
        XCTAssertEqual(matches.count, 2)
    }
    
    func testFindRegexWordBoundary() {
        let text = "cat category catalog"
        let matches = SearchEngine.findMatches(in: text, pattern: "\\bcat\\b", usePCRE: true)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 0)
        XCTAssertEqual(matches[0].length, 3)
    }
    
    func testFindRegexCharacterClass() {
        let text = "a1 b2 c3 d4"
        let matches = SearchEngine.findMatches(in: text, pattern: "[a-c]\\d", usePCRE: true)
        
        XCTAssertEqual(matches.count, 3)
    }
    
    func testFindRegexInvalidPattern() {
        let text = "Hello World"
        let matches = SearchEngine.findMatches(in: text, pattern: "[invalid", usePCRE: true)
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testFindRegexCaseInsensitive() {
        let text = "ABC abc AbC"
        let matches = SearchEngine.findMatches(in: text, pattern: "abc", caseSensitive: false, usePCRE: true)
        
        XCTAssertEqual(matches.count, 3)
    }
    
    func testFindRegexCaseSensitive() {
        let text = "ABC abc AbC"
        let matches = SearchEngine.findMatches(in: text, pattern: "abc", caseSensitive: true, usePCRE: true)
        
        XCTAssertEqual(matches.count, 1)
    }
    
    func testFindRegexLineAnchors() {
        // Test that ^ and $ match line boundaries, not just string boundaries
        let text = "hello\n124\nworld"
        let matches = SearchEngine.findMatches(in: text, pattern: "^[0-9]+$", usePCRE: true)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual((text as NSString).substring(with: matches[0]), "124")
    }
    
    func testFindRegexStartOfLine() {
        let text = "line1\nline2\nline3"
        let matches = SearchEngine.findMatches(in: text, pattern: "^line", usePCRE: true)
        
        XCTAssertEqual(matches.count, 3)
    }
    
    func testFindRegexEndOfLine() {
        let text = "cat\ndog\nbat"
        let matches = SearchEngine.findMatches(in: text, pattern: "at$", usePCRE: true)
        
        XCTAssertEqual(matches.count, 2) // "cat" and "bat"
    }
    
    // MARK: - Search Range Tests
    
    func testFindWithSearchRange() {
        let text = "cat dog cat bird cat"
        let range = NSRange(location: 5, length: 10) // "og cat bir"
        let matches = SearchEngine.findMatches(in: text, pattern: "cat", searchRange: range)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 8)
    }
    
    // MARK: - Replace Tests
    
    func testReplaceAll() {
        let text = "cat dog cat"
        let result = SearchEngine.replaceAll(in: text, pattern: "cat", replacement: "bird")
        
        XCTAssertEqual(result, "bird dog bird")
    }
    
    func testReplaceAllCaseSensitive() {
        let text = "Cat cat CAT"
        let result = SearchEngine.replaceAll(in: text, pattern: "cat", replacement: "dog", caseSensitive: true)
        
        XCTAssertEqual(result, "Cat dog CAT")
    }
    
    func testReplaceAllNoMatches() {
        let text = "Hello World"
        let result = SearchEngine.replaceAll(in: text, pattern: "xyz", replacement: "abc")
        
        XCTAssertEqual(result, "Hello World")
    }
    
    func testReplaceAllRegex() {
        let text = "cat123 dog456"
        let result = SearchEngine.replaceAll(in: text, pattern: "\\d+", replacement: "XXX", usePCRE: true)
        
        XCTAssertEqual(result, "catXXX dogXXX")
    }
    
    func testReplaceMatch() {
        let text = "Hello World"
        let range = NSRange(location: 6, length: 5)
        let result = SearchEngine.replaceMatch(in: text, at: range, with: "Universe")
        
        XCTAssertEqual(result, "Hello Universe")
    }
    
    func testReplaceMatchInvalidRange() {
        let text = "Hello"
        let range = NSRange(location: 10, length: 5)
        let result = SearchEngine.replaceMatch(in: text, at: range, with: "World")
        
        XCTAssertEqual(result, "Hello") // Unchanged
    }
    
    // MARK: - Extract Tests
    
    func testExtractAll() {
        let text = "cat dog cat bird cat"
        let extracted = SearchEngine.extractAll(from: text, pattern: "cat")
        
        XCTAssertEqual(extracted.count, 3)
        XCTAssertEqual(extracted, ["cat", "cat", "cat"])
    }
    
    func testExtractAllRegex() {
        let text = "cat123 dog456 bird789"
        let extracted = SearchEngine.extractAll(from: text, pattern: "\\d+", usePCRE: true)
        
        XCTAssertEqual(extracted.count, 3)
        XCTAssertEqual(extracted, ["123", "456", "789"])
    }
    
    func testExtractAllNoMatches() {
        let text = "Hello World"
        let extracted = SearchEngine.extractAll(from: text, pattern: "xyz")
        
        XCTAssertTrue(extracted.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    func testFindEmptyText() {
        let text = ""
        let matches = SearchEngine.findMatches(in: text, pattern: "test")
        
        XCTAssertTrue(matches.isEmpty)
    }
    
    func testFindOverlappingMatches() {
        let text = "aaaa"
        let matches = SearchEngine.findMatches(in: text, pattern: "aa")
        
        // Non-overlapping matches: positions 0 and 2
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].location, 0)
        XCTAssertEqual(matches[1].location, 2)
    }
    
    func testFindSpecialCharacters() {
        let text = "a.b*c?d"
        let matches = SearchEngine.findMatches(in: text, pattern: ".")
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 1)
    }
    
    func testRegexSpecialCharactersAsLiteral() {
        let text = "a.b*c?d"
        let matches = SearchEngine.findMatches(in: text, pattern: "\\.", usePCRE: true)
        
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].location, 1)
    }
    
    func testFindMultilineText() {
        let text = "line1\nline2\nline3"
        let matches = SearchEngine.findMatches(in: text, pattern: "line")
        
        XCTAssertEqual(matches.count, 3)
    }
}
