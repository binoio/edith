//
//  EdithApp.swift
//  Edith
//
//  A basic macOS text editor
//

import SwiftUI

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
        // Always save, even if empty - this ensures the directory exists
        // and clears any stale data if no documents are open
        
        guard reopenDocumentsOnLaunch else {
            DocumentRestoreManager.shared.clearOpenDocuments()
            return
        }
        
        // Save list of open documents
        var openDocs: [DocumentRestoreManager.OpenDocumentInfo] = []
        
        for document in NSDocumentController.shared.documents {
            guard let fileURL = document.fileURL else { continue }
            
            let restoreID = fileURL.lastPathComponent.replacingOccurrences(of: ".", with: "_")
            let info = DocumentRestoreManager.OpenDocumentInfo(
                path: fileURL.path,
                hasUnsavedChanges: document.hasUnautosavedChanges,
                restoreID: restoreID
            )
            openDocs.append(info)
        }
        
        // Always save, even if array is empty (to clear old data)
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

@main
struct EdithApp: App {
    @NSApplicationDelegateAdaptor(EdithAppDelegate.self) var appDelegate
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            ContentView(document: file.$document)
                .environmentObject(settingsManager)
                .onAppear {
                    // Pass settings to app delegate
                    appDelegate.settingsManager = settingsManager
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
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}
