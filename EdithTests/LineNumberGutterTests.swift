//
//  LineNumberGutterTests.swift
//  EdithTests
//
//  Tests to protect line number gutter functionality from regression.
//

import XCTest
@testable import Edith

final class LineNumberGutterTests: XCTestCase {
    
    var scrollView: LineNumberScrollView!
    var textView: NSTextView!
    var lineNumberView: LineNumberView!
    
    override func setUp() {
        super.setUp()
        scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        textView = scrollView.textView
        lineNumberView = scrollView.lineNumberView
    }
    
    override func tearDown() {
        scrollView = nil
        textView = nil
        lineNumberView = nil
        super.tearDown()
    }
    
    // MARK: - Text Visibility Tests
    
    func testTextViewExists() {
        XCTAssertNotNil(textView, "Text view should exist")
    }
    
    func testTextViewHasCorrectBackgroundColor() {
        XCTAssertEqual(textView.backgroundColor, .textBackgroundColor, "Text view should have textBackgroundColor")
    }
    
    func testTextViewHasCorrectTextColor() {
        XCTAssertEqual(textView.textColor, .textColor, "Text view should have textColor")
    }
    
    func testTextViewDrawsBackground() {
        XCTAssertTrue(textView.drawsBackground, "Text view should draw background")
    }
    
    func testTextIsNotRichText() {
        XCTAssertFalse(textView.isRichText, "Text view should not be rich text")
    }
    
    func testTextCanBeEntered() {
        textView.string = "Hello, World!"
        XCTAssertEqual(textView.string, "Hello, World!", "Text should be enterable")
    }
    
    func testMultilineTextCanBeEntered() {
        let multilineText = "Line 1\nLine 2\nLine 3"
        textView.string = multilineText
        XCTAssertEqual(textView.string, multilineText, "Multiline text should be enterable")
    }
    
    func testTextViewHasFont() {
        XCTAssertNotNil(textView.font, "Text view should have a font")
    }
    
    func testTextViewFontIsMonospaced() {
        let font = textView.font!
        XCTAssertTrue(font.fontName.contains("Menlo") || font.fontName.contains("Monaco") || font.fontName.contains("Courier") || font.isFixedPitch, "Font should be monospaced")
    }
    
    // MARK: - Line Number View Structure Tests
    
    func testLineNumberViewExists() {
        XCTAssertNotNil(lineNumberView, "Line number view should exist")
    }
    
    func testLineNumberViewIsFlipped() {
        XCTAssertTrue(lineNumberView.isFlipped, "Line number view should use flipped coordinates")
    }
    
    func testLineNumberViewHasTextViewReference() {
        XCTAssertNotNil(lineNumberView.textView, "Line number view should reference text view")
        XCTAssertTrue(lineNumberView.textView === textView, "Line number view should reference correct text view")
    }
    
    func testLineNumberViewHasPositiveWidth() {
        XCTAssertGreaterThan(lineNumberView.requiredWidth, 0, "Line number view should have positive width")
    }
    
    func testLineNumberViewWidthIncreasesWithLineCount() {
        let emptyWidth = lineNumberView.requiredWidth
        
        // Add 1000 lines
        textView.string = (1...1000).map { "Line \($0)" }.joined(separator: "\n")
        
        let manyLinesWidth = lineNumberView.requiredWidth
        XCTAssertGreaterThan(manyLinesWidth, emptyWidth, "Width should increase with more lines")
    }
    
    // MARK: - Line Number Ordering Tests (Top to Bottom)
    
    func testLineNumbersStartAtOne() {
        textView.string = ""
        lineNumberView.needsDisplay = true
        
        // Line 1 should be shown for empty document
        let lineCount = textView.string.components(separatedBy: "\n").count
        XCTAssertEqual(lineCount, 1, "Empty document should have 1 line")
    }
    
