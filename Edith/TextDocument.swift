//
//  TextDocument.swift
//  Edith
//

import SwiftUI
import UniformTypeIdentifiers

// Global flag to track when Edith is saving (to avoid false file-change alerts)
class EdithSaveTracker {
    static let shared = EdithSaveTracker()
    private var saveCount = 0
    private var lastSaveCompletedTime: Date?
    
    func markSaveStarted() {
        saveCount += 1
    }
    
    func markSaveCompleted() {
        lastSaveCompletedTime = Date()
        // Decrement save count after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.saveCount = max(0, self.saveCount - 1)
        }
    }
    
    func shouldSuppressFileChangeAlert() -> Bool {
        // Suppress if we're actively in a save operation
        if saveCount > 0 { return true }
        // Also suppress if a save completed very recently (within 500ms)
        if let lastComplete = lastSaveCompletedTime, Date().timeIntervalSince(lastComplete) < 0.5 {
            return true
        }
        return false
    }
    
    func clearSuppression() {
        // Called after suppression window, resets state
        lastSaveCompletedTime = nil
    }
}

struct TextDocument: FileDocument {
    var text: String
    var encoding: TextEncodingOption
    var lineEnding: LineEnding
    var syntaxLanguage: SyntaxLanguage
    
    // All file types the app can open
    static var readableContentTypes: [UTType] {
        [
            .plainText,
            .html,
            .xml,
            .json,
            .yaml,
            .shellScript,
            .pythonScript,
            .swiftSource,
            .sourceCode,
            // Custom types for common extensions
            UTType("public.css") ?? .plainText,
            UTType("public.markdown") ?? .plainText,
            UTType("net.daringfireball.markdown") ?? .plainText,
            UTType("public.sql") ?? .plainText,
            UTType("com.netscape.javascript-source") ?? .plainText,
        ].compactMap { $0 }
    }
    
    // Default to plain text for new documents, but allow saving as any type
    static var writableContentTypes: [UTType] { [.plainText] }
    
    init(text: String = "") {
        self.text = text
        // Default encoding from settings
        let encodingIndex = UserDefaults.standard.integer(forKey: "defaultTextEncoding")
        self.encoding = TextEncodingOption(rawValue: encodingIndex) ?? .utf8
        self.lineEnding = LineEnding.detect(in: text)
        self.syntaxLanguage = .auto
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Try to decode with the default encoding from settings
        let encodingIndex = UserDefaults.standard.integer(forKey: "defaultTextEncoding")
        let defaultEncoding = TextEncodingOption(rawValue: encodingIndex) ?? .utf8
        
        if let string = String(data: data, encoding: defaultEncoding.stringEncoding) {
            text = string
            encoding = defaultEncoding
        } else if let string = String(data: data, encoding: .utf8) {
            text = string
            encoding = .utf8
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Detect line ending from content
        lineEnding = LineEnding.detect(in: text)
        
        // Detect syntax from content type or filename
        syntaxLanguage = SyntaxLanguage.detect(from: configuration.contentType, filename: configuration.file.preferredFilename)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Mark that Edith is saving
        EdithSaveTracker.shared.markSaveStarted()
        
        // Normalize line endings before saving
        var outputText = text
        
        // First normalize all line endings to LF
        outputText = outputText.replacingOccurrences(of: "\r\n", with: "\n")
        outputText = outputText.replacingOccurrences(of: "\r", with: "\n")
        
        // Then convert to the target line ending
        if lineEnding == .crlf {
            outputText = outputText.replacingOccurrences(of: "\n", with: "\r\n")
        } else if lineEnding == .cr {
            outputText = outputText.replacingOccurrences(of: "\n", with: "\r")
        }
        
        guard let data = outputText.data(using: encoding.stringEncoding) ?? outputText.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        // Mark save as completing (with delay for file system)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            EdithSaveTracker.shared.markSaveCompleted()
        }
        
        return FileWrapper(regularFileWithContents: data)
    }
}
