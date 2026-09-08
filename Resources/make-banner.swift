import AppKit

// Renders the repo social preview banner (1280x640): gradient, app icon, wordmark.
// Usage: swift make-banner.swift <icon.png> <output.png>

let iconPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/icon.png"
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "social-preview.png"
let W: CGFloat = 1280, H: CGFloat = 640

let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()

let top = NSColor(srgbRed: 0.30, green: 0.64, blue: 1.00, alpha: 1)
let bottom = NSColor(srgbRed: 0.04, green: 0.42, blue: 0.95, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

if let icon = NSImage(contentsOf: URL(fileURLWithPath: iconPath)) {
    icon.size = NSSize(width: 400, height: 400)
    icon.draw(in: NSRect(x: 110, y: 120, width: 400, height: 400))
}

let para = NSMutableParagraphStyle()
para.lineBreakMode = .byWordWrapping

let title = NSAttributedString(string: "LoginToggle", attributes: [
    .font: NSFont.systemFont(ofSize: 118, weight: .bold),
    .foregroundColor: NSColor.white
])
title.draw(in: NSRect(x: 560, y: 320, width: 700, height: 160))

let tag = NSAttributedString(string: "One button for every app\nthat opens at login", attributes: [
    .font: NSFont.systemFont(ofSize: 44, weight: .medium),
    .foregroundColor: NSColor(white: 1, alpha: 0.85),
    .paragraphStyle: para
])
tag.draw(in: NSRect(x: 566, y: 200, width: 700, height: 130))

image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
