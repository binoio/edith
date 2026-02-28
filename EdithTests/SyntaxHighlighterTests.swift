//
//  SyntaxHighlighterTests.swift
//  EdithTests
//

import XCTest
@testable import Edith

final class SyntaxHighlighterTests: XCTestCase {
    
    // MARK: - SyntaxLanguage Enum Tests
    
    func testSyntaxLanguageRawValues() {
        XCTAssertEqual(SyntaxLanguage.auto.rawValue, "auto")
        XCTAssertEqual(SyntaxLanguage.plain.rawValue, "plain")
        XCTAssertEqual(SyntaxLanguage.html.rawValue, "html")
        XCTAssertEqual(SyntaxLanguage.css.rawValue, "css")
        XCTAssertEqual(SyntaxLanguage.python.rawValue, "python")
        XCTAssertEqual(SyntaxLanguage.json.rawValue, "json")
        XCTAssertEqual(SyntaxLanguage.markdown.rawValue, "markdown")
    }
    
    func testSyntaxLanguageDisplayNames() {
        XCTAssertEqual(SyntaxLanguage.auto.displayName, "Auto-Detect")
        XCTAssertEqual(SyntaxLanguage.plain.displayName, "Plain Text")
        XCTAssertEqual(SyntaxLanguage.html.displayName, "HTML")
        XCTAssertEqual(SyntaxLanguage.css.displayName, "CSS")
        XCTAssertEqual(SyntaxLanguage.python.displayName, "Python")
        XCTAssertEqual(SyntaxLanguage.json.displayName, "JSON")
        XCTAssertEqual(SyntaxLanguage.markdown.displayName, "Markdown")
        XCTAssertEqual(SyntaxLanguage.javascript.displayName, "JavaScript")
        XCTAssertEqual(SyntaxLanguage.swift.displayName, "Swift")
    }
    
    func testHighlightLanguageIdentifiers() {
        // Auto and plain should return nil (no highlighting)
        XCTAssertNil(SyntaxLanguage.auto.highlightLanguage)
        XCTAssertNil(SyntaxLanguage.plain.highlightLanguage)
        
        // Others should return their highlight.js identifiers
        XCTAssertEqual(SyntaxLanguage.html.highlightLanguage, "html")
        XCTAssertEqual(SyntaxLanguage.css.highlightLanguage, "css")
        XCTAssertEqual(SyntaxLanguage.python.highlightLanguage, "python")
        XCTAssertEqual(SyntaxLanguage.json.highlightLanguage, "json")
        XCTAssertEqual(SyntaxLanguage.markdown.highlightLanguage, "markdown")
        XCTAssertEqual(SyntaxLanguage.shell.highlightLanguage, "bash")
    }
    
    // MARK: - Default Extension Tests
    
    func testDefaultExtensions() {
        XCTAssertEqual(SyntaxLanguage.auto.defaultExtension, "txt")
        XCTAssertEqual(SyntaxLanguage.plain.defaultExtension, "txt")
        XCTAssertEqual(SyntaxLanguage.html.defaultExtension, "html")
        XCTAssertEqual(SyntaxLanguage.css.defaultExtension, "css")
        XCTAssertEqual(SyntaxLanguage.python.defaultExtension, "py")
        XCTAssertEqual(SyntaxLanguage.json.defaultExtension, "json")
        XCTAssertEqual(SyntaxLanguage.markdown.defaultExtension, "md")
        XCTAssertEqual(SyntaxLanguage.javascript.defaultExtension, "js")
        XCTAssertEqual(SyntaxLanguage.swift.defaultExtension, "swift")
        XCTAssertEqual(SyntaxLanguage.xml.defaultExtension, "xml")
        XCTAssertEqual(SyntaxLanguage.yaml.defaultExtension, "yml")
        XCTAssertEqual(SyntaxLanguage.sql.defaultExtension, "sql")
        XCTAssertEqual(SyntaxLanguage.shell.defaultExtension, "sh")
    }
    
    // MARK: - File Extension Detection Tests
    
    func testDetectHTMLFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.html")), .html)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.htm")), .html)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.HTML")), .html)
    }
    
    func testDetectCSSFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/styles.css")), .css)
    }
    
    func testDetectPythonFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/script.py")), .python)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/script.pyw")), .python)
    }
    
    func testDetectJSONFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/data.json")), .json)
    }
    
    func testDetectMarkdownFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/readme.md")), .markdown)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/docs.markdown")), .markdown)
    }
    
    func testDetectJavaScriptFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/app.js")), .javascript)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/module.mjs")), .javascript)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/common.cjs")), .javascript)
    }
    
    func testDetectSwiftFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/main.swift")), .swift)
    }
    
    func testDetectXMLFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/data.xml")), .xml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/schema.xsd")), .xml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/Info.plist")), .xml)
    }
    
    func testDetectYAMLFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/config.yml")), .yaml)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/config.yaml")), .yaml)
    }
    
    func testDetectSQLFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/query.sql")), .sql)
    }
    
    func testDetectShellFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/script.sh")), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/script.bash")), .shell)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/script.zsh")), .shell)
    }
    
    func testDetectPlainTextFromExtension() {
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/notes.txt")), .plain)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/notes.text")), .plain)
    }
    
    func testDetectPlainForUnknownExtension() {
        // Unknown extensions default to plain text (no highlighting)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.xyz")), .plain)
        XCTAssertEqual(SyntaxLanguage.detect(from: URL(fileURLWithPath: "/test/file.unknown")), .plain)
    }
    
    func testDetectPlainForNilURL() {
        XCTAssertEqual(SyntaxLanguage.detect(from: nil), .plain)
    }
    
    // MARK: - Core Languages Tests
    
    func testCoreLanguagesIncludesEssentials() {
        let coreLanguages = SyntaxLanguage.coreLanguages
        
        XCTAssertTrue(coreLanguages.contains(.auto))
        XCTAssertTrue(coreLanguages.contains(.plain))
        XCTAssertTrue(coreLanguages.contains(.html))
        XCTAssertTrue(coreLanguages.contains(.css))
        XCTAssertTrue(coreLanguages.contains(.python))
        XCTAssertTrue(coreLanguages.contains(.json))
        XCTAssertTrue(coreLanguages.contains(.markdown))
    }
    
    func testAdditionalLanguagesExcludesCore() {
        let additional = SyntaxLanguage.additionalLanguages
        
        XCTAssertFalse(additional.contains(.auto))
        XCTAssertFalse(additional.contains(.plain))
        XCTAssertTrue(additional.contains(.swift))
        XCTAssertTrue(additional.contains(.javascript))
    }
    
    // MARK: - TextDocument Integration Tests
    
    func testTextDocumentHasSyntaxLanguage() {
        let doc = TextDocument(text: "test")
        XCTAssertEqual(doc.syntaxLanguage, .auto)
    }
    
    func testTextDocumentSyntaxLanguageCanBeChanged() {
        var doc = TextDocument(text: "test")
        doc.syntaxLanguage = .python
        XCTAssertEqual(doc.syntaxLanguage, .python)
    }
    
    // MARK: - Codable Tests
    
    func testSyntaxLanguageIsCodable() throws {
        let original = SyntaxLanguage.python
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SyntaxLanguage.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }
}
