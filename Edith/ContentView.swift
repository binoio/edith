//
//  ContentView.swift
//  Edith
//

import SwiftUI

// Observable wrapper for per-document zoom state
class DocumentZoomState: ObservableObject {
    @Published var zoom: Double = 1.0
    @Published var fontSizeOffset: Double = 0.0
    
    func resetZoom() {
        zoom = 1.0
    }
    
    func zoomIn() {
        zoom = min(zoom * 1.25, 4.0)
    }
    
    func zoomOut() {
        zoom = max(zoom / 1.25, 0.25)
    }
    
    func increaseFontSize() {
        fontSizeOffset += 1.0
    }
    
    func decreaseFontSize(minOffset: Double) {
        fontSizeOffset = max(fontSizeOffset - 1.0, minOffset)
    }
}

// FocusedValue for per-document zoom state
struct DocumentZoomStateKey: FocusedValueKey {
    typealias Value = DocumentZoomState
}

extension FocusedValues {
    var documentZoomState: DocumentZoomState? {
        get { self[DocumentZoomStateKey.self] }
        set { self[DocumentZoomStateKey.self] = newValue }
    }
}

struct ContentView: View {
    @Binding var document: TextDocument
    @EnvironmentObject var settingsManager: SettingsManager
    
    // Per-document state (not persisted)
    @StateObject private var zoomState = DocumentZoomState()
    
    var body: some View {
        EditorView(text: $document.text, zoomState: zoomState)
            .environmentObject(settingsManager)
            .focusedSceneValue(\.documentZoomState, zoomState)
    }
}
