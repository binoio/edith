//
//  SettingsPersistenceTests.swift
//  EdithTests
//
//  Tests to verify that settings persist across app relaunches via @AppStorage
//

import XCTest
@testable import Edith

final class SettingsPersistenceTests: XCTestCase {
    
    let testSuiteName = "com.edith.test.persistence"
    var testDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use a separate UserDefaults suite for testing
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults?.removePersistentDomain(forName: testSuiteName)
    }
    
    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: testSuiteName)
        super.tearDown()
    }
    
    // MARK: - Magnification Persistence Tests
    
    func testMagnificationPersistsThroughSimulatedRelaunch() {
        // Simulate first app session - set magnification
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        let customMagnification = 2.5
        settings1.magnification = customMagnification
        
        // Simulate app relaunch by creating new SettingsManager
        let settings2 = SettingsManager()
        
        XCTAssertEqual(settings2.magnification, customMagnification,
            "Magnification should persist through app relaunch")
    }
    
    func testMagnificationPersistsAfterChangingOtherSettings() {
        let settings = SettingsManager()
        settings.restoreDefaults()
        
        // Set magnification
        settings.magnification = 1.75
        
        // Change other settings
        settings.fontSize = 18.0
        settings.fontName = "Courier"
        settings.showInvisibleCharacters = true
        
        // Simulate relaunch
        let settings2 = SettingsManager()
        
        XCTAssertEqual(settings2.magnification, 1.75,
            "Magnification should persist even after other settings changed")
    }
    
    func testMagnificationPersistsAtMinimumValue() {
        let settings = SettingsManager()
        settings.magnification = 0.5
        
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.magnification, 0.5,
            "Minimum magnification value should persist")
    }
    
    func testMagnificationPersistsAtMaximumValue() {
        let settings = SettingsManager()
        settings.magnification = 4.0
        
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.magnification, 4.0,
            "Maximum magnification value should persist")
    }
    
    // MARK: - Font Size Persistence Tests
    
    func testFontSizePersistsThroughSimulatedRelaunch() {
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        let customFontSize = 18.0
        settings1.fontSize = customFontSize
        
        let settings2 = SettingsManager()
        
        XCTAssertEqual(settings2.fontSize, customFontSize,
            "Font size should persist through app relaunch")
    }
    
    func testFontSizePersistsAfterChangingOtherSettings() {
        let settings = SettingsManager()
        settings.restoreDefaults()
        
        settings.fontSize = 24.0
        
        // Change other settings
        settings.magnification = 1.5
        settings.showLineNumbers = false
        settings.spacesPerTab = 2
        
        let settings2 = SettingsManager()
        
        XCTAssertEqual(settings2.fontSize, 24.0,
            "Font size should persist even after other settings changed")
    }
    
    func testFontSizePersistsAtSmallValue() {
        let settings = SettingsManager()
        settings.fontSize = 8.0
        
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.fontSize, 8.0,
            "Small font size should persist")
    }
    
    func testFontSizePersistsAtLargeValue() {
        let settings = SettingsManager()
        settings.fontSize = 72.0
        
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.fontSize, 72.0,
            "Large font size should persist")
    }
    
    // MARK: - Line Height Persistence Tests

    func testLineHeightDefaultsToSingleSpacing() {
        let settings = SettingsManager()
        settings.restoreDefaults()

        XCTAssertEqual(settings.lineHeightMultiple, 1.0,
            "Line height should default to 1.0 (single spacing)")
    }

    func testLineHeightPersistsThroughSimulatedRelaunch() {
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        settings1.lineHeightMultiple = 1.5

        let settings2 = SettingsManager()

        XCTAssertEqual(settings2.lineHeightMultiple, 1.5,
            "Line height should persist through app relaunch")
    }

    func testLineHeightPersistsAfterChangingOtherSettings() {
        let settings = SettingsManager()
        settings.restoreDefaults()

        settings.lineHeightMultiple = 1.2
        settings.fontSize = 18.0
        settings.magnification = 1.5

        let settings2 = SettingsManager()

        XCTAssertEqual(settings2.lineHeightMultiple, 1.2, accuracy: 0.001,
            "Line height should persist even after other settings changed")
    }

    func testLineHeightResetsWithRestoreDefaults() {
        let settings1 = SettingsManager()
        settings1.lineHeightMultiple = 2.0

        settings1.restoreDefaults()

        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.lineHeightMultiple, SettingsManager.defaultLineHeightMultiple,
            "Line height should reset to default with Restore Defaults")
    }

    // MARK: - Combined Persistence Tests
    
    func testBothMagnificationAndFontSizePersist() {
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        settings1.magnification = 2.0
        settings1.fontSize = 16.0
        
        let settings2 = SettingsManager()
        
        XCTAssertEqual(settings2.magnification, 2.0,
            "Magnification should persist when both are changed")
        XCTAssertEqual(settings2.fontSize, 16.0,
            "Font size should persist when both are changed")
    }
    
    func testSettingsPersistAfterRestoreDefaults() {
        let settings1 = SettingsManager()
        settings1.magnification = 3.0
        settings1.fontSize = 20.0
        
        // Restore defaults
        settings1.restoreDefaults()
        
        // Verify defaults are now stored
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.magnification, SettingsManager.defaultMagnification,
            "Default magnification should persist after restoreDefaults")
        XCTAssertEqual(settings2.fontSize, SettingsManager.defaultFontSize,
            "Default font size should persist after restoreDefaults")
    }
    
    func testMultipleSettingsChangesPersist() {
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        
        // Make multiple changes
        settings1.magnification = 1.5
        settings1.magnification = 2.0
        settings1.magnification = 1.25
        
        settings1.fontSize = 14.0
        settings1.fontSize = 16.0
        settings1.fontSize = 15.0
        
        // Only final values should persist
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.magnification, 1.25,
            "Final magnification value should persist")
        XCTAssertEqual(settings2.fontSize, 15.0,
            "Final font size value should persist")
    }
    
    // MARK: - Edge Cases
    
    func testSettingsPersistWithDecimalPrecision() {
        let settings1 = SettingsManager()
        settings1.magnification = 1.333
        settings1.fontSize = 13.5
        
        let settings2 = SettingsManager()
        XCTAssertEqual(settings2.magnification, 1.333, accuracy: 0.001,
            "Decimal magnification should persist with precision")
        XCTAssertEqual(settings2.fontSize, 13.5, accuracy: 0.001,
            "Decimal font size should persist with precision")
    }
    
    func testIndependentSettingsPersistence() {
        // Change magnification only
        let settings1 = SettingsManager()
        settings1.restoreDefaults()
        settings1.magnification = 2.0
        
        // In new "session", change font size only
        let settings2 = SettingsManager()
        settings2.fontSize = 20.0
        
        // Both should persist
        let settings3 = SettingsManager()
        XCTAssertEqual(settings3.magnification, 2.0,
            "Magnification from first session should persist")
        XCTAssertEqual(settings3.fontSize, 20.0,
            "Font size from second session should persist")
    }
}
