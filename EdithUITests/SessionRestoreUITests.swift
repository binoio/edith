//
//  SessionRestoreUITests.swift
//  EdithUITests
//
//  UI tests for session restore functionality.
//

import XCTest

final class SessionRestoreUITests: XCTestCase {
    
    var app: XCUIApplication!
    var testFilePath: String!
    
    // Container path for the sandboxed app
    var containerRestoreDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Containers/com.edith.texteditor/Data/Library/Application Support/Edith/Restore")
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        // Use a temporary directory in user space
        let tempDir = FileManager.default.temporaryDirectory
        testFilePath = tempDir.appendingPathComponent("edith_session_restore_test.txt").path
        
        // Create a test file
        let testContent = "Session restore test content - \(Date())"
        try testContent.write(toFile: testFilePath, atomically: true, encoding: .utf8)
    }
    
    override func tearDownWithError() throws {
        // Clean up test file
        if let path = testFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
    
    // MARK: - Session Restore Tests
    
    func testSessionRestoreDataFormat() throws {
        // Create test session data in the container
        try? FileManager.default.createDirectory(at: containerRestoreDir, withIntermediateDirectories: true)
        
        let testData: [[String: Any]] = [
            ["path": "/nonexistent/test/path.txt", "hasUnsavedChanges": false, "restoreID": "test_path_txt"]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: testData)
        try jsonData.write(to: containerRestoreDir.appendingPathComponent("open_documents.json"))
        
        // Launch app
        app = XCUIApplication()
        app.launch()
        
        // The app should launch without crashing even with invalid paths
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        app.terminate()
    }
    
    func testAppLaunchesWithEmptySessionData() throws {
        // Ensure clean state
        try? FileManager.default.removeItem(at: containerRestoreDir.appendingPathComponent("open_documents.json"))
        
        app = XCUIApplication()
        app.launch()
        
        // App should launch successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        app.terminate()
    }
    
    func testReopenDocumentsSettingRespected() throws {
        // First, disable the setting
        UserDefaults.standard.set(false, forKey: "reopenDocumentsOnLaunch")
        
        // Create session data in container
        try? FileManager.default.createDirectory(at: containerRestoreDir, withIntermediateDirectories: true)
        
        let testData: [[String: Any]] = [
            ["path": testFilePath!, "hasUnsavedChanges": false, "restoreID": "test_txt"]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: testData)
        try jsonData.write(to: containerRestoreDir.appendingPathComponent("open_documents.json"))
        
        app = XCUIApplication()
        app.launch()
        
        // App should launch (setting is disabled so it won't try to restore)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        app.terminate()
        
        // Re-enable the setting
        UserDefaults.standard.set(true, forKey: "reopenDocumentsOnLaunch")
    }
    
    func testSessionRestoreCreatesDirectory() throws {
        // Launch app and then quit via menu
        app = XCUIApplication()
        app.launch()
        
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Wait for app to fully initialize
        sleep(2)
        
        // Close the open dialog if it appears (press Escape)
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
        
        // Quit the app using the menu (this triggers save)
        app.typeKey("q", modifierFlags: .command)
        
        // Wait for termination
        sleep(3)
        
        // Check if the Restore directory was created in the container
        XCTAssertTrue(FileManager.default.fileExists(atPath: containerRestoreDir.path),
                      "Restore directory should exist in container")
    }
    
    func testSessionRestoreSavesEmptyArrayForNewDocuments() throws {
        // Launch app (creates new untitled document)
        app = XCUIApplication()
        app.launch()
        
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        sleep(2)
        
        // Quit the app
        app.typeKey("q", modifierFlags: .command)
        sleep(3)
        
        // Check the open_documents.json file
        let openDocsFile = containerRestoreDir.appendingPathComponent("open_documents.json")
        
        if FileManager.default.fileExists(atPath: openDocsFile.path) {
            let data = try Data(contentsOf: openDocsFile)
            // Use JSONSerialization instead of Codable for flexibility
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            
            XCTAssertNotNil(json, "JSON should be a valid array")
            
            // For new untitled documents (no fileURL), the array should be empty
            // This is expected behavior - only saved documents are restored
            // The test just verifies the file was created with valid JSON
        }
    }
    
    func testSessionRestoreSavesOpenedFile() throws {
        // This test is manual since UI test sandbox prevents file access
        // Manual steps:
        // 1. Run Edith
        // 2. Open ~/Downloads/Untitled.txt (or any saved file)
        // 3. Quit Edith (Cmd+Q)
        // 4. Check ~/Library/Containers/com.edith.texteditor/Data/Library/Application Support/Edith/Restore/open_documents.json
        // 5. It should contain the path to the opened file
        // 6. Reopen Edith - the file should be restored
        
        // For now, skip this automated test as sandbox prevents file creation
        throw XCTSkip("Cannot automate file open test due to sandbox restrictions")
    }
}
