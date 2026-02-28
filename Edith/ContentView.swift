//
//  ContentView.swift
//  Edith
//

import SwiftUI

// FocusedValue for per-document zoom and font size adjustments
struct DocumentZoomKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

struct DocumentFontSizeKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var documentZoom: Binding<Double>? {
        get { self[DocumentZoomKey.self] }
        set { self[DocumentZoomKey.self] = newValue }
    }
    
    var documentFontSize: Binding<Double>? {
        get { self[DocumentFontSizeKey.self] }
        set { self[DocumentFontSizeKey.self] = newValue }
    }
}

struct ContentView: View {
    @Binding var document: TextDocument
    @EnvironmentObject var settingsManager: SettingsManager
    
    // Per-document overrides (not persisted)
    @State private var documentZoom: Double = 1.0
    @State private var documentFontSizeOffset: Double = 0.0
    
    var body: some View {
        EditorView(text: $document.text, documentZoom: documentZoom, documentFontSizeOffset: documentFontSizeOffset)
            .environmentObject(settingsManager)
            .focusedSceneValue(\.documentZoom, $documentZoom)
            .focusedSceneValue(\.documentFontSize, $documentFontSizeOffset)
    }
}