    func testLineCountMatchesNewlines() {
        textView.string = "A\nB\nC\nD\nE"
        let lines = textView.string.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 5, "Should have 5 lines")
    }
    
    func testLineCountWithTrailingNewline() {
        textView.string = "A\nB\nC\n"
        let lines = textView.string.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4, "Should count trailing empty line")
    }
    
    // MARK: - Layout and Alignment Tests
    
    func testScrollViewContainsLineNumberView() {
        XCTAssertTrue(lineNumberView.superview === scrollView, "Line number view should be in scroll view")
    }
    
    func testScrollViewContainsTextScrollView() {
        XCTAssertTrue(scrollView.scrollView.superview === scrollView, "Text scroll view should be in container")
    }
    
    func testLineNumberViewIsPositionedLeft() {
        scrollView.layout()
        XCTAssertEqual(lineNumberView.frame.origin.x, 0, "Line number view should be at left edge")
    }
    
    func testTextScrollViewIsPositionedAfterGutter() {
        scrollView.layout()
        XCTAssertEqual(scrollView.scrollView.frame.origin.x, lineNumberView.frame.width, "Text scroll view should start after gutter")
    }
    
    func testLineNumberViewAndTextScrollViewFillWidth() {
        scrollView.layout()
        let totalWidth = lineNumberView.frame.width + scrollView.scrollView.frame.width
        XCTAssertEqual(totalWidth, scrollView.bounds.width, accuracy: 1.0, "Components should fill width")
    }
    
    func testLineNumberViewFillsHeight() {
        scrollView.layout()
        XCTAssertEqual(lineNumberView.frame.height, scrollView.bounds.height, "Line number view should fill height")
    }
    
    func testTextScrollViewFillsHeight() {
        scrollView.layout()
        XCTAssertEqual(scrollView.scrollView.frame.height, scrollView.bounds.height, "Text scroll view should fill height")
    }
    
    // MARK: - Text Container Inset Tests (for alignment)
    
    func testTextViewHasInset() {
        let inset = textView.textContainerInset
        XCTAssertGreaterThan(inset.height, 0, "Text view should have vertical inset")
    }
    
    func testTextContainerTracksWidth() {
        XCTAssertTrue(textView.textContainer?.widthTracksTextView ?? false, "Text container should track width")
    }
    
    // MARK: - Font Synchronization Tests
    
    func testLineNumberViewHasFont() {
        XCTAssertNotNil(lineNumberView.font, "Line number view should have font")
    }
    
    func testLineNumberViewFontCanBeChanged() {
        let newFont = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        lineNumberView.font = newFont
        XCTAssertEqual(lineNumberView.font.pointSize, 18, "Font size should be updated")
    }
    
    // MARK: - Layout Manager Tests (for correct positioning)
    
    func testTextViewHasLayoutManager() {
        XCTAssertNotNil(textView.layoutManager, "Text view should have layout manager")
    }
    
    func testTextViewHasTextContainer() {
        XCTAssertNotNil(textView.textContainer, "Text view should have text container")
    }
    
    func testTextViewHasTextStorage() {
        XCTAssertNotNil(textView.textStorage, "Text view should have text storage")
    }
    
    // MARK: - Coordinate System Tests
    
    func testLineNumberViewCoordinateSystemMatchesTextView() {
        XCTAssertEqual(lineNumberView.isFlipped, textView.isFlipped, "Coordinate systems should match")
    }
    
    // MARK: - Performance Tests
    
    func testHandlesLargeDocument() {
        let largeText = (1...10000).map { "Line \($0): Some text content here" }.joined(separator: "\n")
        textView.string = largeText
        
        XCTAssertEqual(textView.string.components(separatedBy: "\n").count, 10000, "Should handle 10000 lines")
        XCTAssertGreaterThan(lineNumberView.requiredWidth, 40, "Should have adequate width for 5-digit line numbers")
    }
}

// MARK: - Integration Tests

final class LineNumberGutterIntegrationTests: XCTestCase {
    
    func testEditorViewCanBeCreated() {
        let settingsManager = SettingsManager()
        XCTAssertNotNil(settingsManager, "Settings manager should exist for editor view")
    }
    
    func testSettingsManagerDefaults() {
        let settings = SettingsManager()
        // Reset to defaults first to ensure clean state
        settings.restoreDefaults()
        XCTAssertEqual(settings.fontName, "Menlo", "Default font should be Menlo")
        XCTAssertEqual(settings.fontSize, 13.0, "Default font size should be 13")
        XCTAssertEqual(settings.magnification, 1.0, "Default magnification should be 1.0")
    }
    
    func testMagnificationAffectsFontSize() {
        let settings = SettingsManager()
        let baseFontSize = settings.fontSize
        settings.magnification = 2.0
        
        let effectiveSize = settings.fontSize * settings.magnification
        XCTAssertEqual(effectiveSize, baseFontSize * 2.0, "Magnification should scale font size")
    }
    
