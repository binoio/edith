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
    @Binding var selectedText: String
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
        
        // Update vim mode state reference (may change when setting toggled)
        textView.vimModeState = vimModeState
        vimModeState?.textView = textView
        
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

        // Line height applies through a paragraph style, on the default and
        // typing attributes for new text and across the storage for existing
        // text; the highlighter only touches font and color, so it survives
        let lineHeight = CGFloat(settingsManager.lineHeightMultiple)
        if scrollView.currentLineHeightMultiple != lineHeight {
            scrollView.currentLineHeightMultiple = lineHeight
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = lineHeight
            textView.defaultParagraphStyle = style
            textView.typingAttributes[.paragraphStyle] = style
            if let storage = textView.textStorage, storage.length > 0 {
                storage.addAttribute(.paragraphStyle, value: style,
                                     range: NSRange(location: 0, length: storage.length))
            }
            scrollView.lineNumberView.needsDisplay = true
        }
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
            
            // Find results index into the text as it was; an edit invalidates them
            parent.findReplaceState.noteDocumentChanged()
            
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
            updateSelectedText()
        }
        
        private func updateCursorPosition() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let newPosition = CursorPosition.calculate(for: textView.string, at: selectedRange.location)
            DispatchQueue.main.async {
                self.parent.cursorPosition = newPosition
            }
        }
        
        private func updateSelectedText() {
            guard let textView = textView else { return }
            let text = textView.string as NSString
            
            // Handle multiple non-contiguous selections (e.g., from Command+click)
            let ranges = textView.selectedRanges.compactMap { $0.rangeValue }
            var selectedParts: [String] = []
            
            for range in ranges {
                if range.length > 0 {
                    selectedParts.append(text.substring(with: range))
                }
            }
            
            let selectedText = selectedParts.joined(separator: "\n")
            DispatchQueue.main.async {
                self.parent.selectedText = selectedText
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
    var currentLineHeightMultiple: CGFloat = 1.0

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
    private var windowKeyObserver: NSObjectProtocol?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let observer = windowKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            windowKeyObserver = nil
        }
        
        guard let window = window else { return }
        
        windowKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            if window.firstResponder != self {
                window.makeFirstResponder(self)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
            if self.selectedRange().location == NSNotFound {
                self.setSelectedRange(NSRange(location: 0, length: 0))
            }
        }
    }
    
    deinit {
        if let observer = windowKeyObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
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

/// One line number the gutter should show: which number, where to draw it,
/// and the full vertical extent of the line it labels (wrapped rows included).
struct GutterLine: Equatable {
    let number: Int
    /// Rect of the line's first layout fragment, in gutter coordinates
    let rect: NSRect
    /// Rect spanning every fragment of the line, in gutter coordinates.
    /// Used for click targets so wrapped lines stay clickable all the way down.
    let hitRect: NSRect
}

class LineNumberView: NSView {
    weak var textView: NSTextView? {
        didSet { observeTextStorage() }
    }
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
    
    // Character index where each logical line begins. Rebuilt only when the
    // text changes, so drawing and hit testing cost a binary search rather
    // than a walk from the top of the document on every scroll tick.
    private var lineStarts: [Int] = [0]
    private var lineStartsValid = false
    private var textStorageObserver: NSObjectProtocol?
    
    deinit {
        if let observer = textStorageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func observeTextStorage() {
        if let observer = textStorageObserver {
            NotificationCenter.default.removeObserver(observer)
            textStorageObserver = nil
        }
        lineStartsValid = false
        
        guard let textStorage = textView?.textStorage else { return }
        textStorageObserver = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: textStorage,
            queue: .main
        ) { [weak self] notification in
            guard let storage = notification.object as? NSTextStorage,
                  storage.editedMask.contains(.editedCharacters) else { return }
            self?.lineStartsValid = false
            self?.needsDisplay = true
            self?.superview?.needsLayout = true
        }
    }
    
    /// Drop the cached line index; the next draw rebuilds it
    func invalidateLineStarts() {
        lineStartsValid = false
    }
    
    private func ensureLineStarts(_ content: NSString) {
        guard !lineStartsValid else { return }
        
        var starts: [Int] = [0]
        var idx = 0
        while idx < content.length {
            let range = content.lineRange(for: NSRange(location: idx, length: 0))
            idx = NSMaxRange(range)
            if idx < content.length {
                starts.append(idx)
            }
        }
        lineStarts = starts
        lineStartsValid = true
    }
    
    /// Zero-based index into `lineStarts` of the line containing `location`
    private func lineIndex(containing location: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        var best = 0
        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] <= location {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return best
    }
    
    private func endsWithNewline(_ content: NSString) -> Bool {
        guard content.length > 0 else { return false }
        let last = content.character(at: content.length - 1)
        return last == 0x0A || last == 0x0D
    }
    
    /// Total numbered lines, counting the empty line after a trailing newline
    var totalLineCount: Int {
        guard let textView = textView else { return 1 }
        let content = textView.string as NSString
        ensureLineStarts(content)
        return lineStarts.count + (endsWithNewline(content) ? 1 : 0)
    }
    
    // MARK: - Line Number Layout
    
    /// The line numbers currently on screen, with their positions.
    ///
    /// The single source of truth for both drawing and hit testing -- these
    /// used to be two separate copies of the same character walk, free to
    /// disagree with each other.
    func layoutVisibleLineNumbers() -> [GutterLine] {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return [] }
        
        let content = textView.string as NSString
        let inset = textView.textContainerInset
        let visibleRect = textView.visibleRect
        
        func toGutter(_ rect: NSRect) -> NSRect {
            NSRect(x: 0,
                   y: rect.origin.y + inset.height - visibleRect.origin.y,
                   width: bounds.width,
                   height: rect.height)
        }
        
        if content.length == 0 {
            let rect = layoutManager.extraLineFragmentRect.height > 0
                ? layoutManager.extraLineFragmentRect
                : NSRect(x: 0, y: 0, width: bounds.width,
                         height: layoutManager.defaultLineHeight(for: textView.font ?? font))
            let gutterRect = toGutter(rect)
            return [GutterLine(number: 1, rect: gutterRect, hitRect: gutterRect)]
        }
        
        ensureLineStarts(content)
        
        // Lay out what we are about to measure. Without this, fragment rects can
        // be read while layout is still in flight -- which is how a stray number
        // from a half-computed extraLineFragmentRect ended up in the gutter.
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        layoutManager.ensureLayout(forGlyphRange: visibleGlyphs)
        let charRange = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        
        // Start at the beginning of the logical line the visible range lands in,
        // never mid-line: a number belongs to its line's first row, and starting
        // mid-line would pin it to a wrapped continuation row instead.
        var lineIdx = lineIndex(containing: charRange.location)
        var idx = lineStarts[lineIdx]
        let limit = NSMaxRange(charRange)
        
        var result: [GutterLine] = []
        
        while idx < content.length {
            let lineRange = content.lineRange(for: NSRange(location: idx, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let bounding = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            result.append(GutterLine(number: lineIdx + 1,
                                     rect: toGutter(fragment),
                                     hitRect: toGutter(bounding.height > 0 ? bounding : fragment)))
            
            lineIdx += 1
            idx = NSMaxRange(lineRange)
            
            if idx > limit { break }
        }
        
        // The empty line after a trailing newline. Only when the walk actually
        // reached the end of the content, the layout manager really has an extra
        // fragment, and that fragment is on screen -- this block used to run
        // unconditionally, printing whatever number the loop broke on at
        // whatever position extraLineFragmentRect happened to hold.
        if idx >= content.length,
           endsWithNewline(content),
           layoutManager.extraLineFragmentTextContainer != nil {
            let gutterRect = toGutter(layoutManager.extraLineFragmentRect)
            if gutterRect.maxY > 0 && gutterRect.minY < max(bounds.height, visibleRect.height) {
                result.append(GutterLine(number: lineIdx + 1, rect: gutterRect, hitRect: gutterRect))
            }
        }
        
        // A line ending in a newline reports a bounding rect that reaches into
        // the following fragment, so trim each click target at the next line's
        // top. The column then partitions cleanly and a click lands on the line
        // it is actually over.
        for i in result.indices.dropLast() {
            let ceiling = result[i + 1].rect.minY
            if result[i].hitRect.maxY > ceiling {
                let trimmed = NSRect(x: result[i].hitRect.origin.x,
                                     y: result[i].hitRect.origin.y,
                                     width: result[i].hitRect.width,
                                     height: max(0, ceiling - result[i].hitRect.origin.y))
                result[i] = GutterLine(number: result[i].number, rect: result[i].rect, hitRect: trimmed)
            }
        }
        
        return result
    }
    
    // Calculate width based on current font
    private func calculateCurrentWidth() -> CGFloat {
        guard textView != nil else { return 50 }
        let digits = max(3, String(max(1, totalLineCount)).count)
        
        let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize * 0.85, weight: .regular)
        let sampleNumber = String(repeating: "8", count: digits)
        let attrs: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        // Wider padding: 12pt left + 12pt right = 24pt total
        return sampleNumber.size(withAttributes: attrs).width + 24
    }
    
    // Set the baseline width - call this when at default zoom level
    func setBaselineWidth() {
        baselineWidth = calculateCurrentWidth()
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
    func lineNumber(at point: NSPoint) -> Int? {
        let lines = layoutVisibleLineNumbers()
        guard !lines.isEmpty else { return nil }
        
        for line in lines where point.y >= line.hitRect.minY && point.y < line.hitRect.maxY {
            return line.number
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
        
        ensureLineStarts(content)
        
        if lineNumber >= 1 && lineNumber <= lineStarts.count {
            return content.lineRange(for: NSRange(location: lineStarts[lineNumber - 1], length: 0))
        }
        
        // Trailing empty line after a final newline
        if lineNumber == lineStarts.count + 1 && endsWithNewline(content) {
            return NSRange(location: content.length, length: 0)
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
        
        let numberFont = NSFont.monospacedDigitSystemFont(ofSize: font.pointSize * 0.85, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Right-align every number within a column centered in the gutter
        let maxDigits = max(3, String(max(1, totalLineCount)).count)
        let maxNumberWidth = String(repeating: "8", count: maxDigits).size(withAttributes: attrs).width
        let columnLeftEdge = (bounds.width - maxNumberWidth) / 2
        
        for line in layoutVisibleLineNumbers() {
            let text = "\(line.number)"
            let size = text.size(withAttributes: attrs)
            let xPos = columnLeftEdge + (maxNumberWidth - size.width)
            // Vertically center the number within its line fragment
            let yPos = line.rect.origin.y + (line.rect.height - size.height) / 2.0
            text.draw(at: NSPoint(x: xPos, y: yPos), withAttributes: attrs)
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
            
            // Position on the glyph's baseline so taller line heights keep
            // the marker aligned with the character it stands in for
            let point = NSPoint(
                x: origin.x + lineRect.origin.x + glyphLocation.x,
                y: origin.y + lineRect.origin.y + glyphLocation.y - font.ascender
            )
            
            // Draw the invisible character
            glyphToDraw.draw(at: point, withAttributes: invisibleAttrs)
        }
    }
}
