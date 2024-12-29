/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa

// Dummy NvimView class for FontUtils.
class NvimView {
  static let defaultFont = NSFont.userFixedPitchFont(ofSize: 12)!
  static let minFontSize = CGFloat(9)
  static let maxFontSize = CGFloat(128)
}

extension NSColor: @retroactive @unchecked Sendable {}
extension NSFont: @retroactive @unchecked Sendable {}
extension NSImage: @retroactive @unchecked Sendable {}
