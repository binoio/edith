//
//  FindReplaceWindow.swift
//  Edith
//

import SwiftUI

/// Find & Replace panel: a compact floating inspector over the document.
struct FindReplaceView: View {
    @ObservedObject var state: FindReplaceState
    @ObservedObject var manager: FindReplaceManager
    
    @FocusState private var findFieldFocused: Bool
    
    private var hasPattern: Bool { !manager.findText.isEmpty }
    private var canReplace: Bool { state.hasMatches && state.patternError == nil }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if manager.documents.count > 1 {
                documentPicker
                Divider()
            }
            
            fields
            optionsRow
            Divider()
            actions
            
            // Shift+Return searches backwards; onSubmit cannot see modifiers
            Button("") { state.findPrevious() }
                .keyboardShortcut(.return, modifiers: .shift)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(minWidth: 400)
        .onAppear {
            manager.ensureActiveState()
            state.captureSelection()
            findFieldFocused = true
            if !manager.findText.isEmpty {
                manager.syncAndSearch()
            }
        }
    }
    
    // MARK: - Document picker
    
    private var documentPicker: some View {
        Picker("", selection: Binding(
            get: { manager.activeState.map { ObjectIdentifier($0) } },
            set: { newId in
                if let newId = newId,
                   let doc = manager.documents.first(where: { $0.id == newId }) {
                    manager.selectDocument(doc.state)
                }
            }
        )) {
            ForEach(manager.documents) { doc in
                Text(doc.name).tag(Optional(doc.id))
            }
        }
        .labelsHidden()
        .frame(maxWidth: 260, alignment: .leading)
        .accessibilityLabel("Document to search")
    }
    
    // MARK: - Fields
    
    private var fields: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Text("Find")
                    .gridColumnAlignment(.trailing)
                
                TextField("Search text", text: $manager.findText)
                    .textFieldStyle(.roundedBorder)
                    .focused($findFieldFocused)
                    .onChange(of: manager.findText) { _, _ in manager.scheduleSearch() }
                    .onSubmit {
                        manager.syncAndSearch()
                        state.findNext()
                    }
                    .overlay {
                        if state.patternError != nil {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.red, lineWidth: 1)
                        }
                    }
                
                navigationButtons
            }
            
            GridRow {
                Text("Replace")
                    .gridColumnAlignment(.trailing)
                
                TextField("Replacement text", text: $manager.replaceText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: manager.replaceText) { _, newValue in
                        state.replaceText = newValue
                    }
                
                // Keeps the third column's width stable across both rows
                Color.clear.frame(height: 1)
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 4) {
            Button { state.findPrevious() } label: {
                Image(systemName: "chevron.backward")
            }
            .help("Find Previous (⇧⌘G)")
            .disabled(!state.hasMatches)
            
            Button { state.findNext() } label: {
                Image(systemName: "chevron.forward")
            }
            .help("Find Next (⌘G)")
            .keyboardShortcut(.defaultAction)
            .disabled(!state.hasMatches)
            
            Button { state.findAll() } label: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
            }
            .help("Highlight every match and go to the first")
            .disabled(!hasPattern)
        }
        .buttonStyle(.bordered)
    }
    
    // MARK: - Options
    
    private var optionsRow: some View {
        HStack(spacing: 14) {
            Toggle("Aa", isOn: $manager.caseSensitive)
                .help("Case sensitive")
                .onChange(of: manager.caseSensitive) { _, _ in manager.syncAndSearch() }
            
            Toggle(".*", isOn: $manager.usePCRE)
                .help("Interpret the search text as a PCRE regular expression")
                .onChange(of: manager.usePCRE) { _, _ in manager.syncAndSearch() }
            
            Toggle("Sel", isOn: $state.selectedTextOnly)
                .help("Search only within the text that was selected")
                .disabled(state.initialSelectionRange == nil)
                .onChange(of: state.selectedTextOnly) { _, _ in manager.syncAndSearch() }
            
            Toggle("Wrap", isOn: $manager.wrapAround)
                .help("Continue from the top after the last match")
                .onChange(of: manager.wrapAround) { _, newValue in
                    state.wrapAround = newValue
                }
            
            Spacer(minLength: 8)
            
            summary
        }
        .toggleStyle(.checkbox)
    }
    
    @ViewBuilder
    private var summary: some View {
        switch state.matchSummary {
        case .idle:
            // Reserve the row's height so the layout never shifts
            Text(" ").foregroundStyle(.clear)
        case .invalidPattern:
            Text("Invalid pattern")
                .foregroundStyle(.red)
                .help(state.patternError ?? "")
        case .noMatches:
            Text("No matches")
                .foregroundStyle(.red)
        case let .match(index, total):
            Text("\(index) of \(total)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private var actions: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Button("Replace") { state.replaceNext() }
                    .help("Replace the current match and move to the next")
                    .disabled(!canReplace)
                
                Button("Replace All") { state.replaceAll() }
                    .help("Replace every match")
                    .disabled(!canReplace)
            }
            GridRow {
                Button("Find All") { state.findAll() }
                    .help("Highlight every match and go to the first")
                    .disabled(!hasPattern)
                
                Button("Extract All") { state.extractAll() }
                    .help("Copy every match into a new document")
                    .disabled(!canReplace)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - FocusedValue for FindReplaceState
struct FindReplaceStateKey: FocusedValueKey {
    typealias Value = FindReplaceState
}

extension FocusedValues {
    var findReplaceState: FindReplaceState? {
        get { self[FindReplaceStateKey.self] }
        set { self[FindReplaceStateKey.self] = newValue }
    }
}
