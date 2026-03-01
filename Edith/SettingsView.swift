//
//  SettingsView.swift
//  Edith
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            TextEncodingSettingsView()
                .tabItem {
                    Label("Text Encodings", systemImage: "doc.text")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            EditorDefaultsSettingsView()
                .tabItem {
                    Label("Editor Defaults", systemImage: "textformat")
                }
        }
        .environmentObject(settingsManager)
        .frame(width: 500, height: 320)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section {
                Toggle("Re-open documents from last session", isOn: $settingsManager.reopenDocumentsOnLaunch)
                
                Toggle("Restore unsaved changes", isOn: $settingsManager.restoreUnsavedChanges)
                    .disabled(!settingsManager.reopenDocumentsOnLaunch)
                    .foregroundColor(settingsManager.reopenDocumentsOnLaunch ? .primary : .secondary)
                    .padding(.leading, 20)
                
                Divider()
                    .padding(.vertical, 8)
                
                Toggle("Automatically refresh documents changed on disk", isOn: $settingsManager.refreshDocumentsChangedOnDisk)
                
                Divider()
                    .padding(.vertical, 8)
                
                Toggle("Enable vim-like modal editing (double-tap Esc)", isOn: $settingsManager.enableVimMode)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    settingsManager.restoreDefaults()
                }
            }
        }
        .padding()
    }
}

// MARK: - Text Encoding Settings
struct TextEncodingSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section {
                Picker("Default Encoding for New Documents:", selection: $settingsManager.defaultTextEncoding) {
                    ForEach(TextEncodingOption.allCases) { encoding in
                        Text(encoding.description).tag(encoding.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    settingsManager.restoreDefaults()
                }
            }
        }
        .padding()
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section {
                Picker("Appearance:", selection: $settingsManager.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.description).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    settingsManager.restoreDefaults()
                }
            }
        }
        .padding()
    }
}

// MARK: - Editor Defaults Settings
struct EditorDefaultsSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingFontPicker = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Default Font:")
                    Spacer()
                    Text("\(settingsManager.fontName), \(Int(settingsManager.fontSize)) pt")
                        .foregroundColor(.secondary)
                    Button("Select...") {
                        showFontPanel()
                    }
                }
                
                HStack {
                    Text("Magnification:")
                    Slider(value: $settingsManager.magnification, in: 0.5...3.0, step: 0.1)
                    Text("\(Int(settingsManager.magnification * 100))%")
                        .frame(width: 50)
                }
                
                Stepper("Spaces per Tab: \(settingsManager.spacesPerTab)", value: $settingsManager.spacesPerTab, in: 1...8)
                
                Toggle("Show Invisible Characters", isOn: $settingsManager.showInvisibleCharacters)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Restore Defaults") {
                    settingsManager.restoreDefaults()
                }
            }
        }
        .padding()
    }
    
    private func showFontPanel() {
        let fontManager = NSFontManager.shared
        let font = NSFont(name: settingsManager.fontName, size: settingsManager.fontSize) ?? NSFont.systemFont(ofSize: 13)
        fontManager.setSelectedFont(font, isMultiple: false)
        fontManager.target = FontPanelDelegate.shared
        FontPanelDelegate.shared.settingsManager = settingsManager
        fontManager.orderFrontFontPanel(nil)
    }
}

// Font panel delegate to handle font selection
class FontPanelDelegate: NSObject {
    static let shared = FontPanelDelegate()
    weak var settingsManager: SettingsManager?
    
    @objc func changeFont(_ sender: NSFontManager?) {
        guard let fontManager = sender,
              let settingsManager = settingsManager else { return }
        
        let currentFont = NSFont(name: settingsManager.fontName, size: settingsManager.fontSize) ?? NSFont.systemFont(ofSize: 13)
        let newFont = fontManager.convert(currentFont)
        
        DispatchQueue.main.async {
            settingsManager.fontName = newFont.fontName
            settingsManager.fontSize = newFont.pointSize
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
}
