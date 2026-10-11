import AppKit
import Foundation

// Original play / neural-circuit mark; no third-party logo assets.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let mint = NSColor(red: 0.39, green: 0.88, blue: 0.72, alpha: 1)
let violet = NSColor(red: 0.63, green: 0.64, blue: 1, alpha: 1)
for (name, pixels) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels)/1024, y: CGFloat(pixels)/1024)
    let background = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(red: 0.07, green: 0.17, blue: 0.21, alpha: 1), ending: NSColor(red: 0.035, green: 0.046, blue: 0.09, alpha: 1))!.draw(in: background, angle: -65)
    NSColor(white: 1, alpha: 0.10).setStroke(); background.lineWidth = 5; background.stroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 182, y: 182, width: 660, height: 660))
    mint.withAlphaComponent(0.12).setStroke(); ring.lineWidth = 3; ring.stroke()
    let triangle = NSBezierPath()
    triangle.move(to: NSPoint(x: 397, y: 710))
    triangle.line(to: NSPoint(x: 716, y: 512))
    triangle.line(to: NSPoint(x: 397, y: 314))
    triangle.close()
    mint.withAlphaComponent(0.13).setFill(); triangle.fill()
    mint.setStroke(); triangle.lineWidth = 28; triangle.lineJoinStyle = .round; triangle.stroke()
    let connections = NSBezierPath()
    connections.move(to: NSPoint(x: 397,y: 632)); connections.line(to: NSPoint(x: 278,y: 698))
    connections.move(to: NSPoint(x: 397,y: 512)); connections.line(to: NSPoint(x: 244,y: 512))
    connections.move(to: NSPoint(x: 397,y: 392)); connections.line(to: NSPoint(x: 278,y: 326))
    connections.move(to: NSPoint(x: 716,y: 512)); connections.line(to: NSPoint(x: 796,y: 512))
    mint.setStroke(); connections.lineWidth = 17; connections.lineCapStyle = .round; connections.stroke()
    for (x,y,color) in [(278.0,698.0,mint),(244.0,512.0,violet),(278.0,326.0,mint),(796.0,512.0,violet)] {
        let node = NSBezierPath(ovalIn: NSRect(x:x-25, y:y-25, width:50, height:50))
        color.setFill(); node.fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
}
