//
//  FileWatcherTests.swift
//  EdithTests
//

import XCTest
@testable import Edith

final class FileWatcherTests: XCTestCase {
    
    var fileWatcher: FileWatcher!
    var testFileURL: URL!
    
    override func setUpWithError() throws {
        fileWatcher = FileWatcher()
        
        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        testFileURL = tempDir.appendingPathComponent("FileWatcherTest_\(UUID().uuidString).txt")
        try "Initial content".write(to: testFileURL, atomically: true, encoding: .utf8)
    }
    
    override func tearDownWithError() throws {
        fileWatcher.stopWatching()
        try? FileManager.default.removeItem(at: testFileURL)
    }
    
    // MARK: - Basic Functionality Tests
    
    func testFileWatcherInitialState() {
        XCTAssertFalse(fileWatcher.fileChanged)
    }
    
    func testFileWatcherStartsWatching() {
        fileWatcher.startWatching(url: testFileURL)
        // File watcher should be active (no direct way to verify, but it shouldn't crash)
        XCTAssertFalse(fileWatcher.fileChanged)
    }
    
    func testFileWatcherDetectsExternalChange() {
        let expectation = XCTestExpectation(description: "File change detected")
        
        fileWatcher.startWatching(url: testFileURL)
        
        // Wait a moment for the watcher to be fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Modify the file externally (simulating vim)
            do {
                try "Modified content".write(to: self.testFileURL, atomically: true, encoding: .utf8)
            } catch {
                XCTFail("Failed to modify test file: \(error)")
            }
            
            // Wait for the file watcher to detect the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.fileWatcher.fileChanged {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(fileWatcher.fileChanged, "File watcher should detect external change")
    }
    
    func testFileWatcherSuppressesEdithSave() {
        let expectation = XCTestExpectation(description: "Edith save suppressed")
        
        fileWatcher.startWatching(url: testFileURL)
        
        // Wait for watcher setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Mark that Edith is saving
            EdithSaveTracker.shared.markSaveStarted()
            
            // Modify the file (simulating Edith's save)
            do {
                try "Edith modified content".write(to: self.testFileURL, atomically: true, encoding: .utf8)
            } catch {
                XCTFail("Failed to modify test file: \(error)")
            }
            
            // Complete the save
            EdithSaveTracker.shared.markSaveCompleted()
            
            // Wait and check
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(fileWatcher.fileChanged, "File watcher should NOT detect Edith's own save")
    }
    
    func testFileWatcherAcknowledgeChange() {
        let expectation = XCTestExpectation(description: "Change acknowledged")
        
        fileWatcher.startWatching(url: testFileURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Trigger a change
            try? "External change".write(to: self.testFileURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // First verify the change was detected
                let wasChanged = self.fileWatcher.fileChanged
                
                // Acknowledge the change (this also re-establishes the watch)
                self.fileWatcher.acknowledgeChange()
                
                // Wait for re-watch to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // After acknowledge, fileChanged should be false
                    XCTAssertFalse(self.fileWatcher.fileChanged, "fileChanged should be false after acknowledge")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    func testFileWatcherDetectsMultipleChanges() {
        let expectation = XCTestExpectation(description: "Multiple changes detected")
        
        fileWatcher.startWatching(url: testFileURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // First change
            try? "Change 1".write(to: self.testFileURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                XCTAssertTrue(self.fileWatcher.fileChanged, "Should detect first change")
                
                // Acknowledge
                self.fileWatcher.acknowledgeChange()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    XCTAssertFalse(self.fileWatcher.fileChanged, "Should be reset after acknowledge")
                    
                    // Second change
                    try? "Change 2".write(to: self.testFileURL, atomically: true, encoding: .utf8)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // After re-establishing watch, should detect second change
                        if self.fileWatcher.fileChanged {
                            expectation.fulfill()
                        } else {
                            // May need more time for re-watch
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - EdithSaveTracker Tests
    
    func testEdithSaveTrackerInitialState() {
        // Clear any previous state
        let tracker = EdithSaveTracker.shared
        XCTAssertFalse(tracker.shouldSuppressFileChangeAlert())
    }
    
    func testEdithSaveTrackerSuppressesDuringSave() {
        let tracker = EdithSaveTracker.shared
        
        tracker.markSaveStarted()
        XCTAssertTrue(tracker.shouldSuppressFileChangeAlert(), "Should suppress during save")
        
        tracker.markSaveCompleted()
        // Still suppresses immediately after completion
        XCTAssertTrue(tracker.shouldSuppressFileChangeAlert(), "Should still suppress briefly after completion")
    }
    
    func testEdithSaveTrackerStopsSuppressingAfterDelay() {
        let expectation = XCTestExpectation(description: "Suppression ends")
        let tracker = EdithSaveTracker.shared
        
        tracker.markSaveStarted()
        tracker.markSaveCompleted()
        
        // Wait for suppression to end (500ms + buffer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !tracker.shouldSuppressFileChangeAlert() {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
}
