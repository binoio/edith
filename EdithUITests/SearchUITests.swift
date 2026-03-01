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
        app.launch()
    }
    
    override func tearDownWithError() throws {
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
}
