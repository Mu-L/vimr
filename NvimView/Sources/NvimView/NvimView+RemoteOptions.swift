/**
 * Renee Koecher -  @shirk
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import MessagePack
import NvimApi

extension NvimView {
  enum RemoteOption {
    // list of currently handled remote options
    case guifont(fontSpec: String)
    case guifontWide(fontSpec: String)

    static func fromValuePair(_ option: (key: MessagePackValue, value: MessagePackValue))
      -> RemoteOption?
    {
      guard let key = option.key.stringValue,
            let val = option.value.stringValue else { return nil }

      switch key {
      case "guifont": return RemoteOption.guifont(fontSpec: val)
      case "guifontwide": return RemoteOption.guifontWide(fontSpec: val)
      default: return nil
      }
    }

    // convenience methods
    static func fromFont(_ font: NSFont, forWideFont isWide: Bool = false) -> RemoteOption {
      let fontSpec = FontUtils.vimFontSpec(forFont: font)

      if isWide {
        return RemoteOption.guifontWide(fontSpec: fontSpec)
      }
      return RemoteOption.guifont(fontSpec: fontSpec)
    }
  }

  final func handleRemoteOptions(_ options: [MessagePackValue: MessagePackValue]) {
    for kvPair in options {
      guard let option = RemoteOption.fromValuePair(kvPair) else {
        self.bridgeLogger.debug("Could not handle RemoteOption \(kvPair)")
        continue
      }

      switch option {
      // FIXME: currently this treats gft and gfw the as the same
      case let .guifont(fontSpec): self.handleGuifontSet(fontSpec)
      case let .guifontWide(fontSpec): self.handleGuifontSet(fontSpec, forWideFont: true)
      }
    }
  }

  final func signalRemoteOptionChange(_ option: RemoteOption) {
    Task {
      switch option {
      case let .guifont(fontSpec):
        await self.api.nvimSetOptionValue(
          name: "guifont",
          value: .string(fontSpec),
          opts: ["scope": .string("global")]
        ).cauterize()
      case let .guifontWide(fontSpec):
        await self.api.nvimSetOptionValue(
          name: "guifontwide",
          value: .string(fontSpec),
          opts: ["scope": .string("global")]
        ).cauterize()
      }
    }
  }

  public final func signalError(code: Int, message: String) {
    Task {
      await self.api.nvimErrWriteln(str: "E\(code): \(message)").cauterize()
    }
  }

  private func handleGuifontSet(_ fontSpec: String, forWideFont wideFlag: Bool = false) {
    if fontSpec.isEmpty {
      // this happens on connect - signal the current value
      self.signalRemoteOptionChange(RemoteOption.fromFont(self.font, forWideFont: wideFlag))
      return
    }

    // stop if we would set the same font again
    let currentSpec = FontUtils.vimFontSpec(forFont: font)
    if currentSpec == fontSpec.components(separatedBy: " ").joined(separator: "_") {
      return
    }

    guard let newFont = FontUtils.font(fromVimFontSpec: fontSpec) else {
      self.bridgeLogger.debug("Invalid specification for guifont '\(fontSpec)'")

      self.signalError(code: 596, message: "Invalid font(s): guifont=\(fontSpec)")
      self.signalRemoteOptionChange(RemoteOption.fromFont(self.font, forWideFont: wideFlag))
      return
    }

    Task(priority: .high) {
      self.font = newFont
      // Cell size likely changed, do a resize.
      self.resizeNeoVimUi(to: self.frame.size)
      self.markForRenderWholeView()
      await self.delegate?.nextEvent(.guifontChanged(newFont))
    }
  }
}

private let gui = DispatchQueue.main
