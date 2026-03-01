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

/// Global manager for Find & Replace functionality.
/// Documents register/unregister their FindReplaceState when becoming active/inactive.
@MainActor
final class FindReplaceManager: ObservableObject {
    static let shared = FindReplaceManager()
    
    /// The currently active document's find/replace state
    @Published private(set) var activeState: FindReplaceState?
    
    /// Tracks which state is currently registered
    private var registeredStates: [ObjectIdentifier: FindReplaceState] = [:]
    
    private init() {}
    
    /// Called when a document window becomes key (focused)
    func registerActiveState(_ state: FindReplaceState) {
        let id = ObjectIdentifier(state)
        registeredStates[id] = state
        activeState = state
    }
    
    /// Called when a document window resigns key focus
    /// Only clears if this state was the active one
    func documentResignedKey(_ state: FindReplaceState) {
        // Don't clear - keep the last active state available
        // This allows the Find & Replace window to still work
    }
    
    /// Called when a document window is closed
    func unregisterState(_ state: FindReplaceState) {
        let id = ObjectIdentifier(state)
        registeredStates.removeValue(forKey: id)
        
        // If this was the active state, clear it
        if activeState === state {
            activeState = nil
        }
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
