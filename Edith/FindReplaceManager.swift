//
//  FindReplaceManager.swift
//  Edith
//
//  Singleton manager to track the active document's FindReplaceState.
//  This solves the focus problem where FocusedSceneValue becomes nil
//  when the Find & Replace window is active.
//

import SwiftUI
import Combine

/// Represents a document that can be searched
struct DocumentInfo: Identifiable, Hashable {
    let id: ObjectIdentifier
    let name: String
    let state: FindReplaceState
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DocumentInfo, rhs: DocumentInfo) -> Bool {
        lhs.id == rhs.id
    }
}

/// Global manager for Find & Replace functionality.
/// Documents register/unregister their FindReplaceState when becoming active/inactive.
@MainActor
final class FindReplaceManager: ObservableObject {
    static let shared = FindReplaceManager()
    
    /// The currently selected document's find/replace state
    @Published var activeState: FindReplaceState?
    
    /// All registered documents (for the dropdown)
    @Published private(set) var documents: [DocumentInfo] = []
    
    // Shared search parameters (persist across document switches)
    @Published var findText: String = ""
    @Published var replaceText: String = ""
    @Published var caseSensitive: Bool = false
    @Published var usePCRE: Bool = false
    @Published var wrapAround: Bool = true
    
    /// Tracks which state is currently registered with document names
    private var registeredStates: [ObjectIdentifier: (state: FindReplaceState, name: String)] = [:]
    
    private init() {}
    
    /// Sync shared parameters to active state and perform search
    func syncAndSearch() {
        guard let state = activeState else { return }
        state.findText = findText
        state.replaceText = replaceText
        state.caseSensitive = caseSensitive
        state.usePCRE = usePCRE
        state.wrapAround = wrapAround
        state.performSearch()
    }
    
    /// Called when a document window becomes key (focused)
    func registerActiveState(_ state: FindReplaceState, documentName: String = "Untitled") {
        let id = ObjectIdentifier(state)
        registeredStates[id] = (state, documentName)
        updateDocumentsList()
        activeState = state
        // Sync search parameters to new active state
        syncAndSearch()
    }
    
    /// Update document name (e.g., after save)
    func updateDocumentName(_ state: FindReplaceState, name: String) {
        let id = ObjectIdentifier(state)
        if registeredStates[id] != nil {
            registeredStates[id] = (state, name)
            updateDocumentsList()
        }
    }
    
    /// Called when a document window is closed
    func unregisterState(_ state: FindReplaceState) {
        let id = ObjectIdentifier(state)
        registeredStates.removeValue(forKey: id)
        updateDocumentsList()
        
        // If this was the active state, select first available or nil
        if activeState === state {
            activeState = documents.first?.state
        }
    }
    
    /// Select a specific document by its state
    func selectDocument(_ state: FindReplaceState) {
        activeState = state
        syncAndSearch()
    }
    
    /// Ensure we have an active state (called when Find & Replace window opens)
    func ensureActiveState() {
        if activeState == nil, let first = documents.first {
            activeState = first.state
        }
    }
    
    private func updateDocumentsList() {
        documents = registeredStates.map { (id, value) in
            DocumentInfo(id: id, name: value.name, state: value.state)
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Actions that delegate to active state
    
    func findNext() {
        activeState?.findNext()
    }
    
    func findPrevious() {
        activeState?.findPrevious()
    }
    
    func performSearch() {
        activeState?.performSearch()
    }
}
