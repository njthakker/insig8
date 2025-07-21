//
//  NSImage.swift
//  macOS
//
//  Created by Oscar on 16.12.22.
//

import Foundation

extension NSImage {
  /// A PNG representation of the image.
  var PNGRepresentation: Data? {
    if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
      return tiffData.representation(using: .png, properties: [:])
    }

    return nil
  }
  
  var jpgData: Data? {
    guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
    return bitmapImage.representation(using: .jpeg, properties: [:])
  }

  func jpgWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
    do {
      try jpgData?.write(to: url, options: options)
      return true
    } catch {
      print(error)
      return false
    }
  }

  // MARK: Saving
  /// Save the images PNG representation the the supplied file URL:
  ///
  /// - Parameter url: The file URL to save the png file to.
  /// - Throws: An unwrappingPNGRepresentationFailed when the image has no png representation.
  func savePngTo(url: URL) throws {
    if let png = self.PNGRepresentation {
      try png.write(to: url, options: .atomicWrite)
    } else {
      throw NSImageExtensionError.unwrappingPNGRepresentationFailed
    }
  }
}

/// Exceptions for the image extension class.
///
/// - creatingPngRepresentationFailed: Is thrown when the creation of the png representation failed.
enum NSImageExtensionError: Error {
  case unwrappingPNGRepresentationFailed
}

extension NSImage {
  var heic: Data? {
    return NSBitmapImageRep.representationOfImageReps(in: self.representations, using: .tiff, properties: [:])
  }

  func heicWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
    do {
      try heic?.write(to: url, options: options)
      return true
    } catch {
      print(error)
      return false
    }
  }
}

extension NSImage {

  /// The height of the image.
  var height: CGFloat {
    return size.height
  }

  /// The width of the image.
  var width: CGFloat {
    return size.width
  }

  func resize(withSize targetSize: NSSize) -> NSImage? {
    let frame = NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
    guard let representation = self.bestRepresentation(for: frame, context: nil, hints: nil) else {
      return nil
    }
    let image = NSImage(size: targetSize, flipped: false, drawingHandler: { (_) -> Bool in
      return representation.draw(in: frame)
    })
    
    return image
  }
  
  /// Copy the image and resize it to the supplied size, while maintaining it's
  /// original aspect ratio.
  ///
  /// - Parameter size: The target size of the image.
  /// - Returns: The resized image.
  func resizeMaintainingAspectRatio(withSize targetSize: NSSize) -> NSImage? {
    let widthRatio = targetSize.width / self.width
    let heightRatio = targetSize.height / self.height
    let scaleFactor = min(widthRatio, heightRatio) // Use the smaller ratio to fit within bounds
    
    let newSize = NSSize(
      width: floor(self.width * scaleFactor),
      height: floor(self.height * scaleFactor)
    )
    
    return self.resize(withSize: newSize)
  }
}
