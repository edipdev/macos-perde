import AppKit

func render(_ size: CGFloat) -> Data? {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.86, blue: 0.80, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.55, blue: 0.55, alpha: 1)
    ])
    gradient?.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "chevron.compact.down", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let s = symbol.size
        let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2 + size * 0.02)
        symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    }
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "build/Perde.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]
for (name, size) in specs {
    if let data = render(size) {
        try! data.write(to: iconset.appendingPathComponent("\(name).png"))
    }
}

let out = URL(fileURLWithPath: "Resources/Perde.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! process.run()
process.waitUntilExit()
try? fm.removeItem(at: iconset)
print("icon:", process.terminationStatus == 0 ? "ok" : "fail")
