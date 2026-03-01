//
//  EditorView.swift
//  Edith
//

import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject var zoomState: DocumentZoomState
    @Binding var cursorPosition: CursorPosition
    var syntaxLanguage: SyntaxLanguage
    @ObservedObject var syntaxHighlighter: SyntaxHighlighter
    @ObservedObject var findReplaceState: FindReplaceState
    var vimModeState: VimModeState?
    
    func makeNSView(context: Context) -> LineNumberScrollView {
        let scrollView = LineNumberScrollView(vimModeState: vimModeState)
        let textView = scrollView.textView
        
        textView.delegate = context.coordinator
        textView.string = text
        
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        // Wire up find/replace state to text view
        findReplaceState.textView = textView
        
        // Wire up vim mode state to text view (if enabled)
        vimModeState?.textView = textView
        
        applySettings(to: scrollView)
        
        // Apply initial syntax highlighting (in-place, doesn't replace content)
        applyHighlighting(to: scrollView, immediate: true)
        
        // Make text view first responder after a brief delay to ensure window is ready
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: LineNumberScrollView, context: Context) {
        let textView = scrollView.textView
        
        // Check if text changed externally (e.g., file reload)
        let textChanged = textView.string != text
        if textChanged {
            // Preserve selection
            let selectedRanges = textView.selectedRanges
            textView.string = text
            
            // Restore selection if valid
            if let firstRange = selectedRanges.first?.rangeValue,
               firstRange.location <= text.count {
                let validRange = NSRange(
                    location: min(firstRange.location, text.count),
                    length: min(firstRange.length, text.count - min(firstRange.location, text.count))
                )
                textView.setSelectedRange(validRange)
            }
            
            // Re-highlight after external text change
            applyHighlighting(to: scrollView, immediate: true)
        }
        
        applySettings(to: scrollView)
        
        // Re-apply highlighting when language changes
        if context.coordinator.lastLanguage != syntaxLanguage {
            context.coordinator.lastLanguage = syntaxLanguage
            applyHighlighting(to: scrollView, immediate: true)
        }
    }
    
    private func applySettings(to scrollView: LineNumberScrollView) {
        let textView = scrollView.textView
        // Combine settings magnification with per-document zoom
        let effectiveMagnification = settingsManager.magnification * zoomState.zoom
        // Combine settings font size with per-document offset
        let effectiveFontSize = settingsManager.fontSize + zoomState.fontSizeOffset
        let size = CGFloat(effectiveFontSize * effectiveMagnification)
        let font = NSFont(name: settingsManager.fontName, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        
        textView.font = font
        scrollView.lineNumberView.font = font
        scrollView.currentFont = font
        
        // Set baseline width when at default zoom (zoom=1.0)
        if zoomState.zoom == 1.0 {
            scrollView.lineNumberView.setBaselineWidth()
        }
        
        scrollView.showLineNumbers = settingsManager.showLineNumbers
        scrollView.customLayoutManager.showInvisibleCharacters = settingsManager.showInvisibleCharacters
    }
    
    private func applyHighlighting(to scrollView: LineNumberScrollView, immediate: Bool) {
        guard let textStorage = scrollView.textView.textStorage else { return }
        let font = scrollView.currentFont
        
        if immediate {
            Task { @MainActor in
                await syntaxHighlighter.highlightImmediately(
                    text,
                    language: syntaxLanguage,
                    textStorage: textStorage,
                    baseFont: font
                )
            }
        } else {
            syntaxHighlighter.highlightText(
                text,
                language: syntaxLanguage,
                textStorage: textStorage,
                baseFont: font
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?
        weak var scrollView: LineNumberScrollView?
        var lastLanguage: SyntaxLanguage = .auto
        
        init(_ parent: EditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scrollView?.lineNumberView.needsDisplay = true
            updateCursorPosition()
            
            // Trigger debounced highlighting (applies colors in-place, doesn't disrupt typing)
            if let textStorage = textView.textStorage,
               let scrollView = scrollView {
                parent.syntaxHighlighter.highlightText(
                    textView.string,
                    language: parent.syntaxLanguage,
                    textStorage: textStorage,
                    baseFont: scrollView.currentFont
                )
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            updateCursorPosition()
        }
        
        private func updateCursorPosition() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let newPosition = CursorPosition.calculate(for: textView.string, at: selectedRange.location)
            DispatchQueue.main.async {
                self.parent.cursorPosition = newPosition
            }
        }
    }
}

// MARK: - Custom Scroll View with Line Numbers
class LineNumberScrollView: NSView {
    let scrollView: NSScrollView
    let textView: VimTextView
    let lineNumberView: LineNumberView
    let customLayoutManager: InvisibleCharacterLayoutManager
    
    var currentFont: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    
    var showLineNumbers: Bool = true {
        didSet {
            lineNumberView.isHidden = !showLineNumbers
            needsLayout = true
        }
    }
    
    init(frame: NSRect = .zero, vimModeState: VimModeState? = nil) {
        // Create text storage
        let textStorage = NSTextStorage()
        
        // Create custom layout manager for invisible characters
        customLayoutManager = InvisibleCharacterLayoutManager()
        textStorage.addLayoutManager(customLayoutManager)
        
        // Create text container
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        customLayoutManager.addTextContainer(textContainer)
        
        // Create vim-aware text view with custom text system
        textView = VimTextView(frame: .zero, textContainer: textContainer)
        textView.vimModeState = vimModeState
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 5, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        
        // Create line number view
        lineNumberView = LineNumberView()
        lineNumberView.textView = textView
        
        super.init(frame: frame)
        
        addSubview(lineNumberView)
        addSubview(scrollView)
        
        // Observe scroll and text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textOrScrollChanged),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textOrScrollChanged),
            name: NSText.didChangeNotification,
            object: textView
        )
        
        scrollView.contentView.postsBoundsChangedNotifications = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func textOrScrollChanged(_ notification: Notification) {
        lineNumberView.needsDisplay = true
    }
    
    override func layout() {
        super.layout()
        if showLineNumbers {
            let gutterWidth: CGFloat = lineNumberView.requiredWidth
            lineNumberView.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: bounds.height)
            scrollView.frame = NSRect(x: gutterWidth, y: 0, width: bounds.width - gutterWidth, height: bounds.height)
        } else {
            lineNumberView.frame = .zero
            scrollView.frame = bounds
        }
    }
}

// MARK: - Vim-aware Text View
class VimTextView: NSTextView {
    weak var vimModeState: VimModeState?
    
    override func keyDown(with event: NSEvent) {
        guard let vimState = vimModeState else {
            super.keyDown(with: event)
            return
        }
        
        // Check for Esc key
        if event.keyCode == 53 { // Esc key
            if vimState.handleEscPress() {
                return // Double-tap handled mode toggle
            }
            // Single Esc - let it pass for now, will be handled by delayed check
            return
        }
        
        // Handle based on current mode
        switch vimState.mode {
        case .insert:
            // Normal text editing
            super.keyDown(with: event)
            
        case .normal:
            // Vim normal mode - intercept keys
            if let chars = event.charactersIgnoringModifiers {
                for char in chars {
                    if vimState.handleNormalModeKey(String(char), modifiers: event.modifierFlags) {
                        return
                    }
                }
            }
            // Unhandled key in normal mode - ignore (don't insert text)
            
        case .command:
            // Command mode - handle typing in command bar
            if event.keyCode == 36 { // Return key
                _ = vimState.handleCommandKey("\r")
            } else if event.keyCode == 51 { // Delete key
                vimState.deleteFromCommand()
            } else if let chars = event.characters {
                for char in chars {
                    vimState.appendToCommand(char)
                }
            }
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Allow standard key equivalents (Cmd+C, Cmd+V, etc.) in all modes
        if event.modifierFlags.contains(.command) {
            return super.performKeyEquivalent(with: event)
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Line Number View
class LineNumberView: NSView {
    weak var textView: NSTextView?
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet {
            needsDisplay = true
            superview?.needsLayout = true
        }
    }
    
    // Track the baseline width at default zoom (zoom=1.0)
    private var baselineWidth: CGFloat = 0
    
    // Mouse tracking for line selection
    private var isDragging = false
    private var dragStartLine: Int?
    private var commandKeyHeld = false
    
    // Set the baseline width - call this when at default zoom level
    func setBaselineWidth() {
        baselineWidth = calculateCurrentWidth()
    }
    
    // Calculate width based on current font
    private func calculateCurrentWidth() -> CGFloat {
        guard let textView = textView else { return 50 }
        let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
        let digits = max(3, String(lineCount).count)
        
        let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize * 0.85, weight: .regular)
        let sampleNumber = String(repeating: "8", count: digits)
        let attrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        // Wider padding: 12pt left + 12pt right = 24pt total
        return sampleNumber.size(withAttributes: attrs).width + 24
    }
    
    // Width never shrinks below baseline (default zoom width)
    var requiredWidth: CGFloat {
        let currentWidth = calculateCurrentWidth()
        // If baseline not set yet, use current as baseline
        if baselineWidth == 0 {
            baselineWidth = currentWidth
        }
        return max(baselineWidth, currentWidth)
    }
    
    // Use flipped coordinates to match NSTextView
    override var isFlipped: Bool { true }
    
    // MARK: - Mouse Handling for Line Selection
    
    override func mouseDown(with event: NSEvent) {
        guard let textView = textView else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        commandKeyHeld = event.modifierFlags.contains(.command)
        
        if let lineNumber = lineNumber(at: location) {
            isDragging = true
            dragStartLine = lineNumber
            
            // Make text view first responder
            window?.makeFirstResponder(textView)
            
            if commandKeyHeld {
                // Command+click: toggle this line in selection
                toggleLineSelection(lineNumber)
            } else {
                // Normal click: select just this line
                selectLines(from: lineNumber, to: lineNumber)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let startLine = dragStartLine, !commandKeyHeld else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        if let currentLine = lineNumber(at: location) {
            selectLines(from: startLine, to: currentLine)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        dragStartLine = nil
        commandKeyHeld = false
    }
    
    // Get line number at a y position in the gutter
    private func lineNumber(at point: NSPoint) -> Int? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        
        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let inset = textView.textContainerInset
        
        // Convert point to text view coordinates
        let textViewY = point.y + visibleRect.origin.y - inset.height
        
        if content.length == 0 {
            return 1
        }
        
        // Find which line this y coordinate corresponds to
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        // Count lines before visible range
        var lineNum = 1
        var idx = 0
        while idx < charRange.location {
            let range = content.lineRange(for: NSRange(location: idx, length: 0))
            lineNum += 1
            idx = NSMaxRange(range)
        }
        
        // Find line at this y position
        idx = charRange.location
        while idx < content.length {
            let range = content.lineRange(for: NSRange(location: idx, length: 0))
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: idx)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            
            let lineTop = lineRect.origin.y
            let lineBottom = lineRect.origin.y + lineRect.height
            
            if textViewY >= lineTop && textViewY < lineBottom {
                return lineNum
            }
            
            lineNum += 1
            idx = NSMaxRange(range)
        }
        
        // Check for trailing empty line after final newline
        if content.length > 0 {
            let lastChar = content.character(at: content.length - 1)
            if lastChar == 0x0A || lastChar == 0x0D {
                let lastGlyphIdx = layoutManager.glyphIndexForCharacter(at: content.length - 1)
                let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIdx, effectiveRange: nil)
                let trailingTop = lastLineRect.origin.y + lastLineRect.height
                if textViewY >= trailingTop {
                    return lineNum
                }
            }
        }
        
        return nil
    }
    
    // Get the character range for a given line number (1-based)
    private func rangeForLine(_ lineNumber: Int) -> NSRange? {
        guard let textView = textView else { return nil }
        let content = textView.string as NSString
        
        if content.length == 0 {
            return lineNumber == 1 ? NSRange(location: 0, length: 0) : nil
        }
        
        var currentLine = 1
        var idx = 0
        
        while idx < content.length {
            let range = content.lineRange(for: NSRange(location: idx, length: 0))
            if currentLine == lineNumber {
                return range
            }
            currentLine += 1
            idx = NSMaxRange(range)
        }
        
        // Handle trailing empty line
        if currentLine == lineNumber && content.length > 0 {
            let lastChar = content.character(at: content.length - 1)
            if lastChar == 0x0A || lastChar == 0x0D {
                return NSRange(location: content.length, length: 0)
            }
        }
        
        return nil
    }
    
    // Select lines from startLine to endLine (inclusive, 1-based)
    private func selectLines(from startLine: Int, to endLine: Int) {
        guard let textView = textView else { return }
        
        let minLine = min(startLine, endLine)
        let maxLine = max(startLine, endLine)
        
        guard let startRange = rangeForLine(minLine),
              let endRange = rangeForLine(maxLine) else { return }
        
        let selectionStart = startRange.location
        let selectionEnd = NSMaxRange(endRange)
        let selectionRange = NSRange(location: selectionStart, length: selectionEnd - selectionStart)
        
        textView.setSelectedRange(selectionRange)
        needsDisplay = true
    }
    
    // Toggle a line in the current selection (for Command+click)
    private func toggleLineSelection(_ lineNumber: Int) {
        guard let textView = textView,
              let lineRange = rangeForLine(lineNumber) else { return }
        
        var currentRanges = textView.selectedRanges.compactMap { $0.rangeValue }
        
        // Check if this line is already selected
        let lineStart = lineRange.location
        let lineEnd = NSMaxRange(lineRange)
        
        var foundIndex: Int?
        for (index, range) in currentRanges.enumerated() {
            if range.location <= lineStart && NSMaxRange(range) >= lineEnd {
                foundIndex = index
                break
            }
        }
        
        if let index = foundIndex {
            // Line is selected - try to remove it
            let range = currentRanges[index]
            if range.location == lineStart && NSMaxRange(range) == lineEnd {
                // Exact match, remove it
                currentRanges.remove(at: index)
            } else {
                // Line is part of larger selection - split around it
                let beforeRange = NSRange(location: range.location, length: lineStart - range.location)
                let afterRange = NSRange(location: lineEnd, length: NSMaxRange(range) - lineEnd)
                
                currentRanges.remove(at: index)
                if beforeRange.length > 0 {
                    currentRanges.append(beforeRange)
                }
                if afterRange.length > 0 {
                    currentRanges.append(afterRange)
                }
            }
        } else {
            // Line not selected - add it
            currentRanges.append(lineRange)
        }
        
        // Sort and apply ranges
        if currentRanges.isEmpty {
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
        } else {
            currentRanges.sort { $0.location < $1.location }
            textView.setSelectedRanges(currentRanges.map { NSValue(range: $0) }, affinity: .downstream, stillSelecting: false)
        }
        needsDisplay = true
    }
    
    // Gutter background color: light gray in light mode, dark complement in dark mode
    private static let gutterBackgroundColor: NSColor = {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                // Dark mode: RGB 40,40,40
                return NSColor(red: 40/255, green: 40/255, blue: 40/255, alpha: 1.0)
            } else {
                // Light mode: RGB 235,235,235
                return NSColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1.0)
            }
        }
    }()
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        Self.gutterBackgroundColor.setFill()
        bounds.fill()
        
        // Separator
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: 0))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.stroke()
        
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: font.pointSize * 0.85, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let visibleRect = textView.visibleRect
        let content = textView.string as NSString
        let inset = textView.textContainerInset
        
        // Calculate max width for right-alignment (based on total line count)
        let totalLines = max(1, content.components(separatedBy: "\n").count)
        let maxDigits = max(3, String(totalLines).count)
        let maxNumberWidth = String(repeating: "8", count: maxDigits).size(withAttributes: attrs).width
        // Center the number column in the gutter
        let columnLeftEdge = (bounds.width - maxNumberWidth) / 2
        
        if content.length == 0 {
            let s = "1"
            let sz = s.size(withAttributes: attrs)
            // Right-align within centered column
            let xPos = columnLeftEdge + (maxNumberWidth - sz.width)
            s.draw(at: NSPoint(x: xPos, y: inset.height), withAttributes: attrs)
            return
        }
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        // Count lines before visible range
        var lineNum = 1
        var idx = 0
        while idx < charRange.location {
            let range = content.lineRange(for: NSRange(location: idx, length: 0))
            lineNum += 1
            idx = NSMaxRange(range)
        }
        
        // Draw visible line numbers
        idx = charRange.location
        while idx <= NSMaxRange(charRange) {
            // Handle the case where cursor is on a new empty line after trailing newline
            let isTrailingEmptyLine = idx >= content.length && content.length > 0 && 
                (content.character(at: content.length - 1) == 0x0A || content.character(at: content.length - 1) == 0x0D)
            
            if idx >= content.length && content.length > 0 && !isTrailingEmptyLine {
                break
            }
            
            let safeIdx = min(idx, max(0, content.length - 1))
            let range = content.lineRange(for: NSRange(location: safeIdx, length: 0))
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: safeIdx)
            
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            
            // For trailing empty line, calculate position below the last line
            if isTrailingEmptyLine {
                let lastGlyphIdx = layoutManager.glyphIndexForCharacter(at: content.length - 1)
                let lastLineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIdx, effectiveRange: nil)
                lineRect = NSRect(x: lastLineRect.origin.x, 
                                  y: lastLineRect.origin.y + lastLineRect.height,
                                  width: lastLineRect.width, 
                                  height: lastLineRect.height)
            }
            
            // Convert from text view coordinates to our view coordinates
            let yPos = lineRect.origin.y + inset.height - visibleRect.origin.y
            
            let s = "\(lineNum)"
            let sz = s.size(withAttributes: attrs)
            // Right-align within centered column
            let xPos = columnLeftEdge + (maxNumberWidth - sz.width)
            let pt = NSPoint(x: xPos, y: yPos + (lineRect.height - sz.height) / 2)
            s.draw(at: pt, withAttributes: attrs)
            
            lineNum += 1
            
            if isTrailingEmptyLine {
                break
            }
            idx = NSMaxRange(range)
        }
    }
}

