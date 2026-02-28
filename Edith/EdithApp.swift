//
//  EdithApp.swift
//  Edith
//
//  A basic macOS text editor
//

import SwiftUI

@main
struct EdithApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @FocusedValue(\.documentZoomState) var zoomState
    
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
                .keyboardShortcut("+", modifiers: [.command, .option])
                .disabled(zoomState == nil || (zoomState?.zoom ?? 1.0) >= 4.0)
                
                Button("Zoom Out") {
                    zoomState?.zoomOut()
                }
                .keyboardShortcut("-", modifiers: [.command, .option])
                .disabled(zoomState == nil || (zoomState?.zoom ?? 1.0) <= 0.25)
                
                Button("Actual Size") {
                    zoomState?.resetZoom()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                .disabled(zoomState == nil || zoomState?.zoom == 1.0)
            }
            
            // Format > Font menu for font size adjustments
            CommandMenu("Format") {
                Menu("Font") {
                    Button("Bigger") {
                        zoomState?.increaseFontSize()
                    }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(zoomState == nil)
                    
                    Button("Smaller") {
                        zoomState?.decreaseFontSize(minOffset: -settingsManager.fontSize + 6)
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(zoomState == nil)
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}
