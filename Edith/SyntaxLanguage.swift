//
//  SyntaxLanguage.swift
//  Edith
//

import Foundation
import UniformTypeIdentifiers

/// Supported syntax languages for highlighting
enum SyntaxLanguage: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case plain = "plain"
    case html = "html"
    case css = "css"
    case python = "python"
    case json = "json"
    case markdown = "markdown"
    case javascript = "javascript"
    case swift = "swift"
    case xml = "xml"
    case yaml = "yaml"
    case sql = "sql"
    case shell = "shell"
    
    var id: String { rawValue }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .auto: return "Auto-Detect"
        case .plain: return "Plain Text"
        case .html: return "HTML"
        case .css: return "CSS"
        case .python: return "Python"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .javascript: return "JavaScript"
        case .swift: return "Swift"
        case .xml: return "XML"
        case .yaml: return "YAML"
        case .sql: return "SQL"
        case .shell: return "Shell"
        }
    }
    
    /// Language identifier for HighlightSwift
    /// Returns nil for auto-detect mode
    var highlightLanguage: String? {
        switch self {
        case .auto: return nil
        case .plain: return nil
        case .html: return "html"
        case .css: return "css"
        case .python: return "python"
        case .json: return "json"
        case .markdown: return "markdown"
        case .javascript: return "javascript"
        case .swift: return "swift"
        case .xml: return "xml"
        case .yaml: return "yaml"
        case .sql: return "sql"
        case .shell: return "bash"
        }
    }
    
    /// Default file extension for this language
    var defaultExtension: String {
        switch self {
        case .auto, .plain: return "txt"
        case .html: return "html"
        case .css: return "css"
        case .python: return "py"
        case .json: return "json"
        case .markdown: return "md"
        case .javascript: return "js"
        case .swift: return "swift"
        case .xml: return "xml"
        case .yaml: return "yml"
        case .sql: return "sql"
        case .shell: return "sh"
        }
    }
    
    /// Detect language from UTType and optional filename
    static func detect(from contentType: UTType, filename: String?) -> SyntaxLanguage {
        // First try to detect from filename extension
        if let filename = filename {
            let ext = (filename as NSString).pathExtension.lowercased()
            if !ext.isEmpty {
                let detected = detect(from: URL(fileURLWithPath: filename))
                if detected != .plain && detected != .auto {
                    return detected
                }
            }
        }
        
        // Fall back to content type detection
        if contentType.conforms(to: .html) {
            return .html
        } else if contentType.conforms(to: .json) {
            return .json
        } else if contentType.conforms(to: .xml) || contentType.conforms(to: .propertyList) {
            return .xml
        } else if contentType.conforms(to: .yaml) {
            return .yaml
        } else if contentType.conforms(to: .shellScript) {
            return .shell
        } else if contentType.conforms(to: .pythonScript) {
            return .python
        } else if contentType.conforms(to: .swiftSource) {
            return .swift
        } else if contentType.identifier.contains("css") {
            return .css
        } else if contentType.identifier.contains("markdown") {
            return .markdown
        } else if contentType.identifier.contains("javascript") {
            return .javascript
        } else if contentType.identifier.contains("sql") {
            return .sql
        } else if contentType.conforms(to: .sourceCode) {
            // For generic source code, use auto-detect
            return .auto
        }
        
        // For plain text and unknown, no highlighting
        return .plain
    }
    
    /// Detect language from file extension
    static func detect(from url: URL?) -> SyntaxLanguage {
        guard let ext = url?.pathExtension.lowercased() else { return .plain }
        
        switch ext {
        case "html", "htm":
            return .html
        case "css":
            return .css
        case "py", "pyw":
            return .python
        case "json":
            return .json
        case "md", "markdown":
            return .markdown
        case "js", "mjs", "cjs":
            return .javascript
        case "swift":
            return .swift
        case "xml", "xsd", "xsl", "plist":
            return .xml
        case "yml", "yaml":
            return .yaml
        case "sql":
            return .sql
        case "sh", "bash", "zsh", "fish":
            return .shell
        case "txt", "text", "log", "cfg", "conf", "ini":
            return .plain
        default:
            // For unknown extensions, default to plain text (no highlighting)
            // rather than auto-detect which may incorrectly highlight
            return .plain
        }
    }
    
    /// Core languages that should always appear first in UI
    static var coreLanguages: [SyntaxLanguage] {
        [.auto, .plain, .html, .css, .python, .json, .markdown]
    }
    
    /// All languages except auto and plain (for display in "More" submenu)
    static var additionalLanguages: [SyntaxLanguage] {
        allCases.filter { $0 != .auto && $0 != .plain && !coreLanguages.contains($0) }
    }
}
