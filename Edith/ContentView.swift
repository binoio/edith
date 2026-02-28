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
    @Environment(\.undoManager) var undoManager
    
    // Per-document state (not persisted)
    @StateObject private var zoomState = DocumentZoomState()
    @StateObject private var fileWatcher = FileWatcher()
    
    @State private var showFileChangedBanner = false
    
    var body: some View {
        VStack(spacing: 0) {
            // File changed banner
            if showFileChangedBanner {
                FileChangedBanner(
                    onReload: {
                        reloadFromDisk()
                    },
                    onDismiss: {
                        showFileChangedBanner = false
                    }
                )
            }
            
            EditorView(text: $document.text, zoomState: zoomState)
                .environmentObject(settingsManager)
        }
        .focusedSceneValue(\.documentZoomState, zoomState)
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
        }
        .onDisappear {
            fileWatcher.stopWatching()
        }
    }
    
    private func startWatchingFile() {
        // Try to get the file URL from NSDocumentController
        if let windowController = NSApp.keyWindow?.windowController,
           let document = windowController.document as? NSDocument,
           let fileURL = document.fileURL {
            fileWatcher.startWatching(url: fileURL)
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
            lastKnownModificationDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        }
    }
    
    private func checkForChanges() {
        guard let url = watchedURL else { return }
        
        guard let newDate = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date else { return }
        
        if let lastDate = lastKnownModificationDate, newDate > lastDate {
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
