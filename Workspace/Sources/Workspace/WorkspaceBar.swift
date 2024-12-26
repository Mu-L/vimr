/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import os
import PureLayout

@MainActor
protocol WorkspaceBarDelegate: AnyObject {
  func resizeWillStart(workspaceBar: WorkspaceBar, tool: WorkspaceTool?)

  func resizeDidEnd(workspaceBar: WorkspaceBar, tool: WorkspaceTool?)

  func toggle(tool: WorkspaceTool)

  func moved(tool: WorkspaceTool)
}

/**
 TODO: Refactor to include the buttons and the inner separator. Currently it's just a pass-through view only for drag &
 drop due to the drag & drop infrastructure of Cocoa.
 */

private class ProxyBar: NSView {
  fileprivate var draggedOnToolIdx: Int?

  private var isDragOngoing = false
  private var buttonFrames: [CGRect] = []

  fileprivate weak var container: WorkspaceBar?

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init() {
    super.init(frame: .zero)
    self.configureForAutoLayout()

    self.registerForDraggedTypes([NSPasteboard.PasteboardType(WorkspaceToolButton.toolUti)])

    self.wantsLayer = true
  }
}

final class WorkspaceBar: NSView, WorkspaceToolDelegate {
  private static let separatorThickness = 1.0

  fileprivate(set) var tools = [WorkspaceTool]()

  private weak var selectedTool: WorkspaceTool?

  private var isMouseDownOngoing = false
  private var dragIncrement = 1.0

  private var layoutConstraints = [NSLayoutConstraint]()

  private let proxyBar = ProxyBar()

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - API

  static let minimumDimension = 50.0

  let location: WorkspaceBarLocation
  var isButtonVisible = true {
    didSet {
      self.relayout()
    }
  }

  var isOpen: Bool {
    self.selectedTool != nil
  }

  var dimensionConstraint = NSLayoutConstraint()

  var theme: Workspace.Theme {
    self.workspace?.theme ?? Workspace.Theme.default
  }

  weak var delegate: WorkspaceBarDelegate?
  weak var workspace: Workspace?

  init(location: WorkspaceBarLocation) {
    self.location = location

    super.init(frame: .zero)
    self.configureForAutoLayout()

    self.wantsLayer = true
    self.layer!.backgroundColor = self.theme.barBackground.cgColor

    self.proxyBar.container = self
  }

  func dimensionWithoutTool() -> CGFloat {
    switch self.location {
    case .top, .bottom:
      WorkspaceToolButton.dimension() + WorkspaceBar.separatorThickness
    case .right, .left:
      WorkspaceToolButton.dimension() + WorkspaceBar.separatorThickness
    }
  }

  func barFrame() -> CGRect {
    let size = self.bounds.size
    let dimension = self.dimensionWithoutTool()

    switch self.location {
    case .top:
      return CGRect(x: 0, y: size.height - dimension, width: size.width, height: dimension)
    case .right:
      return CGRect(x: size.width - dimension, y: 0, width: dimension, height: size.height)
    case .bottom:
      return CGRect(x: 0, y: 0, width: size.width, height: dimension)
    case .left:
      return CGRect(x: 0, y: 0, width: dimension, height: size.height)
    }
  }

  func repaint() {
    self.layer!.backgroundColor = self.theme.barBackground.cgColor
    self.tools.forEach { $0.repaint() }
    self.needsDisplay = true
  }

