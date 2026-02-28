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
    @FocusedValue(\.documentZoom) var documentZoom
    @FocusedValue(\.documentFontSize) var documentFontSize
    
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
                    if let zoom = documentZoom {
                        zoom.wrappedValue = min(zoom.wrappedValue * 1.25, 4.0)
                    }
                }
                .keyboardShortcut("+", modifiers: [.command, .option])
                .disabled(documentZoom == nil)
                
                Button("Zoom Out") {
                    if let zoom = documentZoom {
                        zoom.wrappedValue = max(zoom.wrappedValue / 1.25, 0.25)
                    }
                }
                .keyboardShortcut("-", modifiers: [.command, .option])
                .disabled(documentZoom == nil)
                
                Button("Actual Size") {
                    if let zoom = documentZoom {
                        zoom.wrappedValue = 1.0
                    }
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(documentZoom == nil)
            }
            
            // Format > Font menu for font size adjustments
            CommandMenu("Format") {
                Menu("Font") {
                    Button("Bigger") {
                        if let fontSize = documentFontSize {
                            fontSize.wrappedValue += 1.0
                        }
                    }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(documentFontSize == nil)
                    
                    Button("Smaller") {
                        if let fontSize = documentFontSize {
                            fontSize.wrappedValue = max(fontSize.wrappedValue - 1.0, -settingsManager.fontSize + 6)
                        }
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(documentFontSize == nil)
                }
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}
