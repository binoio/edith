//
//  HelpView.swift
//  Edith
//
//  Edith Help window content.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading) {
                        Text("Edith")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("A simple, powerful text editor")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 10)
                
                Divider()
                
                // Getting Started
                HelpSection(title: "Getting Started", icon: "play.circle") {
                    HelpItem(shortcut: "⌘N", description: "Create a new document")
                    HelpItem(shortcut: "⌘O", description: "Open an existing document")
                    HelpItem(shortcut: "⌘S", description: "Save the current document")
                    HelpItem(shortcut: "⌘,", description: "Open Settings")
                }
                
                // View Controls
                HelpSection(title: "View Controls", icon: "eye") {
                    HelpItem(shortcut: "⌘=", description: "Zoom in")
                    HelpItem(shortcut: "⌘-", description: "Zoom out")
                    HelpItem(shortcut: "⌘0", description: "Actual size (reset zoom)")
                    HelpItem(shortcut: "⇧⌘+", description: "Increase font size")
                    HelpItem(shortcut: "⌥⌘-", description: "Decrease font size")
                }
                
                // Editor Features
                HelpSection(title: "Editor Features", icon: "textformat") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**Line Numbers** — Toggle in View menu or Settings")
                        Text("**Invisible Characters** — Show spaces, tabs, and line endings in Settings")
                        Text("**Text Encoding** — Choose encoding for new documents in Settings")
                        Text("**Appearance** — Switch between light, dark, or system appearance")
                    }
                    .font(.body)
                }
                
                // Settings Overview
                HelpSection(title: "Settings", icon: "gearshape") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("**General** — Session restore, document refresh options")
                        Text("**Text Encodings** — Default encoding for new documents")
                        Text("**Appearance** — Light, dark, or system appearance")
                        Text("**Editor Defaults** — Font, magnification, tabs, invisibles")
                    }
                    .font(.body)
                }
                
                // Invisible Characters Legend
                HelpSection(title: "Invisible Characters", icon: "eye.slash") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("·").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Space")
                        }
                        HStack {
                            Text("°").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Non-breaking space")
                        }
                        HStack {
                            Text("△").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Tab")
                        }
                        HStack {
                            Text("↵").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Line ending (newline)")
                        }
                        HStack {
                            Text("▽").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Form feed")
                        }
                        HStack {
                            Text("↧").font(.system(.body, design: .monospaced)).frame(width: 30)
                            Text("Vertical tab")
                        }
                    }
                }
                
                Divider()
                
                // Footer
                HStack {
                    Spacer()
                    Text("Edith • Made with ♥")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .frame(width: 500, height: 550)
    }
}

// MARK: - Help Components

struct HelpSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            content
                .padding(.leading, 24)
        }
    }
}

struct HelpItem: View {
    let shortcut: String
    let description: String
    
    var body: some View {
        HStack {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)
            Text(description)
        }
    }
}

// MARK: - Help Window Controller

class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()
    
    convenience init() {
        let hostingController = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Edith Help"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 550))
        window.center()
        
        self.init(window: window)
    }
    
    func showHelp() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview {
    HelpView()
}
