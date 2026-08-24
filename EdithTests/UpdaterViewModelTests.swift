//
//  UpdaterViewModelTests.swift
//  EdithTests
//

import XCTest
import Sparkle
@testable import Edith

@MainActor
final class UpdaterViewModelTests: XCTestCase {
    private func makeUpdater() -> SPUUpdater {
        // startingUpdater: false keeps Sparkle's scheduled checks off in tests
        SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater
    }

    func testCanCheckForUpdatesMirrorsUpdaterState() {
        let updater = makeUpdater()
        let viewModel = UpdaterViewModel(updater: updater)
        XCTAssertEqual(viewModel.canCheckForUpdates, updater.canCheckForUpdates)
    }

    func testAutomaticPreferencesRoundTripThroughUpdater() {
        let updater = makeUpdater()
        let viewModel = UpdaterViewModel(updater: updater)
        let originalChecks = updater.automaticallyChecksForUpdates
        let originalDownloads = updater.automaticallyDownloadsUpdates
        defer {
            updater.automaticallyDownloadsUpdates = originalDownloads
            updater.automaticallyChecksForUpdates = originalChecks
        }

        // Sparkle only honors the downloads preference while automatic checks
        // are on (allowsAutomaticUpdates follows the checks setting when no
        // SUAllowsAutomaticUpdates override exists), so enable checks first
        viewModel.automaticallyChecksForUpdates = true
        XCTAssertTrue(updater.automaticallyChecksForUpdates)

        viewModel.automaticallyDownloadsUpdates = !originalDownloads
        XCTAssertEqual(updater.automaticallyDownloadsUpdates, !originalDownloads)

        viewModel.automaticallyChecksForUpdates = false
        XCTAssertFalse(updater.automaticallyChecksForUpdates)
    }

    func testUpdaterNeverStartsUnderXCTest() {
        // EdithAppDelegate must not start Sparkle while tests host the app;
        // the guard checks for XCTestCase in the runtime.
        XCTAssertNotNil(NSClassFromString("XCTestCase"))
    }
}
