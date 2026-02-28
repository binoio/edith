//
//  StatusBar.swift
//  Edith
//

import SwiftUI

struct StatusBar: View {
    @Binding var document: TextDocument
    @Binding var cursorPosition: CursorPosition
    var detectedLanguage: String?
    
    var body: some View {
        HStack(spacing: 16) {
            // Cursor position: Line and Column
            Text("Ln \(cursorPosition.line), Col \(cursorPosition.column)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            
            Divider()
                .frame(height: 12)
            
            // Character, Word, Line counts
            let stats = textStatistics
            Text("\(stats.characters) characters, \(stats.words) words, \(stats.lines) lines")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Syntax Language picker
            Menu {
                ForEach(SyntaxLanguage.coreLanguages) { lang in
                    languageButton(for: lang)
                }
                
                Divider()
                
                Menu("More...") {
                    ForEach(SyntaxLanguage.additionalLanguages) { lang in
                        languageButton(for: lang)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(languageDisplayText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Divider()
                .frame(height: 12)
            
            // Line Ending picker
            Menu {
                ForEach(LineEnding.allCases) { ending in
                    Button(action: {
                        document.lineEnding = ending
                    }) {
                        HStack {
                            Text(ending.description)
                            if document.lineEnding == ending {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(document.lineEnding.shortDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Divider()
                .frame(height: 12)
            
            // Text Encoding picker
            Menu {
                ForEach(TextEncodingOption.allCases) { encoding in
                    Button(action: {
                        document.encoding = encoding
                    }) {
                        HStack {
                            Text(encoding.description)
                            if document.encoding == encoding {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(document.encoding.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
    
    private var textStatistics: (characters: Int, words: Int, lines: Int) {
        let text = document.text
        let characters = text.count
        
        // Word count: split by whitespace and newlines
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        
        // Line count: count newlines + 1 (empty document has 1 line)
        let lines = max(1, text.components(separatedBy: .newlines).count)
        
        return (characters, words, lines)
    }
    
    private var languageDisplayText: String {
        if document.syntaxLanguage == .auto {
            if let detected = detectedLanguage {
                return "Auto (\(detected))"
            }
            return "Auto-Detect"
        }
        return document.syntaxLanguage.displayName
    }
    
    @ViewBuilder
    private func languageButton(for lang: SyntaxLanguage) -> some View {
        Button(action: {
            document.syntaxLanguage = lang
        }) {
            HStack {
                Text(lang.displayName)
                if document.syntaxLanguage == lang {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

// Cursor position tracking
struct CursorPosition: Equatable {
    var line: Int = 1
    var column: Int = 1
    var characterIndex: Int = 0
    
    static func calculate(for text: String, at characterIndex: Int) -> CursorPosition {
        guard characterIndex >= 0 else {
            return CursorPosition(line: 1, column: 1, characterIndex: 0)
        }
        
        let clampedIndex = min(characterIndex, text.count)
        let textUpToCursor = String(text.prefix(clampedIndex))
        
        // Count lines (newlines + 1)
        let lines = textUpToCursor.components(separatedBy: .newlines)
        let line = lines.count
        
        // Column is the length of the last line + 1 (1-indexed)
        let column = (lines.last?.count ?? 0) + 1
        
        return CursorPosition(line: line, column: column, characterIndex: clampedIndex)
    }
}