  func relayout() {
    self.removeConstraints(self.layoutConstraints)
    self.removeAllSubviews()

    if self.isEmpty() {
      self.set(dimension: 0)
      return
    }

    if self.isButtonVisible {
      self.layoutButtons()

      if self.isOpen {
        let curTool = self.selectedTool!

        self.layout(curTool)

        let newDimension = self.barDimension(withToolDimension: curTool.dimension)
        self.set(dimension: newDimension)
      } else {
        self.set(dimension: self.barDimensionWithButtonsWithoutTool())
      }

    } else {
      if self.isOpen {
        let curTool = self.selectedTool!

        self.layoutWithoutButtons(curTool)

        let newDimension = self.barDimensionWithoutButtons(withToolDimension: curTool.dimension)
        self.set(dimension: newDimension)
      } else {
        self.set(dimension: 0)
      }
    }

    let proxyBar = self.proxyBar
    self.addSubview(proxyBar)
    switch self.location {
    case .top:
      proxyBar.autoPinEdge(toSuperviewEdge: .top)
      proxyBar.autoPinEdge(toSuperviewEdge: .right)
      proxyBar.autoPinEdge(toSuperviewEdge: .left)
      proxyBar.autoSetDimension(.height, toSize: self.barDimensionWithButtonsWithoutTool())

    case .right:
      proxyBar.autoPinEdge(toSuperviewEdge: .top)
      proxyBar.autoPinEdge(toSuperviewEdge: .bottom)
      proxyBar.autoPinEdge(toSuperviewEdge: .right)
      proxyBar.autoSetDimension(.width, toSize: self.barDimensionWithButtonsWithoutTool())

    case .bottom:
      proxyBar.autoPinEdge(toSuperviewEdge: .right)
      proxyBar.autoPinEdge(toSuperviewEdge: .bottom)
      proxyBar.autoPinEdge(toSuperviewEdge: .left)
      proxyBar.autoSetDimension(.height, toSize: self.barDimensionWithButtonsWithoutTool())

    case .left:
      proxyBar.autoPinEdge(toSuperviewEdge: .top)
      proxyBar.autoPinEdge(toSuperviewEdge: .bottom)
      proxyBar.autoPinEdge(toSuperviewEdge: .left)
      proxyBar.autoSetDimension(.width, toSize: self.barDimensionWithButtonsWithoutTool())
    }
  }

  func append(tool: WorkspaceTool) {
    tool.bar = self
    tool.delegate = self
    tool.location = self.location
    self.tools.append(tool)

    if self.isOpen || tool.isSelected {
      self.selectedTool?.isSelected = false

      self.selectedTool = tool
      self.selectedTool?.isSelected = true
    }

    self.relayout()
  }

  func insert(tool: WorkspaceTool, at idx: Int) {
    tool.bar = self
    tool.delegate = self
    tool.location = self.location
    self.tools.insert(tool, at: idx)

    if self.isOpen || tool.isSelected {
      self.selectedTool?.isSelected = false

      self.selectedTool = tool
      self.selectedTool?.isSelected = true
    }

    self.relayout()
  }

  func remove(tool: WorkspaceTool) {
    guard let idx = self.tools.firstIndex(of: tool) else {
      return
    }

    tool.bar = nil
    tool.delegate = nil
    self.tools.remove(at: idx)

    if self.isOpen, self.selectedTool == tool {
      self.selectedTool = self.tools.first
    }

    self.relayout()
  }
}

// MARK: - NSDraggingDestination

extension ProxyBar {
  private func isTool(atIndex idx: Int, beingDragged info: NSDraggingInfo) -> Bool {
    let pasteboard = info.draggingPasteboard

    guard let uuid = pasteboard
      .string(forType: NSPasteboard.PasteboardType(WorkspaceToolButton.toolUti))
    else {
      return false
    }

    let tool = self.container!.tools[idx]
    return self.container!.tools.first { $0.uuid == uuid } == tool
  }

  override func draggingEntered(_: NSDraggingInfo) -> NSDragOperation {
    self.buttonFrames.removeAll()
    self.buttonFrames = self.container!.tools.map(\.button.frame)

    self.isDragOngoing = true
    return .move
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let locInProxy = self.convert(sender.draggingLocation, from: nil)
    let locInBar = self.convert(locInProxy, to: self.container)

    let currentDraggedOnToolIdx = self.buttonFrames.enumerated()
      .reduce(nil) { result, entry -> Int? in
        if result != nil {
          return result
        }

        if entry.element.contains(locInBar) {
          if self.isTool(atIndex: entry.offset, beingDragged: sender) {
            return nil
          }

          return entry.offset
        }

        return nil
      }

    if currentDraggedOnToolIdx == self.draggedOnToolIdx {
      return .move
    }

    self.draggedOnToolIdx = currentDraggedOnToolIdx
    self.container!.relayout()
    return .move
  }

  override func draggingEnded(_: NSDraggingInfo) {
    self.endDrag()
  }

