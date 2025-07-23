/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import Commons

private struct SizedFontTrait: Hashable {
  static func == (lhs: SizedFontTrait, rhs: SizedFontTrait) -> Bool {
    if lhs.trait != rhs.trait { return false }
    if lhs.size != rhs.size { return false }

    return true
  }

  fileprivate var trait: FontTrait
  fileprivate var size: CGFloat
}

extension FontTrait: Hashable {}

enum FontUtils {
  static func fontHeight(of font: NSFont) -> CGFloat {
    if let cached = fontHeightCache.valueForKey(font) { return cached }

    let ascent = CTFontGetAscent(font)
    let descent = CTFontGetDescent(font)
    let leading = CTFontGetLeading(font)
    let height = ceil(ascent + descent + leading)

    fontHeightCache.set(height, forKey: font)
    return height
  }

  static func fontWidth(of font: NSFont) -> CGFloat {
    let capitalM = [UniChar(0x004D)]
    var glyph = [CGGlyph(0)]
    var advancement = CGSize.zero
    CTFontGetGlyphsForCharacters(font, capitalM, &glyph, 1)
    CTFontGetAdvancesForGlyphs(font, .horizontal, glyph, &advancement, 1)

    return advancement.width
  }

  static func cellSize(
    of font: NSFont,
    linespacing: CGFloat,
    characterspacing: CGFloat
  ) -> CGSize {
    if let cached = cellSizeWithDefaultLinespacingCache.valueForKey(font) {
      return CGSize(
        width: characterspacing * cached.width,
        height: ceil(linespacing * cached.height)
      )
    }

    let cellSizeToCache = CGSize(width: fontWidth(of: font), height: fontHeight(of: font))
    cellSizeWithDefaultLinespacingCache.set(cellSizeToCache, forKey: font)

    let cellSize = CGSize(
      width: characterspacing * cellSizeToCache.width,
      height: ceil(linespacing * cellSizeToCache.height)
    )

    return cellSize
  }

  static func font(adding trait: FontTrait, to font: NSFont) -> NSFont {
    if trait.isEmpty { return font }

    let sizedFontTrait = SizedFontTrait(trait: trait, size: font.pointSize)
    if let cachedFont = fontCache.valueForKey(sizedFontTrait) { return cachedFont }
    if nilFontCache.valueForKey(sizedFontTrait) != nil { return font }

    var ctFontTrait: CTFontSymbolicTraits = []
    if trait.contains(.bold) { ctFontTrait.insert(.boldTrait) }
    if trait.contains(.italic) { ctFontTrait.insert(.italicTrait) }

    guard let ctFont = CTFontCreateCopyWithSymbolicTraits(font, 0, nil, ctFontTrait, ctFontTrait)
    else {
      nilFontCache.set(0, forKey: sizedFontTrait)
      return font
    }

    fontCache.set(ctFont, forKey: sizedFontTrait)
    return ctFont
  }

  /// We use @MainActor here because
  /// - NvimView.defaultFont/minFontSize/maxFontSize cannot be accessed despite the fact that
  ///   they are static sendable constants
  /// - One could set those properties as nonisolated(unsafe), but then, the compiler warns that
  ///   nonisolated is not necessary
  /// - This function is only called from @MainActor
  @MainActor static func font(fromVimFontSpec fontSpec: String) -> NSFont? {
    let fontParams = fontSpec.components(separatedBy: ":")

    guard fontParams.count == 2 else {
      return nil
    }

    let fontName = fontParams[0].components(separatedBy: "_").joined(separator: " ")
    var fontSize = NvimView.defaultFont.pointSize // use a sane fallback

    if fontParams[1].hasPrefix("h"), fontParams[1].count >= 2 {
      let sizeSpec = fontParams[1].dropFirst()
      if let parsed = Float(sizeSpec)?.rounded() {
        fontSize = CGFloat(parsed)

        if fontSize < NvimView.minFontSize || fontSize > NvimView.maxFontSize {
          fontSize = NvimView.defaultFont.pointSize
        }
      }
    }
    return NSFont(name: fontName, size: CGFloat(fontSize))
  }

  static func vimFontSpec(forFont font: NSFont) -> String {
    if let escapedName = font.displayName?.components(separatedBy: " ").joined(separator: "_") {
      return "\(escapedName):h\(Int(font.pointSize))"
    }
    // fontName always returns a valid result and works for font(name:, size:) as well
    return "\(font.fontName):h\(Int(font.pointSize))"
  }
}

private let fontCache = ThreadSafeFifoCache<SizedFontTrait, NSFont>(count: 50)
private let nilFontCache = ThreadSafeFifoCache<SizedFontTrait, Int>(count: 50)
private let fontHeightCache = ThreadSafeFifoCache<NSFont, CGFloat>(count: 100)
private let cellSizeWithDefaultLinespacingCache = ThreadSafeFifoCache<NSFont, CGSize>(count: 100)
