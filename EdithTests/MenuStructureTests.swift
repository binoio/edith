//
//  MenuStructureTests.swift
//  EdithTests
//
//  Tests to protect against menu structure issues like duplicate top-level menus
//

import XCTest
@testable import Edith

final class MenuStructureTests: XCTestCase {
    
    func testNoTopLevelMenuDuplicates() {
        // Get the main menu
        guard let mainMenu = NSApp.mainMenu else {
            XCTFail("Application should have a main menu")
            return
        }
        
        // Collect all top-level menu titles
        var menuTitles: [String] = []
        for item in mainMenu.items {
            if let title = item.title as String?, !title.isEmpty {
                menuTitles.append(title)
            }
        }
        
        // Check for duplicates
        let uniqueTitles = Set(menuTitles)
        let duplicates = menuTitles.filter { title in
            menuTitles.filter { $0 == title }.count > 1
        }
        let uniqueDuplicates = Set(duplicates)
        
        XCTAssertEqual(menuTitles.count, uniqueTitles.count,
            "Found duplicate top-level menu items: \(uniqueDuplicates.joined(separator: ", "))")
    }
    
    func testExpectedMenusExist() {
        guard let mainMenu = NSApp.mainMenu else {
            XCTFail("Application should have a main menu")
            return
        }
        
        let menuTitles = mainMenu.items.compactMap { $0.title as String? }
        
        // Standard macOS app menus that should exist
        XCTAssertTrue(menuTitles.contains("File"), "Should have File menu")
        XCTAssertTrue(menuTitles.contains("Edit"), "Should have Edit menu")
        XCTAssertTrue(menuTitles.contains("View"), "Should have View menu")
        XCTAssertTrue(menuTitles.contains("Window"), "Should have Window menu")
        XCTAssertTrue(menuTitles.contains("Help"), "Should have Help menu")
    }
    
    func testViewMenuContainsLineNumbersOption() {
        guard let mainMenu = NSApp.mainMenu else {
            XCTFail("Application should have a main menu")
            return
        }
        
        guard let viewMenu = mainMenu.items.first(where: { $0.title == "View" })?.submenu else {
            XCTFail("Should have View menu")
            return
        }
        
        let viewMenuItemTitles = viewMenu.items.map { $0.title }
        let hasLineNumbersOption = viewMenuItemTitles.contains("Show Line Numbers") || 
                                   viewMenuItemTitles.contains("Hide Line Numbers")
        
        XCTAssertTrue(hasLineNumbersOption, 
            "View menu should contain Show/Hide Line Numbers option. Found: \(viewMenuItemTitles)")
    }
    
    func testSingleViewMenu() {
        guard let mainMenu = NSApp.mainMenu else {
            XCTFail("Application should have a main menu")
            return
        }
        
        let viewMenuCount = mainMenu.items.filter { $0.title == "View" }.count
        XCTAssertEqual(viewMenuCount, 1, "Should have exactly one View menu, found \(viewMenuCount)")
    }
    
    func testFileMenuContainsNewTextDocument() {
        guard let mainMenu = NSApp.mainMenu else {
            XCTFail("Application should have a main menu")
            return
        }
        
        guard let fileMenu = mainMenu.items.first(where: { $0.title == "File" })?.submenu else {
            XCTFail("Should have File menu")
            return
        }
        
        let fileMenuItemTitles = fileMenu.items.map { $0.title }
        XCTAssertTrue(fileMenuItemTitles.contains("New Text Document"),
            "File menu should contain 'New Text Document'. Found: \(fileMenuItemTitles)")
    }
}
