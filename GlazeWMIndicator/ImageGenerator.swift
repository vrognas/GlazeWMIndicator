import Cocoa

func generateWorkspaceImage(label: String, active: Bool, visible: Bool) -> NSImage {
    let size = CGSize(width: 24, height: 16)
    let cornerRadius: CGFloat = 3
    let canvas = NSRect(origin: .zero, size: size)
    let image = NSImage(size: size)
    let color = NSColor.black

    if active {
        // Focused: filled rounded rect with knocked-out text (solid, prominent)
        let imageFill = NSImage(size: size)
        let imageText = NSImage(size: size)

        imageFill.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        imageFill.unlockFocus()

        imageText.lockFocus()
        drawLabel(label as NSString, color: color, size: size)
        imageText.unlockFocus()

        image.lockFocus()
        imageFill.draw(in: canvas, from: .zero, operation: .sourceOut, fraction: 1.0)
        imageText.draw(in: canvas, from: .zero, operation: .destinationOut, fraction: 1.0)
        image.unlockFocus()
    } else if visible {
        // Displayed but not focused: stroked outline with text at reduced opacity
        image.lockFocus()
        color.setStroke()
        let path = NSBezierPath(
            roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5),
            xRadius: cornerRadius, yRadius: cornerRadius
        )
        path.lineWidth = 1.0
        path.stroke()
        drawLabel(label as NSString, color: color, size: size)
        image.unlockFocus()
    } else {
        // Active (has windows) but not on any monitor: just the number, no outline
        image.lockFocus()
        drawLabel(label as NSString, color: color, size: size)
        image.unlockFocus()
    }

    image.isTemplate = true
    return image
}

private func drawLabel(_ text: NSString, color: NSColor, size: CGSize) {
    let fontSize: CGFloat = 10
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium),
        .foregroundColor: color,
    ]
    let boundingBox = text.size(withAttributes: attrs)
    let x = size.width / 2 - boundingBox.width / 2
    let y = size.height / 2 - boundingBox.height / 2
    text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}
