import AppKit
import Bushel

class TermRoleIconView: NSView {
    
    @IBOutlet var tableCellView: NSTableCellView!
    @objc var termDoc: DictionaryBrowserTermDoc?
    
    var role: Term.SyntacticRole? {
        termDoc?.termDoc.term.role
    }
    
    override func awakeFromNib() {
        bind(NSBindingName("termDoc"), to: tableCellView!, withKeyPath: "objectValue", options: [:])
    }
    
    @IBInspectable var cornerRadius: CGFloat = 20
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawRoundedRectangle()
        drawText()
    }
    
    private func drawRoundedRectangle() {
        guard let role = role else {
            return
        }
        let bezier = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        let fillColor = NSColor(cgColor: highlightColors[Styling(for: role)]!)!.usingColorSpace(.deviceRGB)!
        let strokeColor = NSColor(hue: fillColor.hueComponent, saturation: fillColor.saturationComponent, brightness: fillColor.brightnessComponent * 0.8, alpha: 1.0)
        fillColor.setFill()
        strokeColor.setStroke()
        bezier.fill()
        bezier.stroke()
    }
    
    private func drawText() {
        guard let role = role else {
            return
        }
        let string = String(role.rawValue.first!) as NSString
        let attributes: [NSAttributedString.Key : Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let size = string.size(withAttributes: attributes)
        string.draw(at: CGPoint(x: (bounds.maxX - size.width) / 2.0, y: (bounds.maxY - size.height) / 2.0), withAttributes: attributes)
    }
    
}
