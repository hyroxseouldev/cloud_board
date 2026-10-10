// macOS: swift tool/render_motion_gif.swift <frame-directory> <output.gif>
// Encodes the Flutter capture's 40 ms PNG frames without changing their timing.
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift render_motion_gif.swift <frame-directory> <output.gif>")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let frames = try FileManager.default.contentsOfDirectory(at: directory,
    includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !frames.isEmpty,
      let destination = CGImageDestinationCreateWithURL(output as CFURL,
          UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("No PNG frames, or output cannot be created")
}
CGImageDestinationSetProperties(destination,
    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in frames {
    guard let source = CGImageSourceCreateWithURL(frame as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Cannot decode \(frame.path)")
    }
    CGImageDestinationAddImage(destination, image,
        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write GIF")
}
print("Encoded \(frames.count) frames to \(output.path)")
