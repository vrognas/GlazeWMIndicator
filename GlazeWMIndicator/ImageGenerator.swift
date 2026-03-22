import Cocoa

func generateWorkspaceImage(label: String, active: Bool, visible: Bool) -> NSImage {
    let size = CGSize(width: 24, height: 16)
    let cornerRadius: CGFloat = 4
    let canvas = NSRect(origin: .zero, size: size)
    let image = NSImage(size: size)
    let strokeColor = NSColor.black

    if active || visible {
        let imageFill = NSImage(size: size)
        let imageText = NSImage(size: size)

        imageFill.lockFocus()
        strokeColor.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        imageFill.unlockFocus()

        imageText.lockFocus()
        drawLabel(label as NSString, color: strokeColor, size: size)
        imageText.unlockFocus()

        image.lockFocus()
        imageFill.draw(in: canvas, from: .zero, operation: .sourceOut, fraction: active ? 1.0 : 0.8)
        imageText.draw(in: canvas, from: .zero, operation: .destinationOut, fraction: active ? 1.0 : 0.8)
        image.unlockFocus()
    } else {
        image.lockFocus()
        strokeColor.setStroke()
        let path = NSBezierPath(
            roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5),
            xRadius: cornerRadius, yRadius: cornerRadius
        )
        path.stroke()
        drawLabel(label as NSString, color: strokeColor, size: size)
        image.unlockFocus()
    }

    image.isTemplate = true
    return image
}

private func drawLabel(_ text: NSString, color: NSColor, size: CGSize) {
    let fontSize: CGFloat = 10
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        .foregroundColor: color,
    ]
    let boundingBox = text.size(withAttributes: attrs)
    let x = size.width / 2 - boundingBox.width / 2
    let y = size.height / 2 - boundingBox.height / 2
    text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}
