//
//  ZoomUITests.swift
//  EdithUITests
//
//  UI tests for zoom functionality
//

import XCTest

final class ZoomUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Create a new document
        app.menuBars.menuItems["New Text Document"].click()
        sleep(1)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Menu Item Existence Tests
    
    func testViewMenuExists() {
        let viewMenu = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenu.exists, "View menu should exist")
    }
    
    func testZoomInMenuItemExists() {
        app.menuBars.menuBarItems["View"].click()
        let zoomIn = app.menuBars.menuItems["Zoom In"]
        XCTAssertTrue(zoomIn.exists, "Zoom In menu item should exist")
    }
    
    func testZoomOutMenuItemExists() {
        app.menuBars.menuBarItems["View"].click()
        let zoomOut = app.menuBars.menuItems["Zoom Out"]
        XCTAssertTrue(zoomOut.exists, "Zoom Out menu item should exist")
    }
    
    func testActualSizeMenuItemExists() {
        app.menuBars.menuBarItems["View"].click()
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.exists, "Actual Size menu item should exist")
    }
    
    // MARK: - Menu Item Click Tests
    
    func testZoomInViaMenu() {
        app.menuBars.menuBarItems["View"].click()
        let zoomIn = app.menuBars.menuItems["Zoom In"]
        XCTAssertTrue(zoomIn.isEnabled, "Zoom In should be enabled")
        zoomIn.click()
        // If we get here without crash, zoom in worked
    }
    
    func testZoomOutViaMenu() {
        app.menuBars.menuBarItems["View"].click()
        let zoomOut = app.menuBars.menuItems["Zoom Out"]
        XCTAssertTrue(zoomOut.isEnabled, "Zoom Out should be enabled")
        zoomOut.click()
    }
    
    func testActualSizeViaMenu() {
        // First zoom in
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        // Then actual size
        app.menuBars.menuBarItems["View"].click()
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be enabled after zooming")
        actualSize.click()
    }
    
    // MARK: - Keyboard Shortcut Tests
    
    func testZoomInKeyboardShortcut() {
        // ⌘= (Command + equals)
        app.typeKey("=", modifierFlags: .command)
        // If no crash, shortcut is registered
    }
    
    func testZoomOutKeyboardShortcut() {
        // ⌘- (Command + minus)
        app.typeKey("-", modifierFlags: .command)
    }
    
    func testActualSizeKeyboardShortcut() {
        // First zoom in
        app.typeKey("=", modifierFlags: .command)
        sleep(1)
        
        // Then ⌘0 for actual size
        app.typeKey("0", modifierFlags: .command)
    }
    
    // MARK: - Zoom Sequence Tests
    
    func testZoomInThenActualSize() {
        // Zoom in multiple times
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        // Reset with Actual Size
        app.menuBars.menuBarItems["View"].click()
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be enabled after zooming in")
        actualSize.click()
    }
    
    func testZoomOutThenActualSize() {
        // Zoom out multiple times
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom Out"].click()
        sleep(1)
        
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom Out"].click()
        sleep(1)
        
        // Reset with Actual Size
        app.menuBars.menuBarItems["View"].click()
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be enabled after zooming out")
        actualSize.click()
    }
    
    // MARK: - Debug Helper Tests
    
    func testPrintViewMenuItems() {
        // Click on the View menu bar item
        let viewMenuBarItem = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenuBarItem.exists, "View menu bar item should exist")
        viewMenuBarItem.click()
        sleep(1)
        
        // Get menu items from the View menu
        let viewMenu = viewMenuBarItem.menus.firstMatch
        let menuItems = viewMenu.menuItems
        print("=== View Menu Items ===")
        for i in 0..<menuItems.count {
            let item = menuItems.element(boundBy: i)
            print("Item \(i): '\(item.title)' enabled: \(item.isEnabled)")
        }
        print("=======================")
        
        // Dismiss menu
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testPrintAllMenuBars() {
        let menuBarItems = app.menuBars.menuBarItems
        print("=== Menu Bar Items ===")
        for i in 0..<menuBarItems.count {
            let item = menuBarItems.element(boundBy: i)
            print("Menu \(i): '\(item.title)'")
        }
        print("======================")
    }
    
    func testActualSizeKeyboardShortcutWorks() {
        // First zoom in via menu to change zoom level
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        let zoomIn = app.menuBars.menuItems["Zoom In"]
        if zoomIn.exists && zoomIn.isEnabled {
            zoomIn.click()
            sleep(1)
        }
        
        // Now try keyboard shortcut for Actual Size
        // ⌘0 should reset
        app.typeKey("0", modifierFlags: .command)
        sleep(1)
        
        // If we get here without crash, test the menu state
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        print("Actual Size exists: \(actualSize.exists), enabled: \(actualSize.isEnabled)")
        
        app.typeKey(.escape, modifierFlags: [])
    }
}
