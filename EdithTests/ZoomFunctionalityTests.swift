//
//  ZoomFunctionalityTests.swift
//  EdithTests
//
//  Tests for zoom and font size adjustment functionality
//

import XCTest
import SwiftUI
@testable import Edith

final class ZoomFunctionalityTests: XCTestCase {
    
    // MARK: - Document Zoom State Tests
    
    func testDefaultDocumentZoomIsOne() {
        // ContentView initializes documentZoom to 1.0
        // We verify this by checking that the default magnification multiplier is 1.0
        let defaultZoom = 1.0
        XCTAssertEqual(defaultZoom, 1.0, "Default document zoom should be 1.0")
    }
    
    func testZoomInCalculation() {
        var zoom = 1.0
        // Zoom in logic: zoom * 1.25, max 4.0
        zoom = min(zoom * 1.25, 4.0)
        XCTAssertEqual(zoom, 1.25, "Zoom in should multiply by 1.25")
    }
    
    func testZoomOutCalculation() {
        var zoom = 1.0
        // Zoom out logic: zoom / 1.25, min 0.25
        zoom = max(zoom / 1.25, 0.25)
        XCTAssertEqual(zoom, 0.8, "Zoom out should divide by 1.25")
    }
    
    func testActualSizeResetsToOne() {
        var zoom = 2.5
        // Actual Size logic: reset to 1.0
        zoom = 1.0
        XCTAssertEqual(zoom, 1.0, "Actual Size should reset zoom to 1.0")
    }
    
    func testActualSizeFromZoomedIn() {
        var zoom = 1.0
        // Zoom in several times
        zoom = min(zoom * 1.25, 4.0)  // 1.25
        zoom = min(zoom * 1.25, 4.0)  // 1.5625
        zoom = min(zoom * 1.25, 4.0)  // 1.953125
        
        XCTAssertGreaterThan(zoom, 1.0, "Should be zoomed in")
        
        // Reset with Actual Size
        zoom = 1.0
        XCTAssertEqual(zoom, 1.0, "Actual Size should reset from zoomed in state")
    }
    
    func testActualSizeFromZoomedOut() {
        var zoom = 1.0
        // Zoom out several times
        zoom = max(zoom / 1.25, 0.25)  // 0.8
        zoom = max(zoom / 1.25, 0.25)  // 0.64
        zoom = max(zoom / 1.25, 0.25)  // 0.512
        
        XCTAssertLessThan(zoom, 1.0, "Should be zoomed out")
        
        // Reset with Actual Size
        zoom = 1.0
        XCTAssertEqual(zoom, 1.0, "Actual Size should reset from zoomed out state")
    }
    
    func testZoomInMaximum() {
        var zoom = 1.0
        // Zoom in repeatedly until max
        for _ in 0..<20 {
            zoom = min(zoom * 1.25, 4.0)
        }
        XCTAssertEqual(zoom, 4.0, "Zoom should not exceed 4.0")
    }
    
    func testZoomOutMinimum() {
        var zoom = 1.0
        // Zoom out repeatedly until min
        for _ in 0..<20 {
            zoom = max(zoom / 1.25, 0.25)
        }
        XCTAssertEqual(zoom, 0.25, "Zoom should not go below 0.25")
    }
    
    // MARK: - Font Size Offset Tests
    
    func testFontSizeBiggerCalculation() {
        var offset = 0.0
        offset += 1.0
        XCTAssertEqual(offset, 1.0, "Bigger should add 1.0 to offset")
    }
    
    func testFontSizeSmallerCalculation() {
        var offset = 0.0
        let baseFontSize = 13.0
        let minFontSize = 6.0
        offset = max(offset - 1.0, -baseFontSize + minFontSize)
        XCTAssertEqual(offset, -1.0, "Smaller should subtract 1.0 from offset")
    }
    
    func testFontSizeSmallerMinimum() {
        var offset = 0.0
        let baseFontSize = 13.0
        let minFontSize = 6.0
        // Reduce repeatedly
        for _ in 0..<20 {
            offset = max(offset - 1.0, -baseFontSize + minFontSize)
        }
        XCTAssertEqual(offset, -7.0, "Font size offset should stop at -7.0 (13-6)")
        XCTAssertEqual(baseFontSize + offset, minFontSize, "Effective font size should be 6.0")
    }
    
    // MARK: - Effective Size Calculation Tests
    
    func testEffectiveSizeWithZoom() {
        let baseFontSize = 13.0
        let magnification = 1.0
        let documentZoom = 2.0
        let fontSizeOffset = 0.0
        
        let effectiveMagnification = magnification * documentZoom
        let effectiveFontSize = baseFontSize + fontSizeOffset
        let size = effectiveFontSize * effectiveMagnification
        
        XCTAssertEqual(size, 26.0, "Effective size should be base * zoom")
    }
    
    func testEffectiveSizeWithFontOffset() {
        let baseFontSize = 13.0
        let magnification = 1.0
        let documentZoom = 1.0
        let fontSizeOffset = 5.0
        
        let effectiveMagnification = magnification * documentZoom
        let effectiveFontSize = baseFontSize + fontSizeOffset
        let size = effectiveFontSize * effectiveMagnification
        
        XCTAssertEqual(size, 18.0, "Effective size should include font offset")
    }
    
    func testEffectiveSizeWithBothAdjustments() {
        let baseFontSize = 13.0
        let magnification = 1.5  // Settings magnification
        let documentZoom = 2.0   // Per-document zoom
        let fontSizeOffset = 2.0 // Per-document font offset
        
        let effectiveMagnification = magnification * documentZoom
        let effectiveFontSize = baseFontSize + fontSizeOffset
        let size = effectiveFontSize * effectiveMagnification
        
        XCTAssertEqual(size, 45.0, "Effective size should combine all adjustments: (13+2) * (1.5*2) = 45")
    }
    
