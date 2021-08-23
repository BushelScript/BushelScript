import AppKit
import Bushel

class TermRoleIconView: NSView {
    
    @IBOutlet var tableCellView: NSTableCellView!
    
    var role: Term.SyntacticRole? {
        didSet {
            needsDisplay = true
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0
    @IBInspectable var outlineWidth: CGFloat = 0
    @IBInspectable var textFontSize: CGFloat = 12
    @IBInspectable var textStrokeWidth: CGFloat = 0
    @IBInspectable var textColor: NSColor = .textBackgroundColor
    @IBInspectable var textStrokeColor: NSColor = .labelColor
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawRoundedRectangle()
        drawText()
    }
    
    private func drawRoundedRectangle() {
        guard let role = role else {
            return
        }
        
        NSGraphicsContext.current?.saveGraphicsState()
        defer {
            NSGraphicsContext.current?.restoreGraphicsState()
        }
        
        let fillColor =
            (defaultSizeHighlightStyles?[Styling(for: role)]?[.foregroundColor] as? NSColor ?? .clear)
            .usingColorSpace(.deviceRGB)!
        let strokeColor = NSColor(
            hue: fillColor.hueComponent,
            saturation: fillColor.saturationComponent,
            brightness: fillColor.brightnessComponent * 0.7,
            alpha: 1.0
        )
        fillColor.setFill()
        strokeColor.setStroke()
        
        let bezier = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)
        bezier.addClip()
        bezier.lineWidth = 2 * outlineWidth
        bezier.fill()
        bezier.stroke()
    }
    
    private func drawText() {
        guard let role = role else {
            return
        }
        let string = String(role.rawValue.first!) as NSString
        let attributes: [NSAttributedString.Key : Any] = [
            .font: NSFont.systemFont(ofSize: textFontSize),
            .foregroundColor: textColor,
            // See https://developer.apple.com/library/archive/qa/qa1531/_index.html#//apple_ref/doc/uid/DTS40007490
            .strokeWidth: textStrokeWidth,
            .strokeColor: textStrokeColor
        ]
        
        guard let graphicsContext = NSGraphicsContext.current else {
            return
        }
        
        graphicsContext.saveGraphicsState()
        defer {
            graphicsContext.restoreGraphicsState()
        }
        
        let size = string.size(withAttributes: attributes)
        string.draw(at: CGPoint(x: (bounds.maxX - size.width) / 2.0, y: (bounds.maxY - size.height) / 2.0 + 1), withAttributes: attributes)
    }
    
}
