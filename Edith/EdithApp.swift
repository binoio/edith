//
//  EdithApp.swift
//  Edith
//
//  A basic macOS text editor
//

import SwiftUI
import Sparkle

// MARK: - Notification names
extension Notification.Name {
    static let openFindReplace = Notification.Name("openFindReplace")
    static let claimUntitledRestore = Notification.Name("claimUntitledRestore")
}

// MARK: - App Delegate for session management and auto-updates
@MainActor
class EdithAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var settingsManager: SettingsManager?
    
    // Started manually so XCTest runs (which host the app) never spin up
    // Sparkle's scheduled checks
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    lazy var updaterViewModel = UpdaterViewModel(updater: updaterController.updater)
    
    // Read settings directly from UserDefaults (same source as SettingsManager)
    private var reopenDocumentsOnLaunch: Bool {
        if UserDefaults.standard.object(forKey: "reopenDocumentsOnLaunch") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "reopenDocumentsOnLaunch")
    }
    
    private var restoreUnsavedChanges: Bool {
        if UserDefaults.standard.object(forKey: "restoreUnsavedChanges") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "restoreUnsavedChanges")
    }
    
    private var openNewDocumentOnLaunch: Bool {
        if UserDefaults.standard.object(forKey: "openNewDocumentOnLaunch") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "openNewDocumentOnLaunch")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
           NSClassFromString("XCTestCase") == nil {
            updaterController.startUpdater()
        }
        NSApp.activate(ignoringOtherApps: true)
        restoreSession()
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return openNewDocumentOnLaunch
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && openNewDocumentOnLaunch {
            NSDocumentController.shared.newDocument(nil)
            return false
        }
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Snapshot the session while every window is still open
        DocumentSessionCoordinator.shared.beginTermination()
        
        if reopenDocumentsOnLaunch && restoreUnsavedChanges {
            // Hot exit: unsaved changes are backed up and restored on the next
            // launch, so quitting never blocks on save dialogs
            return .terminateNow
        }
        
        // Without restore, fall back to the standard review of unsaved documents
        NSDocumentController.shared.reviewUnsavedDocuments(
            withAlertTitle: "Quit Edith",
            cancellable: true,
            delegate: self,
            didReviewAllSelector: #selector(documentController(_:didReviewAll:contextInfo:)),
            contextInfo: nil)
        return .terminateLater
    }
    
    @objc private func documentController(_ docController: NSDocumentController,
                                          didReviewAll: Bool,
                                          contextInfo: UnsafeMutableRawPointer?) {
        NSApp.reply(toApplicationShouldTerminate: didReviewAll)
    }
    
    // MARK: Session restore
    
    private func restoreSession() {
        let openDocs = reopenDocumentsOnLaunch ? DocumentRestoreManager.shared.loadOpenDocuments() : []
        
        if openDocs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.openNewDocumentOnLaunch {
                    if NSDocumentController.shared.documents.isEmpty {
                        NSDocumentController.shared.newDocument(nil)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                        if let keyWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
                            keyWindow.makeKeyAndOrderFront(nil)
                        }
                    }
                } else {
                    for document in NSDocumentController.shared.documents
                    where document.fileURL == nil && !document.isDocumentEdited {
                        document.close()
                    }
                }
            }
            return
        }
        let restoreUnsaved = restoreUnsavedChanges
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var restoredFiles = 0
            var untitledCount = 0
            
            for docInfo in openDocs {
                if docInfo.isUntitled {
                    guard restoreUnsaved,
                          let content = DocumentRestoreManager.shared.loadUnsavedContent(restoreID: docInfo.restoreID),
                          !content.isEmpty else { continue }
                    PendingSessionRestore.shared.untitledContents.append(content)
                    untitledCount += 1
                    continue
                }
                
                guard let url = Self.resolveSessionURL(for: docInfo) else { continue }
                if restoreUnsaved, docInfo.hasUnsavedChanges,
                   let content = DocumentRestoreManager.shared.loadUnsavedContent(restoreID: docInfo.restoreID) {
                    PendingSessionRestore.shared.contentByPath[url.path] = content
                }
                restoredFiles += 1
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error = error {
                        print("Failed to reopen \(url.path): \(error)")
                    }
                }
            }
            
            if untitledCount > 0 {
                // Let the launch-created empty window claim the first untitled
                // document, then create windows for the rest
                NotificationCenter.default.post(name: .claimUntitledRestore, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    for _ in 0..<PendingSessionRestore.shared.untitledContents.count {
                        NSDocumentController.shared.newDocument(nil)
                    }
                }
            } else if restoredFiles > 0 {
                // Nothing needs the launch-created empty window; close it
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    for document in NSDocumentController.shared.documents
                    where document.fileURL == nil && !document.isDocumentEdited {
                        document.close()
                    }
                }
            }
        }
    }
    
    private static func resolveSessionURL(for docInfo: DocumentRestoreManager.OpenDocumentInfo) -> URL? {
        if let bookmark = docInfo.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale) {
                // Access stays open for the document's lifetime
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        // Legacy session entries (pre-bookmark) recorded only the path
        guard FileManager.default.fileExists(atPath: docInfo.path) else { return nil }
        return URL(fileURLWithPath: docInfo.path)
    }
}

