//
//  EditorView.swift
//  Edith
//

import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var settingsManager: SettingsManager
    
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
        let size = CGFloat(settingsManager.fontSize * settingsManager.magnification)
        let font = NSFont(name: settingsManager.fontName, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        
        textView.font = font
        scrollView.lineNumberView.font = font
        scrollView.showLineNumbers = settingsManager.showLineNumbers
        textView.layoutManager?.showsInvisibleCharacters = settingsManager.showInvisibleCharacters
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
    
    var showLineNumbers: Bool = true {
        didSet {
            lineNumberView.isHidden = !showLineNumbers
            needsLayout = true
        }
    }
    
    override init(frame: NSRect) {
        // Create text view
        textView = NSTextView()
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
    
    var requiredWidth: CGFloat {
        guard let textView = textView else { return 40 }
        let lineCount = max(1, textView.string.components(separatedBy: "\n").count)
        let digits = max(3, String(lineCount).count)
        return CGFloat(digits) * font.pointSize * 0.7 + 16
    }
    
    // Use flipped coordinates to match NSTextView
    override var isFlipped: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        NSColor.controlBackgroundColor.setFill()
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
        
        if content.length == 0 {
            let s = "1"
            let sz = s.size(withAttributes: attrs)
            s.draw(at: NSPoint(x: bounds.width - sz.width - 8, y: inset.height), withAttributes: attrs)
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
            if idx >= content.length && content.length > 0 {
                break
            }
            
            let safeIdx = min(idx, max(0, content.length - 1))
            let range = content.lineRange(for: NSRange(location: safeIdx, length: 0))
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: safeIdx)
            
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            // Convert from text view coordinates to our view coordinates
            let yPos = lineRect.origin.y + inset.height - visibleRect.origin.y
            
            let s = "\(lineNum)"
            let sz = s.size(withAttributes: attrs)
            let pt = NSPoint(x: bounds.width - sz.width - 8, y: yPos + (lineRect.height - sz.height) / 2)
            s.draw(at: pt, withAttributes: attrs)
            
            lineNum += 1
            idx = NSMaxRange(range)
        }
    }
}