  override func draggingExited(_: NSDraggingInfo?) {
    self.endDrag()
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard let toolButton = sender.draggingSource as? WorkspaceToolButton else {
      return false
    }

    guard let tool = toolButton.tool else {
      return false
    }

    guard let draggedOnToolIdx = self.draggedOnToolIdx else {
      // This means:
      // 1. the dragged tool is from this bar and is dropped at the same spot
      // 2. the dragged tool is from this bar and is dropped at the end of the bar
      // 3. the dragged tool is not from this bar and is dropped at the end of the bar

      guard let toolIdx = self.container!.tools.firstIndex(of: tool) else {
        // 3.
        tool.bar?.remove(tool: tool)
        self.container!.append(tool: tool)
        self.container?.delegate?.moved(tool: tool)
        return true
      }

      // 2.
      let locInProxy = self.convert(sender.draggingLocation, from: nil)
      let locInBar = self.convert(locInProxy, to: self.container)

      if self.buttonFrames.filter({ $0.contains(locInBar) }).isEmpty,
         self.container!.barFrame().contains(locInBar)
      {
        self.container!.tools.remove(at: toolIdx)
        self.container!.tools.append(tool)
        self.container?.delegate?.moved(tool: tool)
        return true
      }

      // 1.
      return false
    }

    // If we are here, the dragged tool is dropped somewhere in the middle and
    // 1. is not from this bar
    // 2. is from this bar

    guard let toolIdx = self.container!.tools.firstIndex(of: tool) else {
      // 1.
      tool.bar?.remove(tool: tool)
      self.container!.insert(tool: tool, at: draggedOnToolIdx)
      self.container?.delegate?.moved(tool: tool)
      return true
    }

    // 2.
    if draggedOnToolIdx > toolIdx {
      self.container!.tools.remove(at: toolIdx)
      self.container!.tools.insert(tool, at: draggedOnToolIdx - 1)
    } else {
      self.container!.tools.remove(at: toolIdx)
      self.container!.tools.insert(tool, at: draggedOnToolIdx)
    }
    self.container?.delegate?.moved(tool: tool)
    return true
  }

  private func endDrag() {
    self.isDragOngoing = false
    self.draggedOnToolIdx = nil
    self.container!.relayout()
  }
}

// MARK: - NSView

extension WorkspaceBar {
  override func draw(_ dirtyRect: NSRect) {
//    super.draw(dirtyRect)

    if self.isButtonVisible {
      self.drawInnerSeparator(dirtyRect)
    }

    if self.isOpen {
      self.drawOuterSeparator(dirtyRect)
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let loc = self.convert(point, from: nil)

    guard self.isOpen else {
      return super.hitTest(point)
    }

    if self.resizeRect().contains(loc) {
      return self
    }

    return super.hitTest(point)
  }

  override func mouseDown(with event: NSEvent) {
    guard self.isOpen else {
      return
    }

    if self.isMouseDownOngoing {
      return
    }

    let initialMouseLoc = self.convert(event.locationInWindow, from: nil)
    let mouseInResizeRect = NSMouseInRect(initialMouseLoc, self.resizeRect(), self.isFlipped)

    guard mouseInResizeRect, event.type == .leftMouseDown else {
      super.mouseDown(with: event)
      return
    }

    self.isMouseDownOngoing = true
    self.delegate?.resizeWillStart(workspaceBar: self, tool: self.selectedTool)
    self.dimensionConstraint.priority = NSLayoutConstraint
      .Priority(
        NSLayoutConstraint.Priority
          .RawValue(Int(NSLayoutConstraint.Priority.dragThatCannotResizeWindow.rawValue) - 1)
      )

    var dragged = false
    var curEvent = event
    let nextEventMask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseDown, .leftMouseUp]

    while curEvent.type != .leftMouseUp {
      let nextEvent = NSApp.nextEvent(
        matching: nextEventMask,
        until: .distantFuture,
        inMode: .eventTracking,
        dequeue: true
      )
      guard nextEvent != nil else {
        break
      }

      curEvent = nextEvent!

      guard curEvent.type == .leftMouseDragged else {
        break
      }

      let curMouseLoc = self.convert(curEvent.locationInWindow, from: nil)
      let distance = self.sq(initialMouseLoc.x - curMouseLoc.x) + self
        .sq(initialMouseLoc.y - curMouseLoc.y)

      guard dragged || distance >= 1 else {
        continue
      }

      let locInSuperview = self.superview!.convert(curEvent.locationInWindow, from: nil)
      let newDimension = self.newDimension(forLocationInSuperview: locInSuperview)

      self.set(dimension: newDimension)

      dragged = true
    }

    self.dimensionConstraint.priority = .dragThatCannotResizeWindow
    self.isMouseDownOngoing = false
    self.delegate?.resizeDidEnd(workspaceBar: self, tool: self.selectedTool)
  }

