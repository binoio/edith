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

// FocusedValue for selected text
struct SelectedTextKey: FocusedValueKey {
    typealias Value = String
}

extension FocusedValues {
    var documentZoomState: DocumentZoomState? {
        get { self[DocumentZoomStateKey.self] }
        set { self[DocumentZoomStateKey.self] = newValue }
    }
    
    var selectedText: String? {
        get { self[SelectedTextKey.self] }
        set { self[SelectedTextKey.self] = newValue }
    }
}

struct ContentView: View {
    @Binding var document: TextDocument
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.undoManager) var undoManager
    
    // Per-document state (not persisted)
    @StateObject private var zoomState = DocumentZoomState()
    @StateObject private var fileWatcher = FileWatcher()
    @StateObject private var syntaxHighlighter = SyntaxHighlighter()
    @StateObject private var findReplaceState = FindReplaceState()
    @StateObject private var vimModeState = VimModeState()
    
    @State private var showFileChangedBanner = false
    @State private var cursorPosition = CursorPosition()
    @State private var selectedText: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // File changed banner
                if showFileChangedBanner {
                    FileChangedBanner(
                        onReload: {
                            reloadFromDisk()
                        },
                        onDismiss: {
                            showFileChangedBanner = false
                            fileWatcher.acknowledgeChange()
                        }
                    )
                }
                
                EditorView(
                    text: $document.text,
                    zoomState: zoomState,
                    cursorPosition: $cursorPosition,
                    selectedText: $selectedText,
                    syntaxLanguage: document.syntaxLanguage,
                    syntaxHighlighter: syntaxHighlighter,
                    findReplaceState: findReplaceState,
                    vimModeState: settingsManager.enableVimMode ? vimModeState : nil
                )
                .environmentObject(settingsManager)
                
                // Vim Command Bar (shown in command mode when vim is enabled)
                if settingsManager.enableVimMode && vimModeState.mode == .command {
                    VimCommandBar(vimState: vimModeState)
                }
                
                // Status Bar
                if settingsManager.showStatusBar {
                    StatusBar(
                        document: $document,
                        cursorPosition: $cursorPosition,
                        detectedLanguage: syntaxHighlighter.detectedLanguage,
                        vimModeState: vimModeState,
                        vimModeEnabled: settingsManager.enableVimMode
                    )
                }
            }
            
            // Green glow border for vim normal mode (only when vim is enabled)
            if settingsManager.enableVimMode && vimModeState.mode != .insert {
                VimModeGlowOverlay()
            }
        }
        .focusedSceneValue(\.documentZoomState, zoomState)
        .focusedSceneValue(\.findReplaceState, findReplaceState)
        .focusedSceneValue(\.selectedText, selectedText.isEmpty ? nil : selectedText)
        .onReceive(zoomState.$zoom) { newZoom in
            settingsManager.activeDocumentZoom = newZoom
        }
        .onReceive(fileWatcher.$fileChanged) { changed in
            if changed && settingsManager.refreshDocumentsChangedOnDisk {
                showFileChangedBanner = true
            }
        }
        .onAppear {
            startWatchingFile()
            registerWithTracker()
            
            // Register with a delay to ensure window is set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let docName = getDocumentNameForThisView()
                FindReplaceManager.shared.registerActiveState(findReplaceState, documentName: docName)
            }
            
            // Check for pending extracted content (from Extract All)
            if let pendingContent = ExtractedContentManager.shared.pendingContent {
                ExtractedContentManager.shared.pendingContent = nil
                // Set document text after a brief delay to ensure view is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    document.text = pendingContent
                }
            }
        }
        .onDisappear {
            fileWatcher.stopWatching()
            unregisterFromTracker()
            // Unregister when document closes
            FindReplaceManager.shared.unregisterState(findReplaceState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            // When THIS document's window becomes key, update as active and refresh name
            guard let window = notification.object as? NSWindow,
                  let textView = findReplaceState.textView,
                  textView.window === window else { return }
            
            let docName = getDocumentNameForThisView()
            FindReplaceManager.shared.updateDocumentName(findReplaceState, name: docName)
            FindReplaceManager.shared.selectDocument(findReplaceState)
        }
    }
    
    private func getDocumentNameForThisView() -> String {
        // Get name from the window containing our text view
        if let textView = findReplaceState.textView,
           let window = textView.window,
           let windowController = window.windowController,
           let nsDoc = windowController.document as? NSDocument {
            return nsDoc.displayName
        }
        return "Untitled"
    }
    
    private func getDocumentFileURL() -> URL? {
        if let windowController = NSApp.keyWindow?.windowController,
           let document = windowController.document as? NSDocument {
            return document.fileURL
        }
        return nil
    }
    
    private func registerWithTracker() {
        // Delay to ensure window is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            OpenDocumentsTracker.shared.documentOpened(getDocumentFileURL())
        }
    }
    
    private func unregisterFromTracker() {
        OpenDocumentsTracker.shared.documentClosed(getDocumentFileURL())
    }
    
    private func startWatchingFile() {
        // Try to get the file URL from NSDocumentController
        // Delay slightly to ensure window is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            if let windowController = NSApp.keyWindow?.windowController,
               let document = windowController.document as? NSDocument,
               let fileURL = document.fileURL {
                fileWatcher.startWatching(url: fileURL)
            }
        }
    }
    
    private func reloadFromDisk() {
        if let windowController = NSApp.keyWindow?.windowController,
           let nsDocument = windowController.document as? NSDocument,
           let fileURL = nsDocument.fileURL {
            do {
                let data = try Data(contentsOf: fileURL)
                let encodingIndex = UserDefaults.standard.integer(forKey: "defaultTextEncoding")
                let encoding = TextEncodingOption(rawValue: encodingIndex)?.stringEncoding ?? .utf8
                if let newText = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) {
                    document.text = newText
                }
            } catch {
                print("Failed to reload file: \(error)")
            }
        }
        showFileChangedBanner = false
        fileWatcher.acknowledgeChange()
    }
}

