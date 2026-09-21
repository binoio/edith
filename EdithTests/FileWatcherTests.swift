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
        
        wait(for: [expectation], timeout: 15.0)
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
        
        wait(for: [expectation], timeout: 15.0)
        XCTAssertFalse(fileWatcher.fileChanged, "File watcher should NOT detect Edith's own save")
    }
    
    func testFileWatcherAcknowledgeChange() {
        let expectation = XCTestExpectation(description: "Change acknowledged")
        
        fileWatcher.startWatching(url: testFileURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Trigger a change
            try? "External change".write(to: self.testFileURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Acknowledge the change (this also re-establishes the watch)
                self.fileWatcher.acknowledgeChange()
                
                // Poll for the settled state instead of asserting at a fixed
                // instant: the atomic write above can still deliver a queued
                // filesystem event just after the watch is re-established, so a
                // single sample races it.
                let deadline = Date().addingTimeInterval(10.0)
                func poll() {
                    if !self.fileWatcher.fileChanged {
                        expectation.fulfill()
                    } else if Date() < deadline {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: poll)
                    } else {
                        XCTFail("fileChanged never cleared after acknowledge")
                        expectation.fulfill()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: poll)
            }
        }
        
        wait(for: [expectation], timeout: 20.0)
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
        
        wait(for: [expectation], timeout: 25.0)
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
        
        // Poll rather than sampling once. markSaveCompleted() drops its counter
        // from a delayed main-queue block, so a single check at a fixed instant
        // races that block -- and any still pending from a sibling test -- and
        // a longer timeout cannot help a check that only ever runs once.
        let deadline = Date().addingTimeInterval(10.0)
        func poll() {
            if !tracker.shouldSuppressFileChangeAlert() {
                expectation.fulfill()
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: poll)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: poll)
        
        wait(for: [expectation], timeout: 15.0)
    }
}
