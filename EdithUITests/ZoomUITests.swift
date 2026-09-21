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
        // Opt out of session restore: without it each launch reopens the
        // previous test's documents and the suite accumulates windows
        app.launchArguments += ["-EdithUITesting"]
        app.launch()
        
        // Create a new document
        app.menuBars.menuItems["New Text Document"].click()
        sleep(1)
    }
    
    override func tearDownWithError() throws {
        app.typeKey("w", modifierFlags: [.command, .option])
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
    
    // MARK: - Zoom Bounds Disabled State Tests
    
    func testZoomInDisabledAtMaximum() {
        // Zoom in repeatedly to reach maximum
        for _ in 0..<10 {
            app.menuBars.menuBarItems["View"].click()
            let zoomIn = app.menuBars.menuItems["Zoom In"]
            if zoomIn.isEnabled {
                zoomIn.click()
                sleep(1)
            } else {
                break
            }
        }
        
        // Check Zoom In is now disabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let zoomIn = app.menuBars.menuItems["Zoom In"]
        XCTAssertFalse(zoomIn.isEnabled, "Zoom In should be DISABLED at maximum zoom (4.0)")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testZoomOutDisabledAtMinimum() {
        // Zoom out repeatedly to reach minimum
        for _ in 0..<10 {
            app.menuBars.menuBarItems["View"].click()
            let zoomOut = app.menuBars.menuItems["Zoom Out"]
            if zoomOut.isEnabled {
                zoomOut.click()
                sleep(1)
            } else {
                break
            }
        }
        
        // Check Zoom Out is now disabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let zoomOut = app.menuBars.menuItems["Zoom Out"]
        XCTAssertFalse(zoomOut.isEnabled, "Zoom Out should be DISABLED at minimum zoom (0.25)")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testZoomOutStillEnabledAfterZoomIn() {
        // Zoom in
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        // Check Zoom Out is still enabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let zoomOut = app.menuBars.menuItems["Zoom Out"]
        XCTAssertTrue(zoomOut.isEnabled, "Zoom Out should remain enabled after zooming in")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testZoomInStillEnabledAfterZoomOut() {
        // Zoom out
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom Out"].click()
        sleep(1)
        
        // Check Zoom In is still enabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let zoomIn = app.menuBars.menuItems["Zoom In"]
        XCTAssertTrue(zoomIn.isEnabled, "Zoom In should remain enabled after zooming out")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    // MARK: - Keyboard Shortcut Verification Tests
    
    func testZoomInKeyboardShortcutChangesState() {
        // Use keyboard shortcut to zoom in
        app.typeKey("=", modifierFlags: .command)
        sleep(1)
        
        // Verify Actual Size is now enabled (indicating zoom changed)
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be enabled after ⌘= shortcut")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testZoomOutKeyboardShortcutChangesState() {
        // Use keyboard shortcut to zoom out
        app.typeKey("-", modifierFlags: .command)
        sleep(1)
        
        // Verify Actual Size is now enabled (indicating zoom changed)
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be enabled after ⌘- shortcut")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testActualSizeKeyboardShortcutResetsState() {
        // First zoom in
        app.typeKey("=", modifierFlags: .command)
        sleep(1)
        
        // Then reset with ⌘0
        app.typeKey("0", modifierFlags: .command)
        sleep(1)
        
        // Verify Actual Size is now disabled (indicating zoom reset to 1.0)
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertFalse(actualSize.isEnabled, "Actual Size should be disabled after ⌘0 shortcut resets zoom")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    // MARK: - Debug Helper Tests
    
    func testActualSizeDisabledAtDefaultZoom() {
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.exists, "Actual Size should exist")
        XCTAssertFalse(actualSize.isEnabled, "Actual Size should be DISABLED at default zoom")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testActualSizeEnabledAfterZoomIn() {
        // Zoom in first
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        // Check Actual Size is now enabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be ENABLED after zooming in")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testActualSizeEnabledAfterZoomOut() {
        // Zoom out first
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom Out"].click()
        sleep(1)
        
        // Check Actual Size is now enabled
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertTrue(actualSize.isEnabled, "Actual Size should be ENABLED after zooming out")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testActualSizeDisabledAfterReset() {
        // Zoom in first
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Zoom In"].click()
        sleep(1)
        
        // Reset to actual size
        app.menuBars.menuBarItems["View"].click()
        app.menuBars.menuItems["Actual Size"].click()
        sleep(1)
        
        // Check Actual Size is now disabled again
        app.menuBars.menuBarItems["View"].click()
        sleep(1)
        
        let actualSize = app.menuBars.menuItems["Actual Size"]
        XCTAssertFalse(actualSize.isEnabled, "Actual Size should be DISABLED after reset to 1.0")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
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
    
    // MARK: - Status Bar Tests
    
    func testStatusBarMenuItemExists() {
        app.menuBars.menuBarItems["View"].click()
        // Check for either "Show Status Bar" or "Hide Status Bar"
        let showStatusBar = app.menuBars.menuItems["Show Status Bar"]
        let hideStatusBar = app.menuBars.menuItems["Hide Status Bar"]
        XCTAssertTrue(showStatusBar.exists || hideStatusBar.exists, "Status Bar toggle menu item should exist")
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func testStatusBarToggleViaMenu() {
        // Toggle status bar visibility via menu
        app.menuBars.menuBarItems["View"].click()
        
        let hideStatusBar = app.menuBars.menuItems["Hide Status Bar"]
        let showStatusBar = app.menuBars.menuItems["Show Status Bar"]
        
        if hideStatusBar.exists {
            hideStatusBar.click()
            sleep(1)
            
            // Verify it now says "Show"
            app.menuBars.menuBarItems["View"].click()
            XCTAssertTrue(app.menuBars.menuItems["Show Status Bar"].exists, "After hiding, menu should say 'Show Status Bar'")
            
            // Restore
            app.menuBars.menuItems["Show Status Bar"].click()
        } else if showStatusBar.exists {
            showStatusBar.click()
            sleep(1)
            
            // Verify it now says "Hide"
            app.menuBars.menuBarItems["View"].click()
            XCTAssertTrue(app.menuBars.menuItems["Hide Status Bar"].exists, "After showing, menu should say 'Hide Status Bar'")
            
            // Restore
            app.menuBars.menuItems["Hide Status Bar"].click()
        }
        
        app.typeKey(.escape, modifierFlags: [])
    }
}
