import AppKit

// Renders the LoginToggle app icon: Apple-style blue squircle, white power glyph.
// Usage: swift make-icon.swift <output.png>  (1024x1024)

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S: CGFloat = 1024

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()

let inset: CGFloat = 100
let bgRect = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
bg.addClip()

let top = NSColor(srgbRed: 0.30, green: 0.64, blue: 1.00, alpha: 1)
let bottom = NSColor(srgbRed: 0.04, green: 0.42, blue: 0.95, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(in: bgRect, angle: -90)

let ink = NSColor.white
let cx: CGFloat = 512, cy: CGFloat = 512

let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: 250,
              startAngle: 125, endAngle: 55, clockwise: false)
arc.lineWidth = 70
arc.lineCapStyle = .round
ink.setStroke()
arc.stroke()

let stem = NSBezierPath()
stem.move(to: NSPoint(x: cx, y: cy + 30))
stem.line(to: NSPoint(x: cx, y: cy + 335))
stem.lineWidth = 70
stem.lineCapStyle = .round
stem.stroke()

image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