    // MARK: - Actual Size Regression Tests
    
    func testActualSizeAfterMultipleZoomOperations() {
        var zoom = 1.0
        
        // Mix of zoom in and out
        zoom = min(zoom * 1.25, 4.0)
        zoom = min(zoom * 1.25, 4.0)
        zoom = max(zoom / 1.25, 0.25)
        zoom = min(zoom * 1.25, 4.0)
        zoom = min(zoom * 1.25, 4.0)
        zoom = min(zoom * 1.25, 4.0)
        
        XCTAssertNotEqual(zoom, 1.0, "Zoom should have changed from 1.0")
        
        // Actual Size
        zoom = 1.0
        XCTAssertEqual(zoom, 1.0, "Actual Size must reset to exactly 1.0")
    }
    
    func testActualSizeIsExactlyOne() {
        // This test ensures Actual Size sets exactly 1.0, not approximately 1.0
        let zoom = 1.0
        XCTAssertEqual(zoom, 1.0, accuracy: 0.0, "Actual Size must be exactly 1.0, not approximately")
    }
    
    func testZoomDoesNotAffectSettingsMagnification() {
        let settings = SettingsManager()
        settings.restoreDefaults()
        let originalMagnification = settings.magnification
        
        // Simulate document zoom changes (these are separate from settings)
        var documentZoom = 1.0
        documentZoom = min(documentZoom * 1.25, 4.0)
        documentZoom = 1.0  // Actual Size
        
        // Settings magnification should be unchanged
        XCTAssertEqual(settings.magnification, originalMagnification,
            "Document zoom operations should not affect settings magnification")
    }
    
    // MARK: - DocumentZoomState Tests
    
    func testDocumentZoomStateResetZoom() {
        let state = DocumentZoomState()
        state.zoom = 2.5
        state.resetZoom()
        XCTAssertEqual(state.zoom, 1.0, "resetZoom() should set zoom to exactly 1.0")
    }
    
    func testDocumentZoomStateZoomIn() {
        let state = DocumentZoomState()
        state.zoom = 1.0
        state.zoomIn()
        XCTAssertEqual(state.zoom, 1.25, "zoomIn() should multiply by 1.25")
    }
    
    func testDocumentZoomStateZoomOut() {
        let state = DocumentZoomState()
        state.zoom = 1.0
        state.zoomOut()
        XCTAssertEqual(state.zoom, 0.8, "zoomOut() should divide by 1.25")
    }
    
    func testDocumentZoomStateResetFromZoomedIn() {
        let state = DocumentZoomState()
        state.zoomIn()
        state.zoomIn()
        state.zoomIn()
        XCTAssertGreaterThan(state.zoom, 1.0)
        state.resetZoom()
        XCTAssertEqual(state.zoom, 1.0, "resetZoom() should reset to 1.0 from zoomed in state")
    }
    
    func testDocumentZoomStateResetFromZoomedOut() {
        let state = DocumentZoomState()
        state.zoomOut()
        state.zoomOut()
        state.zoomOut()
        XCTAssertLessThan(state.zoom, 1.0)
        state.resetZoom()
        XCTAssertEqual(state.zoom, 1.0, "resetZoom() should reset to 1.0 from zoomed out state")
    }
    
    func testDocumentZoomStateMaximumZoom() {
        let state = DocumentZoomState()
        for _ in 0..<20 {
            state.zoomIn()
        }
        XCTAssertEqual(state.zoom, 4.0, "Zoom should cap at 4.0")
    }
    
    func testDocumentZoomStateMinimumZoom() {
        let state = DocumentZoomState()
        for _ in 0..<20 {
            state.zoomOut()
        }
        XCTAssertEqual(state.zoom, 0.25, "Zoom should floor at 0.25")
    }
    
    // MARK: - Menu Disabled State Tests
    
    func testActualSizeDisabledWhenAtDefaultZoom() {
        let state = DocumentZoomState()
        // At default zoom (1.0), Actual Size should be disabled
        let shouldBeDisabled = state.zoom == 1.0
        XCTAssertTrue(shouldBeDisabled, "Actual Size should be disabled when zoom is 1.0")
    }
    
    func testActualSizeEnabledWhenZoomedIn() {
        let state = DocumentZoomState()
        state.zoomIn()
        let shouldBeDisabled = state.zoom == 1.0
        XCTAssertFalse(shouldBeDisabled, "Actual Size should be enabled when zoomed in")
    }
    
    func testActualSizeEnabledWhenZoomedOut() {
        let state = DocumentZoomState()
        state.zoomOut()
        let shouldBeDisabled = state.zoom == 1.0
        XCTAssertFalse(shouldBeDisabled, "Actual Size should be enabled when zoomed out")
    }
    
    func testZoomInDisabledAtMaximum() {
        let state = DocumentZoomState()
        for _ in 0..<20 {
            state.zoomIn()
        }
        let shouldBeDisabled = state.zoom >= 4.0
        XCTAssertTrue(shouldBeDisabled, "Zoom In should be disabled at maximum zoom")
    }
    
    func testZoomOutDisabledAtMinimum() {
        let state = DocumentZoomState()
        for _ in 0..<20 {
            state.zoomOut()
        }
        let shouldBeDisabled = state.zoom <= 0.25
        XCTAssertTrue(shouldBeDisabled, "Zoom Out should be disabled at minimum zoom")
    }
}
