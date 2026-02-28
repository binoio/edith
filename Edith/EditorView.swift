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
    
    func makeNSView(context: Context) -> LineNumberScrollView {
        let scrollView = LineNumberScrollView()
        let textView = scrollView.textView
        
        textView.delegate = context.coordinator
        textView.string = text
        
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        applySettings(to: scrollView)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: LineNumberScrollView, context: Context) {
        let textView = scrollView.textView
        
        if textView.string != text {
            textView.string = text
        }
        
        applySettings(to: scrollView)
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
        
        // Set baseline width when at default zoom (zoom=1.0)
        if zoomState.zoom == 1.0 {
            scrollView.lineNumberView.setBaselineWidth()
        }
        
        scrollView.showLineNumbers = settingsManager.showLineNumbers
        scrollView.customLayoutManager.showInvisibleCharacters = settingsManager.showInvisibleCharacters
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?
        weak var scrollView: LineNumberScrollView?
        
        init(_ parent: EditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            scrollView?.lineNumberView.needsDisplay = true
        }
    }
}

// MARK: - Custom Scroll View with Line Numbers
class LineNumberScrollView: NSView {
    let scrollView: NSScrollView
    let textView: NSTextView
    let lineNumberView: LineNumberView
    let customLayoutManager: InvisibleCharacterLayoutManager
    
    var showLineNumbers: Bool = true {
        didSet {
            lineNumberView.isHidden = !showLineNumbers
            needsLayout = true
        }
    }
    
    override init(frame: NSRect) {
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
        
        // Create text view with custom text system
        textView = NSTextView(frame: .zero, textContainer: textContainer)
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
              let textContainer = textContainers.first else { return }
        
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
            var lineFragmentRect = NSRect.zero
            self.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
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
