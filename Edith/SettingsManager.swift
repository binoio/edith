//
//  SettingsManager.swift
//  Edith
//

import SwiftUI
import Combine

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .system: return "Use System Appearance"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum TextEncodingOption: Int, CaseIterable, Identifiable {
    case utf8 = 0
    case utf16 = 1
    case utf16BigEndian = 2
    case utf16LittleEndian = 3
    case ascii = 4
    case isoLatin1 = 5
    case macOSRoman = 6
    case windowsCP1252 = 7
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .utf8: return "Unicode (UTF-8)"
        case .utf16: return "Unicode (UTF-16)"
        case .utf16BigEndian: return "Unicode (UTF-16BE)"
        case .utf16LittleEndian: return "Unicode (UTF-16LE)"
        case .ascii: return "ASCII"
        case .isoLatin1: return "Western (ISO Latin 1)"
        case .macOSRoman: return "Western (Mac OS Roman)"
        case .windowsCP1252: return "Western (Windows Latin 1)"
        }
    }
    
    var stringEncoding: String.Encoding {
        switch self {
        case .utf8: return .utf8
        case .utf16: return .utf16
        case .utf16BigEndian: return .utf16BigEndian
        case .utf16LittleEndian: return .utf16LittleEndian
        case .ascii: return .ascii
        case .isoLatin1: return .isoLatin1
        case .macOSRoman: return .macOSRoman
        case .windowsCP1252: return .windowsCP1252
        }
    }
}

class SettingsManager: ObservableObject {
    // General
    @AppStorage("reopenDocumentsOnLaunch") var reopenDocumentsOnLaunch: Bool = true
    @AppStorage("restoreUnsavedChanges") var restoreUnsavedChanges: Bool = true
    @AppStorage("refreshDocumentsChangedOnDisk") var refreshDocumentsChangedOnDisk: Bool = true
    
    // Text Encoding
    @AppStorage("defaultTextEncoding") var defaultTextEncoding: Int = TextEncodingOption.utf8.rawValue
    
    // Appearance
    @AppStorage("appearanceMode") var appearanceMode: Int = AppearanceMode.system.rawValue {
        didSet {
            applyAppearance()
        }
    }
    
    // Editor Defaults
    @AppStorage("fontName") var fontName: String = "Menlo"
    @AppStorage("fontSize") var fontSize: Double = 13.0
    @AppStorage("magnification") var magnification: Double = 1.0
    @AppStorage("spacesPerTab") var spacesPerTab: Int = 4
    @AppStorage("showInvisibleCharacters") var showInvisibleCharacters: Bool = false
    @AppStorage("showLineNumbers") var showLineNumbers: Bool = true
    
    // Transient state for active document (not persisted)
    @Published var activeDocumentZoom: Double = 1.0
    
    // Default values for restoration
    static let defaultReopenDocumentsOnLaunch = true
    static let defaultRestoreUnsavedChanges = true
    static let defaultRefreshDocumentsChangedOnDisk = true
    static let defaultFontName = "Menlo"
    static let defaultFontSize: Double = 13.0
    static let defaultMagnification: Double = 1.0
    static let defaultSpacesPerTab: Int = 4
    static let defaultShowInvisibleCharacters = false
    static let defaultShowLineNumbers = true
    static let defaultTextEncoding = TextEncodingOption.utf8.rawValue
    static let defaultAppearanceMode = AppearanceMode.system.rawValue
    
    var currentEncoding: String.Encoding {
        TextEncodingOption(rawValue: defaultTextEncoding)?.stringEncoding ?? .utf8
    }
    
    init() {
        applyAppearance()
    }
    
    func applyAppearance() {
        DispatchQueue.main.async {
            switch AppearanceMode(rawValue: self.appearanceMode) {
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case .system, .none:
                NSApp.appearance = nil
            }
        }
    }
    
    func restoreDefaults() {
        reopenDocumentsOnLaunch = Self.defaultReopenDocumentsOnLaunch
        restoreUnsavedChanges = Self.defaultRestoreUnsavedChanges
        refreshDocumentsChangedOnDisk = Self.defaultRefreshDocumentsChangedOnDisk
        fontName = Self.defaultFontName
        fontSize = Self.defaultFontSize
        magnification = Self.defaultMagnification
        spacesPerTab = Self.defaultSpacesPerTab
        showInvisibleCharacters = Self.defaultShowInvisibleCharacters
        showLineNumbers = Self.defaultShowLineNumbers
        defaultTextEncoding = Self.defaultTextEncoding
        appearanceMode = Self.defaultAppearanceMode
    }
}
