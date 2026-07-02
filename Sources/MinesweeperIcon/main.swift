import AppKit
import MinesweeperCore

// Renders IconArt at every macOS icon size into an .iconset directory (to be
// packed by `iconutil`), and optionally a standalone PNG for the pygame window.
//
// Usage: MinesweeperIcon <output.iconset dir> [standalone.png] [standalonePx]

func renderPNG(pixels: Int) -> Data {
    guard let png = IconArt.pngData(pixels: pixels) else {
        FileHandle.standardError.write(Data("failed to encode PNG at \(pixels)px\n".utf8))
        exit(1)
    }
    return png
}

func write(_ data: Data, to path: String) {
    do {
        try data.write(to: URL(fileURLWithPath: path))
    } catch {
        FileHandle.standardError.write(Data("write failed (\(path)): \(error)\n".utf8))
        exit(1)
    }
}

let args = CommandLine.arguments
guard args.count > 1 else {
    FileHandle.standardError.write(Data("usage: MinesweeperIcon <out.iconset> [png] [px]\n".utf8))
    exit(2)
}
let iconsetDir = args[1]

do {
    try FileManager.default.createDirectory(atPath: iconsetDir,
                                            withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write(Data("could not create \(iconsetDir): \(error)\n".utf8))
    exit(1)
}

// Apple's required iconset members: (filename, pixel size).
let members: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

var cache: [Int: Data] = [:]  // several iconset members share a pixel size
for (name, px) in members {
    let data = cache[px] ?? renderPNG(pixels: px)
    cache[px] = data
    write(data, to: "\(iconsetDir)/\(name).png")
}
print("wrote \(members.count) icons to \(iconsetDir)")

// Optional standalone PNG (e.g. for pygame's window icon).
if args.count > 2 {
    let requested = args.count > 3 ? (Int(args[3]) ?? 256) : 256
    let px = max(1, requested)
    write(cache[px] ?? renderPNG(pixels: px), to: args[2])
    print("wrote standalone \(px)px PNG to \(args[2])")
}