// MARK: - Custom Layout Manager for Invisible Characters
class InvisibleCharacterLayoutManager: NSLayoutManager {
    
    var showInvisibleCharacters: Bool = false {
        didSet {
            invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage?.length ?? 0))
        }
    }
    
    // Light gray color for invisible characters
    private let invisibleColor = NSColor(calibratedWhite: 0.7, alpha: 1.0)
    
    // Unicode characters for invisibles
    private let spaceGlyph: String = "·"              // Middle dot for space
    private let nonBreakingSpaceGlyph: String = "°"   // Degree symbol for non-breaking space
    private let newlineGlyph: String = "↵"            // Return symbol for newline  
    private let tabGlyph: String = "△"                // Delta for tab
    private let formFeedGlyph: String = "▽"           // Down triangle for form feed
    private let verticalTabGlyph: String = "↧"        // Down arrow to bar for vertical tab
    
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        
        guard showInvisibleCharacters,
              let textStorage = textStorage,
              textContainers.first != nil else { return }
        
        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let string = textStorage.string as NSString
        
        string.enumerateSubstrings(in: characterRange, options: .byComposedCharacterSequences) { [weak self] substring, substringRange, _, _ in
            guard let self = self, let char = substring else { return }
            
            var glyph: String?
            
            switch char {
            case " ":
                glyph = self.spaceGlyph
            case "\u{00A0}":  // Non-breaking space
                glyph = self.nonBreakingSpaceGlyph
            case "\n":
                glyph = self.newlineGlyph
            case "\t":
                glyph = self.tabGlyph
            case "\r":
                glyph = self.newlineGlyph
            case "\u{000C}":  // Form feed
                glyph = self.formFeedGlyph
            case "\u{000B}":  // Vertical tab
                glyph = self.verticalTabGlyph
            default:
                return
            }
            
            guard let glyphToDraw = glyph else { return }
            
            let glyphIndex = self.glyphIndexForCharacter(at: substringRange.location)
            _ = self.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
            let glyphLocation = self.location(forGlyphAt: glyphIndex)
            let lineRect = self.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            
            // Get the font at this location
            var effectiveRange = NSRange()
            let attrs = textStorage.attributes(at: substringRange.location, effectiveRange: &effectiveRange)
            let font = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 12)
            
            // Create attributes for invisible character
            let invisibleAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: self.invisibleColor
            ]
            
            // Calculate position
            let point = NSPoint(
                x: origin.x + lineRect.origin.x + glyphLocation.x,
                y: origin.y + lineRect.origin.y
            )
            
            // Draw the invisible character
            glyphToDraw.draw(at: point, withAttributes: invisibleAttrs)
        }
    }
}