// MARK: - File Watcher

class FileWatcher: ObservableObject {
    @Published var fileChanged = false
    
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var lastKnownModificationDate: Date?
    
    func startWatching(url: URL) {
        stopWatching()
        watchedURL = url
        
        lastKnownModificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        
        source?.setEventHandler { [weak self] in
            self?.checkForChanges()
        }
        
        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }
        
        source?.resume()
    }
    
    func stopWatching() {
        source?.cancel()
        source = nil
        watchedURL = nil
    }
    
    func acknowledgeChange() {
        fileChanged = false
        if let url = watchedURL {
            // Re-establish the watch in case the file was replaced (new inode)
            // This handles editors like vim that create a new file when saving
            let savedURL = url
            // Update modification date first
            lastKnownModificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
            // Then re-establish watch
            startWatching(url: savedURL)
        }
    }
    
    private func checkForChanges() {
        guard let url = watchedURL else { return }
        
        guard let newDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else {
            // File might have been replaced - re-establish watch after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, let url = self.watchedURL else { return }
                self.startWatching(url: url)
            }
            return
        }
        
        // Check if the file was modified
        guard let lastDate = lastKnownModificationDate, newDate > lastDate else { return }
        
        // File was modified - check if we should suppress (Edith's own save)
        let shouldSuppress = EdithSaveTracker.shared.shouldSuppressFileChangeAlert()
        
        // Always update the known date to track the latest state
        lastKnownModificationDate = newDate
        
        // Re-establish watch since file might have been replaced (new inode)
        // This handles editors like vim that delete+rename when saving
        let savedURL = url
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.stopWatching()
            self.watchedURL = savedURL
            self.lastKnownModificationDate = newDate
            
            self.fileDescriptor = open(savedURL.path, O_EVTONLY)
            guard self.fileDescriptor >= 0 else { return }
            
            self.source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: self.fileDescriptor,
                eventMask: [.write, .rename, .delete, .attrib],
                queue: .main
            )
            
            self.source?.setEventHandler { [weak self] in
                self?.checkForChanges()
            }
            
            self.source?.setCancelHandler { [weak self] in
                if let fd = self?.fileDescriptor, fd >= 0 {
                    close(fd)
                }
                self?.fileDescriptor = -1
            }
            
            self.source?.resume()
        }
        
        if shouldSuppress {
            // This was Edith's own save - suppress silently
            return
        }
        
        // External modification - show banner (only if not already showing)
        if !fileChanged {
            fileChanged = true
        }
    }
}

// MARK: - File Changed Banner

struct FileChangedBanner: View {
    let onReload: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            
            Text("This file has been modified by another application.")
                .font(.callout)
            
            Spacer()
            
            Button("Reload") {
                onReload()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button("Ignore") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.yellow.opacity(0.3)),
            alignment: .bottom
        )
    }
}