  override func resetCursorRects() {
    guard self.isOpen else {
      return
    }

    switch self.location {
    case .top, .bottom:
      self.addCursorRect(self.resizeRect(), cursor: .resizeUpDown)
    case .right, .left:
      self.addCursorRect(self.resizeRect(), cursor: .resizeLeftRight)
    }
  }

  private func drawInnerSeparator(_ dirtyRect: NSRect) {
    self.theme.separator.set()

    let innerLineRect = self.innerSeparatorRect()
    if dirtyRect.intersects(innerLineRect) {
      innerLineRect.fill()
    }
  }

  private func drawOuterSeparator(_ dirtyRect: NSRect) {
    self.theme.separator.set()

    let outerLineRect = self.outerSeparatorRect()
    if dirtyRect.intersects(outerLineRect) {
      outerLineRect.fill()
    }
  }

  private func buttonSize() -> CGSize {
    if self.isEmpty() {
      return CGSize.zero
    }

    return WorkspaceToolButton.size(forLocation: self.location)
  }

  private func innerSeparatorRect() -> CGRect {
    let bounds = self.bounds
    let thickness = WorkspaceBar.separatorThickness
    let bar = self.buttonSize()

    switch self.location {
    case .top:
      return CGRect(
        x: 0,
        y: bounds.height - bar.height - thickness,
        width: bounds.width,
        height: thickness
      )
    case .right:
      return CGRect(
        x: bounds.width - bar.width - thickness,
        y: 0,
        width: thickness,
        height: bounds.height
      )
    case .bottom:
      return CGRect(x: 0, y: bar.height, width: bounds.width, height: thickness)
    case .left:
      return CGRect(x: bar.width, y: 0, width: thickness, height: bounds.height)
    }
  }

  private func newDimension(forLocationInSuperview locInSuperview: CGPoint) -> CGFloat {
    let dimension = self.dimension(forLocationInSuperview: locInSuperview)
    return self.dragIncrement * floor(dimension / self.dragIncrement)
  }

  private func dimension(forLocationInSuperview locInSuperview: CGPoint) -> CGFloat {
    let superviewBounds = self.superview!.bounds

    switch self.location {
    case .top:
      return superviewBounds.height - locInSuperview.y
    case .right:
      return superviewBounds.width - locInSuperview.x
    case .bottom:
      return locInSuperview.y
    case .left:
      return locInSuperview.x
    }
  }

  private func sq(_ number: CGFloat) -> CGFloat {
    number * number
  }

  private func outerSeparatorRect() -> CGRect {
    let thickness = WorkspaceBar.separatorThickness

    switch self.location {
    case .top:
      return CGRect(x: 0, y: 0, width: self.bounds.width, height: thickness)
    case .right:
      return CGRect(x: 0, y: 0, width: thickness, height: self.bounds.height)
    case .bottom:
      return CGRect(
        x: 0,
        y: self.bounds.height - thickness,
        width: self.bounds.width,
        height: thickness
      )
    case .left:
      return CGRect(
        x: self.bounds.width - thickness,
        y: 0,
        width: thickness,
        height: self.bounds.height
      )
    }
  }

  private func resizeRect() -> CGRect {
    let separatorRect = self.outerSeparatorRect()
    let clickDimension = 4.0

    switch self.location {
    case .top:
      return separatorRect.offsetBy(dx: 0, dy: clickDimension).union(separatorRect)
    case .right:
      return separatorRect.offsetBy(dx: clickDimension, dy: 0).union(separatorRect)
    case .bottom:
      return separatorRect.offsetBy(dx: 0, dy: -clickDimension).union(separatorRect)
    case .left:
      return separatorRect.offsetBy(dx: -clickDimension, dy: 0).union(separatorRect)
    }
  }

  private func set(dimension: CGFloat) {
    let saneDimension = self.saneDimension(from: dimension)

    self.dimensionConstraint.constant = saneDimension

    let toolDimension = self.toolDimension(fromBarDimension: saneDimension)
    if self.isOpen {
      self.selectedTool?.dimension = toolDimension
    }

    // In 10.12 we need the following, otherwise resizing the tools does not work correctly.
    self.layoutSubtreeIfNeeded()

    self.window?.invalidateCursorRects(for: self)
    self.needsDisplay = true
  }

