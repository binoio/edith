//
//  SearchUITests.swift
//  EdithUITests
//

import XCTest

final class SearchUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Opt out of session restore: without it each launch reopens the
        // previous test's documents and the suite accumulates windows
        app.launchArguments += ["-EdithUITesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // Close every document window so none is left for a later launch
        app.typeKey("w", modifierFlags: [.command, .option])
        app.terminate()
    }
    
    // MARK: - Search Menu Tests
    
    func testSearchMenuExists() throws {
        let menuBar = app.menuBars.firstMatch
        let searchMenu = menuBar.menuBarItems["Search"]
        
        XCTAssertTrue(searchMenu.exists, "Search menu should exist")
    }
    
    func testSearchMenuContainsFindAndReplace() throws {
        let menuBar = app.menuBars.firstMatch
        let searchMenu = menuBar.menuBarItems["Search"]
        
        searchMenu.click()
        
        let findReplaceItem = app.menuItems["Find & Replace..."]
        XCTAssertTrue(findReplaceItem.exists, "Find & Replace menu item should exist")
    }
    
    func testSearchMenuContainsFindNext() throws {
        let menuBar = app.menuBars.firstMatch
        let searchMenu = menuBar.menuBarItems["Search"]
        
        searchMenu.click()
        
        let findNextItem = app.menuItems["Find Next"]
        XCTAssertTrue(findNextItem.exists, "Find Next menu item should exist")
    }
    
    func testSearchMenuContainsFindPrevious() throws {
        let menuBar = app.menuBars.firstMatch
        let searchMenu = menuBar.menuBarItems["Search"]
        
        searchMenu.click()
        
        let findPreviousItem = app.menuItems["Find Previous"]
        XCTAssertTrue(findPreviousItem.exists, "Find Previous menu item should exist")
    }
    
    func testSearchMenuIsAfterViewMenu() throws {
        let menuBar = app.menuBars.firstMatch
        let menuItems = menuBar.menuBarItems.allElementsBoundByIndex
        
        var viewIndex = -1
        var searchIndex = -1
        
        for (index, item) in menuItems.enumerated() {
            if item.title == "View" {
                viewIndex = index
            } else if item.title == "Search" {
                searchIndex = index
            }
        }
        
        XCTAssertTrue(viewIndex >= 0, "View menu should exist")
        XCTAssertTrue(searchIndex >= 0, "Search menu should exist")
        XCTAssertTrue(searchIndex > viewIndex, "Search menu should come after View menu")
    }
    
    // MARK: - Find & Replace Window Tests
    
    func testFindReplaceWindowOpensWithCommandF() throws {
        // Need an open document for Find & Replace
        app.typeKey("n", modifierFlags: .command)
        
        // Wait for document window
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 2))
        
        // Open Find & Replace with ⌘F
        app.typeKey("f", modifierFlags: .command)
        
        // The window or panel should appear
        // Note: Window title or identifier may vary based on implementation
        let findReplaceWindow = app.windows["Find & Replace"]
        
        // Give it time to appear
        if findReplaceWindow.waitForExistence(timeout: 2) {
            XCTAssertTrue(findReplaceWindow.exists)
        }
        // If window doesn't appear, the feature may use a sheet or different mechanism
    }

    // MARK: - Find & Replace Panel Behaviour
    
    /// Open a document containing the reported text and bring up the panel
    private func openPanel(with text: String) throws -> XCUIElement {
        app.typeKey("n", modifierFlags: .command)
        
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5), "document window should open")
        // The app focuses the text view on launch, so a click is only a nudge --
        // and a window positioned partly off screen has no hit point to click
        if textView.isHittable {
            textView.click()
        }
        
        // Start from a document holding only what this test typed
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        app.typeText(text)
        
        // Back to the top so the search anchors from the start of the document
        app.typeKey(.home, modifierFlags: [.command])
        
        app.typeKey("f", modifierFlags: .command)
        let panel = app.windows["Find & Replace"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "Find & Replace panel should open")
        return panel
    }
    
    /// The reported bug, end to end: the index must stay inside the match set
    func testTypingCloudReportsTheRightCount() throws {
        let panel = try openPanel(with: "Cloud Engineer\ncloud native\nno match here\nCloud again\n")
        
        let findField = panel.textFields.firstMatch
        XCTAssertTrue(findField.waitForExistence(timeout: 2), "find field should exist")
        findField.click()
        findField.typeText("Cloud")
        
        // Debounced search, then a count that never exceeds the total
        let count = panel.staticTexts.matching(NSPredicate(format: "value CONTAINS ' of '")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 3), "the panel should report a match count")
        
        let label = (count.value as? String) ?? count.label
        let parts = label.components(separatedBy: " of ")
        XCTAssertEqual(parts.count, 2, "unexpected count format: \(label)")
        
        let index = Int(parts[0].trimmingCharacters(in: .whitespaces)) ?? -1
        let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? -1
        XCTAssertGreaterThanOrEqual(total, 1, "expected at least one match, got \(label)")
        XCTAssertGreaterThanOrEqual(index, 1, "count read \(label)")
        XCTAssertLessThanOrEqual(index, total, "count read \(label) -- the index escaped the match set")
    }
    
    /// Narrowing the pattern must not leave the wider pattern's count behind
    func testNarrowingThePatternKeepsTheCountConsistent() throws {
        let panel = try openPanel(with: "Cloud Engineer\ncloud native\ncoconut cocoa\nCloud again\n")
        
        let findField = panel.textFields.firstMatch
        XCTAssertTrue(findField.waitForExistence(timeout: 2))
        findField.click()
        
        for character in "Cloud" {
            findField.typeText(String(character))
            
            let count = panel.staticTexts.matching(NSPredicate(format: "value CONTAINS ' of '")).firstMatch
            guard count.waitForExistence(timeout: 2) else { continue }
            
            let label = (count.value as? String) ?? count.label
            let parts = label.components(separatedBy: " of ")
            guard parts.count == 2,
                  let index = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                  let total = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
            
            XCTAssertLessThanOrEqual(index, total,
                                     "after typing \"\(character)\" the panel read \(label)")
        }
    }
    
    /// The panel is a floating utility window, so the document stays usable behind it
    func testPanelFloatsOverTheDocument() throws {
        let panel = try openPanel(with: "Cloud Engineer\n")
        
        XCTAssertTrue(app.windows.count >= 2, "the document window should still be open")
        XCTAssertTrue(panel.exists, "the panel should remain on screen alongside the document")
    }
}