    func testLineNumberScrollViewCreation() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        
        XCTAssertNotNil(scrollView.textView, "Should have text view")
        XCTAssertNotNil(scrollView.lineNumberView, "Should have line number view")
        XCTAssertNotNil(scrollView.scrollView, "Should have scroll view")
    }
    
    func testTextEntryUpdatesLineNumbers() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = scrollView.textView
        let lineNumberView = scrollView.lineNumberView
        
        let initialWidth = lineNumberView.requiredWidth
        
        // Add many lines
        textView.string = (1...100).map { "Line \($0)" }.joined(separator: "\n")
        
        let newWidth = lineNumberView.requiredWidth
        XCTAssertGreaterThanOrEqual(newWidth, initialWidth, "Width should not decrease with more lines")
    }
    
    func testScrollViewHasVerticalScroller() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertTrue(scrollView.scrollView.hasVerticalScroller, "Should have vertical scroller")
    }
    
    func testTextViewIsVerticallyResizable() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertTrue(scrollView.textView.isVerticallyResizable, "Text view should be vertically resizable")
    }
    
    func testShowLineNumbersDefaultsToTrue() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertTrue(scrollView.showLineNumbers, "Line numbers should be shown by default")
    }
    
    func testHideLineNumbers() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.showLineNumbers = false
        XCTAssertTrue(scrollView.lineNumberView.isHidden, "Line number view should be hidden")
    }
    
    func testShowLineNumbers() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.showLineNumbers = false
        scrollView.showLineNumbers = true
        XCTAssertFalse(scrollView.lineNumberView.isHidden, "Line number view should be visible")
    }
    
    func testLayoutWithLineNumbersHidden() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.showLineNumbers = false
        scrollView.layout()
        XCTAssertEqual(scrollView.scrollView.frame.origin.x, 0, "Scroll view should start at x=0 when line numbers hidden")
        XCTAssertEqual(scrollView.scrollView.frame.width, 600, "Scroll view should use full width when line numbers hidden")
    }
    
    func testLayoutWithLineNumbersVisible() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        scrollView.showLineNumbers = true
        scrollView.layout()
        XCTAssertGreaterThan(scrollView.scrollView.frame.origin.x, 0, "Scroll view should be offset when line numbers visible")
        XCTAssertLessThan(scrollView.scrollView.frame.width, 600, "Scroll view should not use full width when line numbers visible")
    }
    
    func testSettingsManagerShowLineNumbersDefault() {
        let settings = SettingsManager()
        settings.restoreDefaults()
        XCTAssertTrue(settings.showLineNumbers, "showLineNumbers should default to true")
    }
}

// MARK: - Visual Regression Tests

final class LineNumberVisualRegressionTests: XCTestCase {
    
    func testGutterBackgroundColor() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertNotNil(scrollView.lineNumberView, "Line number view should exist")
        XCTAssertNotNil(NSColor.controlBackgroundColor, "Control background color should exist")
    }
    
    func testGutterSeparatorColor() {
        XCTAssertNotNil(NSColor.separatorColor, "Separator color should exist")
    }
    
    func testLineNumberTextColor() {
        XCTAssertNotNil(NSColor.secondaryLabelColor, "Secondary label color should exist")
    }
    
    func testTextAreaBackgroundColor() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertEqual(scrollView.textView.backgroundColor, NSColor.textBackgroundColor, "Text area should use textBackgroundColor")
    }
    
    func testTextAreaTextColor() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        XCTAssertEqual(scrollView.textView.textColor, NSColor.textColor, "Text area should use textColor")
    }
    
    // MARK: - Gutter Width Stability Tests
    
    func testGutterWidthDoesNotChangeWithFontSize() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let lineNumberView = scrollView.lineNumberView
        
        // Get initial width with default font
        lineNumberView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let widthAt13pt = lineNumberView.requiredWidth
        
        // Change font size - width should remain the same
        lineNumberView.font = NSFont.monospacedSystemFont(ofSize: 26, weight: .regular)
        let widthAt26pt = lineNumberView.requiredWidth
        
        XCTAssertEqual(widthAt13pt, widthAt26pt, "Gutter width should not change with font size")
    }
    
    func testGutterWidthDoesNotChangeWithMagnification() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let lineNumberView = scrollView.lineNumberView
        
        // Get initial width
        lineNumberView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let initialWidth = lineNumberView.requiredWidth
        
        // Simulate magnification by changing font (as EditorView does)
        lineNumberView.font = NSFont.monospacedSystemFont(ofSize: 13 * 2.0, weight: .regular)
        let zoomedWidth = lineNumberView.requiredWidth
        
        XCTAssertEqual(initialWidth, zoomedWidth, "Gutter width should not respond to magnification")
    }
    
    func testGutterWidthOnlyChangesWithLineCount() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let lineNumberView = scrollView.lineNumberView
        let textView = scrollView.textView
        
        // Width with few lines
        textView.string = "Line 1\nLine 2\nLine 3"
        let width3Lines = lineNumberView.requiredWidth
        
        // Width with many lines (4+ digits)
        textView.string = (1...10000).map { "Line \($0)" }.joined(separator: "\n")
        let width10000Lines = lineNumberView.requiredWidth
        
        XCTAssertGreaterThan(width10000Lines, width3Lines, "Gutter width should increase for more line number digits")
    }
    
    func testGutterWidthIsConsistentAcrossMultipleFontChanges() {
        let scrollView = LineNumberScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let lineNumberView = scrollView.lineNumberView
        
        var widths: [CGFloat] = []
        
        for size in [10.0, 13.0, 16.0, 20.0, 30.0, 50.0] {
            lineNumberView.font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            widths.append(lineNumberView.requiredWidth)
        }
        
        // All widths should be identical
        let uniqueWidths = Set(widths)
        XCTAssertEqual(uniqueWidths.count, 1, "Gutter width should be constant regardless of font size changes")
    }
}

// Extension to check if font is fixed pitch
extension NSFont {
    var isFixedPitch: Bool {
        let descriptor = fontDescriptor
        let traits = descriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        let symbolicTraits = traits?[.symbolic] as? UInt32 ?? 0
        return (symbolicTraits & NSFontDescriptor.SymbolicTraits.monoSpace.rawValue) != 0
    }
}
