//
//  EdithApp.swift
//  Edith
//
//  A basic macOS text editor
//

import SwiftUI

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
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        DocumentGroup(newDocument: TextDocument()) { file in
            ContentView(document: file.$document)
                .environmentObject(settingsManager)
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
