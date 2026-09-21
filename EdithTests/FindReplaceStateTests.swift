//
//  FindReplaceStateTests.swift
//  EdithTests
//
//  Regression tests for the find/replace result set. The fixture is the real
//  document the reported bugs were found in: 27 lines, 93 case-insensitive "c"
//  matches, and 7 "cloud" matches. The 8th "c" (index 7) sits at offset 127 --
//  the "C" of "Cloud Engineer" on line 7 -- which is what let a cursor parked
//  on that line produce an index of 7 against a 7-match set.
//

import XCTest
import AppKit
@testable import Edith

enum CoverLetterFixture {
    static let text = #"""
# Michael Bino

Lawrenceville, NJ · mb@michaelbino.com · 732-917-4401 · michaelbino.com

September 19, 2026

Hiring Committee, Cloud Engineer\
Information Technology Services, Application Development\
Seton Hall University

Dear Members of the Hiring Committee,

For the twenty-five years of my career at Princeton University I have been the sole technology lead for the Department of Operations Research and Financial Engineering (ORFE), which has meant designing the department's cloud, provisioning it, integrating it with everything else on campus, and answering for it when it breaks. I am writing to apply for the Cloud Engineer position within IT Services, job number 497501.

The posting describes provisioning and integration as two halves of the same job, and that is how work arrives at my desk. On the provisioning side I publish our hosting platform as a library of infrastructure-as-code modules rather than as environments I hand-build: private database subnets, secrets and registry reached by managed identity, validated pre-deploy backup, one immutable image per commit with rollback by tag. Two hosting topologies deploy from that library, and our research groups can stand up their own applications from it instead of asking me to build theirs. Every production application carries scheduled backup and security-audit workflows, network security rules are watched by drift detection, and nothing stores a credential; deployments authenticate by OIDC and federated identity.

On the integration side, analyzing an existing process and replacing it with an automated one is a primary motivation in where I'd like to apply my talents next. Whether it has been automating our DocuSign webforms to feed our expense system, designing conference registration integrations with Eventbrite and a custom check-in pipeline, or transforming our calendaring into machine-readable feeds that campus systems ingest on a schedule rather than staff re-keying them, I've leveraged AI and automation to find, build out, and audit opportunities for efficiencies. I document as I go as a matter of professional practice: our incident response plan, continuity supplement, runbooks, and architecture notes, to name a few.

My hands-on cloud experience is Azure and Google Cloud rather than Amazon. I have taken internal training in AWS, and where the platform appears in my working record it is as the one I assessed workloads on and then moved them off of. That is relevant experience, but not the same as having run it. Terraform, Git, containers, identity federation, and the habit of describing infrastructure in code all carry over as core principles and practices around cloud and platform engineering.

The rest of this role is familiar ground. I represent my department in architecture and standards conversations with our central IT, network, and security groups, and at administrative meetings well above my own reporting line.

I would welcome the chance to discuss whether that is the Cloud Engineer you are looking for.

Sincerely,

Michael Bino

"""#
    
    /// Case-insensitive occurrences of "c"
    static let singleLetterCMatches = 93
    /// Case-insensitive occurrences of "cloud"
    static let cloudMatches = 7
    /// Offset of the "C" in "Cloud Engineer" on line 7
    static let firstCloudOffset = 127
    /// Logical lines in the document, counting the empty line after the final newline
    static let lineCount = 28
}

@MainActor
final class FindReplaceStateTests: XCTestCase {
    
    private var window: NSWindow!
    private var scrollView: LineNumberScrollView!
    private var textView: NSTextView!
    private var state: FindReplaceState!
    
    override func setUp() {
        super.setUp()
        let frame = NSRect(x: 0, y: 0, width: 700, height: 520)
        // An undo manager comes off the responder chain, so the text view needs
        // a window for the replace tests to exercise undo at all
        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .resizable],
                          backing: .buffered,
                          defer: false)
        // Closed explicitly in tearDown; without this AppKit would free it there
        window.isReleasedWhenClosed = false
        scrollView = LineNumberScrollView(frame: frame)
        window.contentView = scrollView
        scrollView.layoutSubtreeIfNeeded()
        
        textView = scrollView.textView
        textView.string = CoverLetterFixture.text
        state = FindReplaceState()
        state.textView = textView
    }
    
    override func tearDown() {
        state = nil
        textView = nil
        scrollView = nil
        // Dropping the reference does not close the window; one leaked per test
        window?.contentView = nil
        window?.close()
        window = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    /// Every range currently carrying a find highlight
    private func highlightedRanges() -> [NSRange] {
        guard let layoutManager = textView.layoutManager,
              let length = textView.textStorage?.length else { return [] }
        let whole = NSRange(location: 0, length: length)
        
        var ranges: [NSRange] = []
        var idx = 0
        while idx < length {
            var effective = NSRange()
            let value = layoutManager.temporaryAttribute(.backgroundColor,
                                                         atCharacterIndex: idx,
                                                         longestEffectiveRange: &effective,
                                                         in: whole)
            if value != nil, effective.length > 0 {
                ranges.append(effective)
            }
            idx = effective.length > 0 ? NSMaxRange(effective) : idx + 1
        }
        return ranges
    }
    
    private func search(_ pattern: String) {
        state.findText = pattern
        state.performSearch()
    }
    
    // MARK: - The reported bug
    
    /// Typing "Cloud" with the caret on line 7 used to report "8 of 7".
    func testIncrementalNarrowingClampsCurrentMatchIndex() {
        // Caret just before the "C" of "Cloud Engineer"
        textView.setSelectedRange(NSRange(location: 120, length: 0))
        
        search("C")
        XCTAssertEqual(state.totalMatches, CoverLetterFixture.singleLetterCMatches)
        XCTAssertEqual(state.currentMatchIndex, 7,
                       "the caret on line 7 should land on the 8th \"c\", which is what made this reproduce")
        
        search("Cl")
        XCTAssertEqual(state.totalMatches, CoverLetterFixture.cloudMatches)
        XCTAssertTrue((0..<state.totalMatches).contains(state.currentMatchIndex),
                      "index \(state.currentMatchIndex) escaped a \(state.totalMatches)-match set")
    }
    
    /// The panel must never render an index the match set does not contain.
    func testDisplayedIndexNeverExceedsTotal() {
        textView.setSelectedRange(NSRange(location: 120, length: 0))
        
        for prefix in ["C", "Cl", "Clo", "Clou", "Cloud"] {
            search(prefix)
            guard case let .match(index, total) = state.matchSummary else {
                XCTFail("expected matches for \"\(prefix)\", got \(state.matchSummary)")
                continue
            }
            XCTAssertGreaterThanOrEqual(index, 1, "\"\(prefix)\" reported index \(index)")
            XCTAssertLessThanOrEqual(index, total, "\"\(prefix)\" reported \(index) of \(total)")
        }
    }
    
    /// Typing through to "Cloud" from line 7 lands on the first match.
    func testTypingCloudFromLineSevenReportsOneOfSeven() {
        textView.setSelectedRange(NSRange(location: 120, length: 0))
        for prefix in ["C", "Cl", "Clo", "Clou", "Cloud"] { search(prefix) }
        
        XCTAssertEqual(state.matchSummary, .match(index: 1, total: 7))
    }
    
    /// Narrowing the pattern used to leave the previous pattern's highlights
    /// on screen -- 93 single "c" characters, while the panel said "8 of 7".
    func testHighlightsClearedWhenMatchSetNarrows() {
        textView.setSelectedRange(NSRange(location: 120, length: 0))
        
        search("C")
        XCTAssertEqual(highlightedRanges().count, CoverLetterFixture.singleLetterCMatches)
        
        search("Cloud")
        let ranges = highlightedRanges()
        XCTAssertEqual(ranges.count, CoverLetterFixture.cloudMatches)
        XCTAssertTrue(ranges.allSatisfy { $0.length == 5 },
                      "single-character highlights survived the narrower search: \(ranges)")
        XCTAssertTrue(ranges.contains { $0.location == CoverLetterFixture.firstCloudOffset })
    }
    
    /// Find highlighting must not write into the document's own attributes
    func testHighlightingLeavesTextStorageUntouched() {
        search("Cloud")
        
        let storage = textView.textStorage!
        var idx = 0
        while idx < storage.length {
            var effective = NSRange()
            let value = storage.attribute(.backgroundColor, at: idx, effectiveRange: &effective)
            XCTAssertNil(value, "find highlighting wrote .backgroundColor into the text storage at \(idx)")
            idx = effective.length > 0 ? NSMaxRange(effective) : idx + 1
        }
    }
    
    // MARK: - Navigation
    
    func testFindNextCyclesEveryMatchAndWraps() {
        search("Cloud")
        state.wrapAround = true
        
        var visited: [Int] = [state.currentMatchIndex]
        for _ in 0..<CoverLetterFixture.cloudMatches {
            state.findNext()
            visited.append(state.currentMatchIndex)
        }
        
        XCTAssertEqual(visited, [0, 1, 2, 3, 4, 5, 6, 0])
    }
    
    func testFindPreviousWrapsBackwards() {
        search("Cloud")
        state.wrapAround = true
        
        state.findPrevious()
        XCTAssertEqual(state.currentMatchIndex, CoverLetterFixture.cloudMatches - 1)
    }
    
    // MARK: - Stale ranges
    
    /// Match ranges index into the text as it was. After an edit shortens the
    /// document, applying them would address characters that no longer exist.
    func testStaleMatchesAfterDocumentEditDoNotCrash() {
        search("Cloud")
        XCTAssertEqual(state.totalMatches, CoverLetterFixture.cloudMatches)
        
        textView.string = "short"
        
        // Without the change notification the cached ranges are still around;
        // they must be filtered rather than applied.
        state.findNext()
        
        state.noteDocumentChanged()
        state.findNext()
        XCTAssertEqual(state.totalMatches, 0)
        XCTAssertEqual(state.matchSummary, .noMatches)
    }
    
    // MARK: - Replace
    
    func testReplaceAllRewritesEveryMatchAndNothingElse() {
        let originalLength = (textView.string as NSString).length
        
        state.replaceText = "Sky"
        search("Cloud")
        state.replaceAll()
        
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "cloud").count, 0)
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "Sky").count,
                       CoverLetterFixture.cloudMatches)
        XCTAssertEqual((textView.string as NSString).length,
                       originalLength - CoverLetterFixture.cloudMatches * 2,
                       "Replace All changed more than the matches")
        XCTAssertTrue(textView.string.hasPrefix("# Michael Bino"),
                      "Replace All disturbed text outside the matches")
    }
    
    func testReplaceAllIsUndoableAsOneEdit() {
        let original = textView.string
        
        state.replaceText = "Sky"
        search("Cloud")
        state.replaceAll()
        XCTAssertNotEqual(textView.string, original)
        
        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, original, "Replace All should undo in a single step")
    }
    
    func testReplaceNextReplacesOnlyTheCurrentMatch() {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        state.replaceText = "Sky"
        search("Cloud")
        
        state.replaceNext()
        
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "cloud").count,
                       CoverLetterFixture.cloudMatches - 1)
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "Sky").count, 1)
    }
    
    // MARK: - PCRE
    
    func testInvalidPatternIsReportedRatherThanSilentlyEmpty() {
        state.usePCRE = true
        search("[invalid")
        
        XCTAssertNotNil(state.patternError)
        XCTAssertEqual(state.totalMatches, 0)
        guard case .invalidPattern = state.matchSummary else {
            return XCTFail("expected .invalidPattern, got \(state.matchSummary)")
        }
    }
    
    func testRecoveringFromAnInvalidPatternClearsTheError() {
        state.usePCRE = true
        search("[invalid")
        XCTAssertNotNil(state.patternError)
        
        search("[Cc]loud")
        XCTAssertNil(state.patternError)
        XCTAssertEqual(state.totalMatches, CoverLetterFixture.cloudMatches)
    }
    
    /// `x*` matches the empty string everywhere; those matches highlight
    /// nothing and leave Find Next with nowhere to go.
    func testZeroLengthRegexMatchesAreNotOffered() {
        state.usePCRE = true
        search("x*")
        
        XCTAssertTrue(state.matches.allSatisfy { $0.length > 0 },
                      "zero-length matches were offered as results")
    }
    
    func testPCREBackreferenceReplacement() {
        state.usePCRE = true
        state.replaceText = "[$1] Architect"
        search("(Cloud) Engineer")
        XCTAssertEqual(state.totalMatches, 3, "\"Cloud Engineer\" appears three times in the letter")
        
        state.replaceAll()
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "[Cloud] Architect").count, 3)
        XCTAssertEqual(SearchEngine.findMatches(in: textView.string, pattern: "Cloud Engineer").count, 0)
    }
    
    // MARK: - Scoped search
    
    func testSelectedTextOnlyLimitsTheMatchSet() {
        // Lines 1-11, which contain exactly one "Cloud"
        textView.setSelectedRange(NSRange(location: 0, length: 250))
        state.captureSelection()
        state.selectedTextOnly = true
        
        search("Cloud")
        XCTAssertEqual(state.totalMatches, 1)
        
        state.selectedTextOnly = false
        state.performSearch()
        XCTAssertEqual(state.totalMatches, CoverLetterFixture.cloudMatches)
    }
    
    func testEmptyPatternClearsResultsAndHighlights() {
        search("Cloud")
        XCTAssertFalse(highlightedRanges().isEmpty)
        
        search("")
        XCTAssertEqual(state.totalMatches, 0)
        XCTAssertEqual(state.matchSummary, .idle)
        XCTAssertTrue(highlightedRanges().isEmpty)
    }
}