// Helper view to observe zoom state and provide reactive menu items
struct ZoomCommands: Commands {
    @FocusedValue(\.documentZoomState) var zoomState
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            Button(settingsManager.showLineNumbers ? "Hide Line Numbers" : "Show Line Numbers") {
                settingsManager.showLineNumbers.toggle()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            
            Button(settingsManager.showStatusBar ? "Hide Status Bar" : "Show Status Bar") {
                settingsManager.showStatusBar.toggle()
            }
            .keyboardShortcut("/", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Zoom In") {
                zoomState?.zoomIn()
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(zoomState == nil || settingsManager.activeDocumentZoom >= 4.0)
            
            Button("Zoom Out") {
                zoomState?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(zoomState == nil || settingsManager.activeDocumentZoom <= 0.25)
            
            Button("Actual Size") {
                zoomState?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(zoomState == nil || settingsManager.activeDocumentZoom == 1.0)
        }
        
        // Format > Font menu for font size adjustments
        CommandMenu("Format") {
            Menu("Font") {
                Button("Bigger") {
                    zoomState?.increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: [.command, .shift])
                .disabled(zoomState == nil)
                
                Button("Smaller") {
                    zoomState?.decreaseFontSize(minOffset: -settingsManager.fontSize + 6)
                }
                .keyboardShortcut("-", modifiers: [.command, .option])
                .disabled(zoomState == nil)
            }
        }
        
        // Help menu
        CommandGroup(replacing: .help) {
            Button("Edith Help") {
                HelpWindowController.shared.showHelp()
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}

// Search menu commands
struct SearchCommands: Commands {
    @ObservedObject private var findReplaceManager = FindReplaceManager.shared
    
    var body: some Commands {
        CommandMenu("Search") {
            Button("Find & Replace...") {
                // Use NSApp to open the window
                if let window = NSApp.windows.first(where: { $0.title == "Find & Replace" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // Post a notification to open the window
                    NotificationCenter.default.post(name: .openFindReplace, object: nil)
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            
            Divider()
            
            Button("Find Next") {
                findReplaceManager.findNext()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(findReplaceManager.activeState == nil)
            
            Button("Find Previous") {
                findReplaceManager.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(findReplaceManager.activeState == nil)
        }
    }
}

// File menu commands
struct FileCommands: Commands {
    @FocusedValue(\.selectedText) var selectedText
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Text Document") {
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("New from Selected") {
                if let text = selectedText {
                    ExtractedContentManager.shared.pendingContent = text
                    NSDocumentController.shared.newDocument(nil)
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(selectedText == nil)
        }
    }
}

@main
struct EdithApp: App {
    @NSApplicationDelegateAdaptor(EdithAppDelegate.self) var appDelegate
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var findReplaceManager = FindReplaceManager.shared
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            ContentView(document: file.$document)
                .environmentObject(settingsManager)
                .onAppear {
                    // Pass settings to app delegate
                    appDelegate.settingsManager = settingsManager
                }
                .onReceive(NotificationCenter.default.publisher(for: .openFindReplace)) { _ in
                    openWindow(id: "find-replace")
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(viewModel: appDelegate.updaterViewModel)
            }
            FileCommands()
            ZoomCommands(settingsManager: settingsManager)
            SearchCommands()
        }
        
        Settings {
            SettingsView(updaterViewModel: appDelegate.updaterViewModel)
                .environmentObject(settingsManager)
        }
        
        // Find & Replace window - uses the shared manager to get active document's state
        Window("Find & Replace", id: "find-replace") {
            if let state = findReplaceManager.activeState {
                FindReplaceView(state: state, manager: findReplaceManager)
            } else if !findReplaceManager.documents.isEmpty {
                // Documents exist but no active state - trigger selection
                FindReplaceView(state: findReplaceManager.documents.first!.state, manager: findReplaceManager)
                    .onAppear {
                        findReplaceManager.ensureActiveState()
                    }
            } else {
                Text("No documents open")
                    .foregroundColor(.secondary)
                    .frame(width: 300, height: 100)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
