/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import Commons

public final class WorkspaceToolButton: NSView, NSDraggingSource {
  private static let titlePadding = CGSize(width: 8, height: 2)
  private static let dummyButton = WorkspaceToolButton(title: "Dummy")

  private var isHighlighted = false

  private let title: NSMutableAttributedString
  private var trackingArea = NSTrackingArea()

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

  static let toolUti = "com.qvacua.vimr.tool"

  static func == (left: WorkspaceToolButton, right: WorkspaceToolButton) -> Bool {
    guard let leftTool = left.tool, let rightTool = right.tool else {
      return false
    }

    return leftTool == rightTool
  }

  var location = WorkspaceBarLocation.top
  var isSelected: Bool {
    self.tool?.isSelected ?? false
  }

  var theme: Workspace.Theme {
    self.tool?.theme ?? Workspace.Theme.default
  }

  weak var tool: WorkspaceTool?

  static func dimension() -> CGFloat {
    self.dummyButton.intrinsicContentSize.height
  }

  static func size(forLocation loc: WorkspaceBarLocation) -> CGSize {
    switch loc {
    case .top, .bottom:
      self.dummyButton.intrinsicContentSize
    case .right, .left:
      CGSize(
        width: self.dummyButton.intrinsicContentSize.height,
        height: self.dummyButton.intrinsicContentSize.width
      )
    }
  }

  init(title: String) {
    self.title = NSMutableAttributedString(string: title, attributes: [
      NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11),
    ])

    super.init(frame: .zero)
    self.configureForAutoLayout()

    self.title.addAttribute(
      NSAttributedString.Key.foregroundColor,
      value: self.theme.foreground,
      range: NSRange(location: 0, length: self.title.length)
    )

    self.wantsLayer = true
  }

  func repaint() {
    if self.isHighlighted {
      self.highlight()
    } else {
      self.dehighlight()
    }

    self.title.addAttribute(
      NSAttributedString.Key.foregroundColor,
      value: self.theme.foreground,
      range: NSRange(location: 0, length: self.title.length)
    )

    self.needsDisplay = true
  }

  func highlight() {
    self.isHighlighted = true
    self.layer?.backgroundColor = self.theme.barButtonHighlight.cgColor
  }

  func dehighlight() {
    self.isHighlighted = false
    self.layer?.backgroundColor = self.theme.barButtonBackground.cgColor
  }
}

// MARK: - NSView

public extension WorkspaceToolButton {
  override var intrinsicContentSize: NSSize {
    let titleSize = self.title.size()

    let padding = WorkspaceToolButton.titlePadding
    switch self.location {
    case .top, .bottom:
      return CGSize(
        width: titleSize.width + 2 * padding.width,
        height: titleSize.height + 2 * padding.height
      )
    case .right, .left:
      return CGSize(
        width: titleSize.height + 2 * padding.height,
        height: titleSize.width + 2 * padding.width
      )
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let padding = WorkspaceToolButton.titlePadding
    switch self.location {
    case .top, .bottom:
      self.title.draw(at: CGPoint(x: padding.width, y: padding.height))
    case .right:
      self.title.draw(
        at: CGPoint(x: padding.height, y: self.bounds.height - padding.width),
        angle: -(.pi / 2)
      )
    case .left:
      self.title.draw(
        at: CGPoint(x: self.bounds.width - padding.height, y: padding.width),
        angle: .pi / 2
      )
    }
  }

  override func updateTrackingAreas() {
    self.removeTrackingArea(self.trackingArea)

    self.trackingArea = NSTrackingArea(
      rect: self.bounds,
      options: [.mouseEnteredAndExited, .activeInActiveApp],
      owner: self,
      userInfo: nil
    )
    self.addTrackingArea(self.trackingArea)

    super.updateTrackingAreas()
  }

  override func mouseDown(with event: NSEvent) {
    guard let nextEvent = self.window!.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else {
      return
    }

    switch nextEvent.type {
    case .leftMouseUp:
      self.tool?.toggle()
      return

    case .leftMouseDragged:
      let pasteboardItem = NSPasteboardItem()
      pasteboardItem.setString(
        self.tool!.uuid,
        forType: NSPasteboard.PasteboardType(WorkspaceToolButton.toolUti)
      )

      let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
      draggingItem.setDraggingFrame(self.bounds, contents: self.snapshot())

      self.beginDraggingSession(with: [draggingItem], event: event, source: self)
      return

    default:
      return
    }
  }

  override func mouseEntered(with _: NSEvent) {
    if self.isSelected {
      return
    }

    self.highlight()
  }

  override func mouseExited(with _: NSEvent) {
    if self.isSelected {
      return
    }

    self.dehighlight()
  }

  // Modified version of snapshot() from
  // https://www.raywenderlich.com/136272/drag-and-drop-tutorial-for-macos
  private func snapshot() -> NSImage {
    let pdfData = self.dataWithPDF(inside: self.bounds)
    guard let image = NSImage(data: pdfData) else {
      return NSImage()
    }

    let result = NSImage()
    let rect = CGRect(origin: .zero, size: image.size)
    result.size = rect.size

    result.lockFocus()
    self.theme.barButtonHighlight.set()
    rect.fill()
    image.draw(in: rect)
    result.unlockFocus()

    return result
  }
}

// MARK: - NSDraggingSource

public extension WorkspaceToolButton {
  @objc(draggingSession: sourceOperationMaskForDraggingContext:)
  func draggingSession(
    _: NSDraggingSession,
    sourceOperationMaskFor _: NSDraggingContext
  ) -> NSDragOperation {
    .move
  }

  @objc(draggingSession: endedAtPoint:operation:)
  func draggingSession(
    _: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation _: NSDragOperation
  ) {
    guard let pointInWindow = self.window?
      .convertFromScreen(CGRect(origin: screenPoint, size: .zero))
    else {
      return
    }

    let pointInView = self.convert(pointInWindow, from: nil)
    // Sometimes if the drag ends, the button does not get dehighlighted.
    if !self.frame.contains(pointInView), !(self.tool?.isSelected ?? false) {
      self.dehighlight()
    }
  }
}
