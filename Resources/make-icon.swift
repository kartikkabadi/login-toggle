import AppKit

// Renders the LoginToggle app icon: dark squircle, glowing power glyph.
// Usage: swift make-icon.swift <output.png>  (1024x1024)

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let S: CGFloat = 1024

let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()

let inset: CGFloat = 100
let bgRect = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
bg.addClip()

let top = NSColor(calibratedRed: 0.19, green: 0.21, blue: 0.26, alpha: 1)
let bottom = NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1)
NSGradient(starting: top, ending: bottom)?.draw(in: bgRect, angle: -90)

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedRed: 0.36, green: 0.92, blue: 0.83, alpha: 0.85)
shadow.shadowBlurRadius = 55
shadow.shadowOffset = NSSize(width: 0, height: 0)
shadow.set()

let ink = NSColor(calibratedRed: 0.94, green: 0.98, blue: 0.97, alpha: 1)
let cx: CGFloat = 512, cy: CGFloat = 512

let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: 240,
              startAngle: 125, endAngle: 55, clockwise: false)
arc.lineWidth = 66
arc.lineCapStyle = .round
ink.setStroke()
arc.stroke()

let stem = NSBezierPath()
stem.move(to: NSPoint(x: cx, y: cy + 30))
stem.line(to: NSPoint(x: cx, y: cy + 320))
stem.lineWidth = 66
stem.lineCapStyle = .round
stem.stroke()

NSShadow().set()
image.unlockFocus()

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