  private func saneDimension(from dimension: CGFloat) -> CGFloat {
    if dimension == 0 {
      return 0
    }

    if self.isOpen {
      return max(dimension, self.selectedTool!.minimumDimension, WorkspaceBar.minimumDimension)
    }

    return max(dimension, self.barDimensionWithButtonsWithoutTool())
  }
}

// MARK: - Layout

extension WorkspaceBar {
  private func isEmpty() -> Bool {
    self.tools.isEmpty
  }

  private func hasTools() -> Bool {
    !self.isEmpty()
  }

  private func layoutWithoutButtons(_ tool: WorkspaceTool) {
    let view = tool
    let thickness = WorkspaceBar.separatorThickness

    self.addSubview(view)
    switch self.location {
    case .top:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top),
        view.autoPinEdge(toSuperviewEdge: .right),
        view.autoPinEdge(toSuperviewEdge: .bottom, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .left),

        view.autoSetDimension(
          .height,
          toSize: tool.minimumDimension,
          relation: .greaterThanOrEqual
        ),
      ])
    case .right:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top),
        view.autoPinEdge(toSuperviewEdge: .right),
        view.autoPinEdge(toSuperviewEdge: .bottom),
        view.autoPinEdge(toSuperviewEdge: .left, withInset: thickness),

        view.autoSetDimension(.width, toSize: tool.minimumDimension, relation: .greaterThanOrEqual),
      ])
    case .bottom:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .right),
        view.autoPinEdge(toSuperviewEdge: .bottom),
        view.autoPinEdge(toSuperviewEdge: .left),

        view.autoSetDimension(
          .height,
          toSize: tool.minimumDimension,
          relation: .greaterThanOrEqual
        ),
      ])
    case .left:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top),
        view.autoPinEdge(toSuperviewEdge: .right, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .bottom),
        view.autoPinEdge(toSuperviewEdge: .left),

        view.autoSetDimension(.width, toSize: tool.minimumDimension, relation: .greaterThanOrEqual),
      ])
    }
  }

  private func layout(_ tool: WorkspaceTool) {
    let view = tool
    let button = tool.button
    let thickness = WorkspaceBar.separatorThickness

    self.addSubview(view)

    switch self.location {
    case .top:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(.top, to: .bottom, of: button, withOffset: thickness),
        view.autoPinEdge(toSuperviewEdge: .right),
        view.autoPinEdge(toSuperviewEdge: .bottom, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .left),

        view.autoSetDimension(
          .height,
          toSize: tool.minimumDimension,
          relation: .greaterThanOrEqual
        ),
      ])
    case .right:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top),
        view.autoPinEdge(.right, to: .left, of: button, withOffset: -thickness),
        // Offset is count l -> r,
        view.autoPinEdge(toSuperviewEdge: .bottom),
        view.autoPinEdge(toSuperviewEdge: .left, withInset: thickness),

        view.autoSetDimension(.width, toSize: tool.minimumDimension, relation: .greaterThanOrEqual),
      ])
    case .bottom:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .right),
        view.autoPinEdge(.bottom, to: .top, of: button, withOffset: -thickness),
        // Offset is count t -> b,
        view.autoPinEdge(toSuperviewEdge: .left),

        view.autoSetDimension(
          .height,
          toSize: tool.minimumDimension,
          relation: .greaterThanOrEqual
        ),
      ])
    case .left:
      self.layoutConstraints.append(contentsOf: [
        view.autoPinEdge(toSuperviewEdge: .top),
        view.autoPinEdge(toSuperviewEdge: .right, withInset: thickness),
        view.autoPinEdge(toSuperviewEdge: .bottom),
        view.autoPinEdge(.left, to: .right, of: button, withOffset: thickness),

        view.autoSetDimension(.width, toSize: tool.minimumDimension, relation: .greaterThanOrEqual),
      ])
    }
  }

  private func draggedButtonDimension() -> CGFloat {
    guard let idx = self.proxyBar.draggedOnToolIdx else {
      return 0
    }

    let button = self.tools[idx].button

    switch button.location {
    case .top, .bottom:
      switch self.location {
      case .top, .bottom:
        return button.intrinsicContentSize.width
      case .left, .right:
        return button.intrinsicContentSize.width
      }
    case .left, .right:
      switch self.location {
      case .top, .bottom:
        return button.intrinsicContentSize.height
      case .left, .right:
        return button.intrinsicContentSize.height
      }
    }
  }

  private func layoutButtons() {
    guard let firstTool = self.tools.first else {
      return
    }

    self.tools
      .map(\.button)
      .forEach { self.addSubview($0) }

    let dimensionForDraggedButton = self.draggedButtonDimension()

    let firstButton = firstTool.button
    let firstButtonMargin = self.proxyBar.draggedOnToolIdx == 0 ? dimensionForDraggedButton : 0
    switch self.location {
    case .top:
      self.layoutConstraints.append(contentsOf: [
        firstButton.autoPinEdge(toSuperviewEdge: .top),
        firstButton.autoPinEdge(toSuperviewEdge: .left, withInset: firstButtonMargin),
      ])
    case .right:
      self.layoutConstraints.append(contentsOf: [
        firstButton.autoPinEdge(toSuperviewEdge: .top, withInset: firstButtonMargin),
        firstButton.autoPinEdge(toSuperviewEdge: .right),
      ])
    case .bottom:
      self.layoutConstraints.append(contentsOf: [
        firstButton.autoPinEdge(toSuperviewEdge: .left, withInset: firstButtonMargin),
        firstButton.autoPinEdge(toSuperviewEdge: .bottom),
      ])
    case .left:
      self.layoutConstraints.append(contentsOf: [
        firstButton.autoPinEdge(toSuperviewEdge: .top, withInset: firstButtonMargin),
        firstButton.autoPinEdge(toSuperviewEdge: .left),
      ])
    }

    var lastButton = firstButton
    self.tools
      .map(\.button)
      .enumerated()
      .forEach { idx, button in
        // self.tools.first is already done above
        guard idx > 0 else {
          return
        }

        let margin = self.proxyBar.draggedOnToolIdx == idx ? dimensionForDraggedButton : 0
        switch self.location {
        case .top:
          self.layoutConstraints.append(contentsOf: [
            button.autoPinEdge(toSuperviewEdge: .top),
            button.autoPinEdge(.left, to: .right, of: lastButton, withOffset: margin),
          ])
        case .right:
          self.layoutConstraints.append(contentsOf: [
            button.autoPinEdge(.top, to: .bottom, of: lastButton, withOffset: margin),
            button.autoPinEdge(toSuperviewEdge: .right),
          ])
        case .bottom:
          self.layoutConstraints.append(contentsOf: [
            button.autoPinEdge(.left, to: .right, of: lastButton, withOffset: margin),
            button.autoPinEdge(toSuperviewEdge: .bottom),
          ])
        case .left:
          self.layoutConstraints.append(contentsOf: [
            button.autoPinEdge(.top, to: .bottom, of: lastButton, withOffset: margin),
            button.autoPinEdge(toSuperviewEdge: .left),
          ])
        }

        lastButton = button
      }
  }

  private func barDimensionWithButtonsWithoutTool() -> CGFloat {
    switch self.location {
    case .top, .bottom:
      self.buttonSize().height + WorkspaceBar.separatorThickness
    case .right, .left:
      self.buttonSize().width + WorkspaceBar.separatorThickness
    }
  }

  private func barDimensionWithoutButtons(withToolDimension toolDimension: CGFloat) -> CGFloat {
    toolDimension + WorkspaceBar.separatorThickness
  }

  private func barDimension(withToolDimension toolDimension: CGFloat) -> CGFloat {
    self.barDimensionWithButtonsWithoutTool() + toolDimension + WorkspaceBar.separatorThickness
  }

  private func toolDimension(fromBarDimension barDimension: CGFloat) -> CGFloat {
    if self.isButtonVisible {
      return barDimension - WorkspaceBar.separatorThickness - self
        .barDimensionWithButtonsWithoutTool()
    }

    return barDimension - WorkspaceBar.separatorThickness
  }
}

// MARK: - WorkspaceToolDelegate

extension WorkspaceBar {
  func toggle(_ tool: WorkspaceTool) {
    self.delegate?.resizeWillStart(workspaceBar: self, tool: self.selectedTool)

    if self.isOpen {
      let curTool = self.selectedTool!
      if curTool == tool {
        // In this case, curTool.isSelected is already set to false in WorkspaceTool.toggle()
        self.selectedTool = nil
      } else {
        curTool.isSelected = false
        self.selectedTool = tool
      }

    } else {
      self.selectedTool = tool
    }

    self.relayout()

    self.delegate?.resizeDidEnd(workspaceBar: self, tool: self.selectedTool)
    self.delegate?.toggle(tool: tool)
  }
}
