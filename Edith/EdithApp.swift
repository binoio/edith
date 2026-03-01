//
//  EdithApp.swift
//  Edith
//
//  A basic macOS text editor
//

import SwiftUI

// MARK: - Notification names
extension Notification.Name {
    static let openFindReplace = Notification.Name("openFindReplace")
}

// MARK: - Open Documents Tracker (for SwiftUI DocumentGroup)
class OpenDocumentsTracker: ObservableObject {
    static let shared = OpenDocumentsTracker()
    
    @Published private(set) var openDocuments: Set<URL> = []
    
    func documentOpened(_ url: URL?) {
        guard let url = url else { return }
        DispatchQueue.main.async {
            self.openDocuments.insert(url)
        }
    }
    
    func documentClosed(_ url: URL?) {
        guard let url = url else { return }
        DispatchQueue.main.async {
            self.openDocuments.remove(url)
        }
    }
    
    func getOpenDocumentPaths() -> [String] {
        return openDocuments.map { $0.path }
    }
}

// MARK: - App Delegate for session management
class EdithAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var settingsManager: SettingsManager?
    
    override init() {
        super.init()
        
        // Force directory creation immediately
        _ = DocumentRestoreManager.shared
        
        // Register for termination notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    // Read setting directly from UserDefaults (same source as SettingsManager)
    private var reopenDocumentsOnLaunch: Bool {
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "reopenDocumentsOnLaunch") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "reopenDocumentsOnLaunch")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard reopenDocumentsOnLaunch else { return }
        
        // Restore documents from last session
        let openDocs = DocumentRestoreManager.shared.loadOpenDocuments()
        
        guard !openDocs.isEmpty else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for docInfo in openDocs {
                let url = URL(fileURLWithPath: docInfo.path)
                guard FileManager.default.fileExists(atPath: docInfo.path) else { continue }
                
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { document, wasAlreadyOpen, error in
                    if let error = error {
                        print("Failed to reopen \(docInfo.path): \(error)")
                    }
                }
            }
        }
    }
    
    @objc func handleWillTerminate(_ notification: Notification) {
        saveOpenDocumentsState()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save open documents BEFORE the app starts closing windows
        saveOpenDocumentsState()
        return .terminateNow
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Backup: also try to save here in case applicationShouldTerminate wasn't called
        saveOpenDocumentsState()
    }
    
    private func saveOpenDocumentsState() {
        guard reopenDocumentsOnLaunch else {
            DocumentRestoreManager.shared.clearOpenDocuments()
            return
        }
        
        // Use the tracker instead of NSDocumentController (SwiftUI DocumentGroup doesn't use NSDocumentController)
        let paths = OpenDocumentsTracker.shared.getOpenDocumentPaths()
        
        var openDocs: [DocumentRestoreManager.OpenDocumentInfo] = []
        
        for path in paths {
            let restoreID = URL(fileURLWithPath: path).lastPathComponent.replacingOccurrences(of: ".", with: "_")
            let info = DocumentRestoreManager.OpenDocumentInfo(
                path: path,
                hasUnsavedChanges: false,
                restoreID: restoreID
            )
            openDocs.append(info)
        }
        
        DocumentRestoreManager.shared.saveOpenDocuments(openDocs)
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
            CommandGroup(replacing: .newItem) {
                Button("New Text Document") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            ZoomCommands(settingsManager: settingsManager)
            SearchCommands()
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
        
        // Find & Replace window - uses the shared manager to get active document's state
        Window("Find & Replace", id: "find-replace") {
            if let state = findReplaceManager.activeState {
                FindReplaceView(state: state)
            } else {
                Text("No document selected")
                    .foregroundColor(.secondary)
                    .frame(width: 300, height: 100)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
}
