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
            
            CommandMenu("View") {
                Button(settingsManager.showLineNumbers ? "Hide Line Numbers" : "Show Line Numbers") {
                    settingsManager.showLineNumbers.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
        }
    }
}
