//
//  FindReplaceWindow.swift
//  Edith
//

import SwiftUI

/// Multi-line text editor for Find/Replace fields
struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        // Set placeholder
        if text.isEmpty {
            textView.string = ""
        }
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextField
        
        init(_ parent: MultilineTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Handle Enter key to submit (Option+Enter for newline)
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.option) {
                    // Option+Enter inserts actual newline
                    return false
                } else {
                    // Enter triggers search
                    parent.onSubmit?()
                    return true
                }
            }
            return false
        }
    }
}

/// Find & Replace window view
struct FindReplaceView: View {
    @ObservedObject var state: FindReplaceState
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left side: Fields and options
            VStack(alignment: .leading, spacing: 12) {
                // Find field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find:")
                        .font(.headline)
                    MultilineTextField(text: $state.findText, placeholder: "Search text") {
                        state.findNext()
                    }
                    .frame(height: 60)
                    .onChange(of: state.findText) { _ in
                        state.performSearch()
                    }
                }
                
                // Replace field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replace:")
                        .font(.headline)
                    MultilineTextField(text: $state.replaceText, placeholder: "Replacement text")
                        .frame(height: 60)
                }
                
                Divider()
                
                // Options in a grid
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 20) {
                        Toggle("Case sensitive", isOn: $state.caseSensitive)
                            .onChange(of: state.caseSensitive) { _ in state.performSearch() }
                        
                        Toggle("PCRE syntax", isOn: $state.usePCRE)
                            .onChange(of: state.usePCRE) { _ in state.performSearch() }
                    }
                    
                    HStack(spacing: 20) {
                        Toggle("Selected text only", isOn: $state.selectedTextOnly)
                            .disabled(state.initialSelectionRange == nil)
                            .onChange(of: state.selectedTextOnly) { _ in state.performSearch() }
                        
                        Toggle("Wrap around", isOn: $state.wrapAround)
                    }
                }
                
                // Match count - always reserve space to prevent layout shift
                HStack {
                    if state.findText.isEmpty {
                        Text(" ")
                            .foregroundColor(.clear)
                    } else if state.hasMatches {
                        Text("\(state.currentMatchIndex + 1) of \(state.totalMatches) matches")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No matches")
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .frame(height: 16)
                
                Spacer()
            }
            
            Divider()
            
            // Right side: Action buttons in a column
            VStack(spacing: 8) {
                Group {
                    Button("Find Next") {
                        state.findNext()
                    }
                    
                    Button("Find Previous") {
                        state.findPrevious()
                    }
                    
                    Button("Find All") {
                        state.findAll()
                    }
                    
                    Button("Extract All") {
                        state.extractAll()
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .padding(.vertical, 4)
                
                Group {
                    Button("Replace Next") {
                        state.replaceNext()
                    }
                    
                    Button("Replace All") {
                        state.replaceAll()
                    }
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .frame(width: 120)
        }
        .padding()
        .frame(minWidth: 520, minHeight: 300)
        .onAppear {
            state.captureSelection()
            if !state.findText.isEmpty {
                state.performSearch()
            }
        }
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
