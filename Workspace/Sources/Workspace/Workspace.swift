/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import PureLayout

public enum WorkspaceBarLocation: String, Codable, CaseIterable, Sendable {
  case top
  case right
  case bottom
  case left
}

@MainActor
public protocol WorkspaceDelegate: AnyObject {
  func resizeWillStart(workspace: Workspace, tool: WorkspaceTool?)
  func resizeDidEnd(workspace: Workspace, tool: WorkspaceTool?)

  func toggled(tool: WorkspaceTool)
  func moved(tool: WorkspaceTool)
}

public final class Workspace: NSView, WorkspaceBarDelegate {
  // MARK: - Public

  public struct Config {
    public let mainViewMinimumSize: CGSize

    public init(mainViewMinimumSize: CGSize) { self.mainViewMinimumSize = mainViewMinimumSize }
  }

  public struct Theme: Sendable {
    public static let `default` = Workspace.Theme()

    public var foreground = NSColor.black
    public var background = NSColor.white

    public var separator = NSColor.separatorColor

    public var barBackground = NSColor.windowBackgroundColor
    public var barFocusRing = NSColor.selectedControlColor

    public var barButtonBackground = NSColor.clear
    public var barButtonHighlight = NSColor.separatorColor

    public var toolbarForeground = NSColor.darkGray
    public var toolbarBackground = NSColor(red: 0.899, green: 0.934, blue: 0.997, alpha: 1)

    public init() {}
  }

  public private(set) var isAllToolsVisible = true {
    didSet { self.relayout() }
  }

  public private(set) var isToolButtonsVisible = true {
    didSet { self.bars.values.forEach { $0.isButtonVisible = !$0.isButtonVisible } }
  }

  public var orderedTools: [WorkspaceTool] {
    self.bars.values.reduce([]) { [$0, $1.tools].flatMap(\.self) }
  }

  public let mainView: NSView
  public let config: Config

  public var theme = Workspace.Theme.default {
    didSet { self.repaint() }
  }

  public weak var delegate: WorkspaceDelegate?

  public init(
    mainView: NSView,
    config: Config = Config(mainViewMinimumSize: CGSize(width: 100, height: 100))
  ) {
    self.config = config
    self.mainView = mainView

    self.bars = [
      .top: WorkspaceBar(location: .top),
      .right: WorkspaceBar(location: .right),
      .bottom: WorkspaceBar(location: .bottom),
      .left: WorkspaceBar(location: .left),
    ]

    super.init(frame: .init(x: 0, y: 0, width: 640, height: 480))
    self.configureForAutoLayout()

    self.registerForDraggedTypes([NSPasteboard.PasteboardType(WorkspaceToolButton.toolUti)])
    for value in self.bars.values {
      value.workspace = self
      value.delegate = self
    }

    self.relayout()
  }

  public func append(tool: WorkspaceTool, location: WorkspaceBarLocation) {
    if self.tools.contains(tool) {
      return
    }

    self.tools.append(tool)
    self.bars[location]?.append(tool: tool)
  }

  public func move(tool: WorkspaceTool, to location: WorkspaceBarLocation) {
    tool.bar?.remove(tool: tool)
    self.bars[location]?.append(tool: tool)

    self.delegate?.moved(tool: tool)
  }

  public func hideAllTools() {
    if self.isAllToolsVisible {
      self.isAllToolsVisible = false
    }
  }

  public func showAllTools() {
    if !self.isAllToolsVisible {
      self.isAllToolsVisible = true
    }
  }

  public func toggleAllTools() {
    self.isAllToolsVisible = !self.isAllToolsVisible
  }

  public func hideToolButtons() {
    if self.isToolButtonsVisible {
      self.isToolButtonsVisible = false
    }
  }

  public func showToolButtons() {
    if !self.isToolButtonsVisible {
      self.isToolButtonsVisible = true
    }
  }

  public func toggleToolButtons() {
    self.isToolButtonsVisible = !self.isToolButtonsVisible
  }

  // MARK: - Internal and private

  @available(*, unavailable)
  required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

  let bars: [WorkspaceBarLocation: WorkspaceBar]

  private var tools = [WorkspaceTool]()
  private var isDragOngoing = false
  private var draggedOnBarLocation: WorkspaceBarLocation?
  private let proxyBar = ProxyWorkspaceBar(forAutoLayout: ())
}

// MARK: - NSDraggingDestination

public extension Workspace {
  override func draggingEntered(_: NSDraggingInfo) -> NSDragOperation {
    self.isDragOngoing = true
    return .move
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let loc = self.convert(sender.draggingLocation, from: nil)
    let currentBarLoc = self.barLocation(inPoint: loc)

    if currentBarLoc == self.draggedOnBarLocation {
      return .move
    }

    self.draggedOnBarLocation = currentBarLoc
    self.relayout()
    return .move
  }

  override func draggingExited(_: NSDraggingInfo?) {
    self.endDrag()
  }

  override func draggingEnded(_: NSDraggingInfo) {
    self.endDrag()
  }

  private func endDrag() {
    self.isDragOngoing = false
    self.draggedOnBarLocation = nil
    self.proxyBar.removeFromSuperview()
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let loc = self.convert(sender.draggingLocation, from: nil)
    guard let barLoc = self.barLocation(inPoint: loc) else {
      return false
    }

    guard let toolButton = sender.draggingSource as? WorkspaceToolButton else {
      return false
    }

    guard let tool = toolButton.tool else {
      return false
    }

    self.move(tool: tool, to: barLoc)

    return true
  }

  private func barLocation(inPoint loc: CGPoint) -> WorkspaceBarLocation? {
    return WorkspaceBarLocation.allCases.first(where: { self.rect(forBar: $0).contains(loc) })
  }

  // We copy and pasted WorkspaceBar.barFrame() since we need the rect for the proxy bars.
  private func rect(forBar location: WorkspaceBarLocation) -> CGRect {
    let size = self.bounds.size
    let dimension = self.bars[location]!.dimensionWithoutTool()

    switch location {
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
}

// MARK: - WorkspaceBarDelegate

extension Workspace {
  func resizeWillStart(workspaceBar _: WorkspaceBar, tool: WorkspaceTool?) {
    self.delegate?.resizeWillStart(workspace: self, tool: tool)
  }

  func resizeDidEnd(workspaceBar _: WorkspaceBar, tool: WorkspaceTool?) {
    self.delegate?.resizeDidEnd(workspace: self, tool: tool)
  }

  func toggle(tool: WorkspaceTool) {
    self.delegate?.toggled(tool: tool)
  }

  func moved(tool: WorkspaceTool) {
    self.delegate?.moved(tool: tool)
  }
}

// MARK: - Layout

private extension Workspace {
  private func repaint() {
    self.bars.values.forEach { $0.repaint() }
    self.proxyBar.repaint()
    self.needsDisplay = true
  }

  private func relayout() {
    // FIXME: I did not investigate why toggleButtons does not work correctly if we store all constraints in an array
    // and remove them here by self.removeConstraints(${all constraints). The following seems to
    // work...
    self.subviews.forEach { $0.removeAllConstraints() }
    self.removeAllSubviews()

    let mainView = self.mainView
    self.addSubview(mainView)

    mainView.autoSetDimension(
      .width,
      toSize: self.config.mainViewMinimumSize.width,
      relation: .greaterThanOrEqual
    )
    mainView.autoSetDimension(
      .height,
      toSize: self.config.mainViewMinimumSize.height,
      relation: .greaterThanOrEqual
    )

    guard self.isAllToolsVisible else {
      mainView.autoPinEdgesToSuperviewEdges()
      return
    }

    let topBar = self.bars[.top]!
    let rightBar = self.bars[.right]!
    let bottomBar = self.bars[.bottom]!
    let leftBar = self.bars[.left]!

    self.addSubview(topBar)
    self.addSubview(rightBar)
    self.addSubview(bottomBar)
    self.addSubview(leftBar)

    topBar.autoPinEdge(toSuperviewEdge: .top)
    topBar.autoPinEdge(toSuperviewEdge: .right)
    topBar.autoPinEdge(toSuperviewEdge: .left)

    rightBar.autoPinEdge(.top, to: .bottom, of: topBar)
    rightBar.autoPinEdge(toSuperviewEdge: .right)
    rightBar.autoPinEdge(.bottom, to: .top, of: bottomBar)

    bottomBar.autoPinEdge(toSuperviewEdge: .right)
    bottomBar.autoPinEdge(toSuperviewEdge: .bottom)
    bottomBar.autoPinEdge(toSuperviewEdge: .left)

    leftBar.autoPinEdge(.top, to: .bottom, of: topBar)
    leftBar.autoPinEdge(toSuperviewEdge: .left)
    leftBar.autoPinEdge(.bottom, to: .top, of: bottomBar)

    NSLayoutConstraint.autoSetPriority(.dragThatCannotResizeWindow) {
      topBar.dimensionConstraint = topBar.autoSetDimension(.height, toSize: 50)
      rightBar.dimensionConstraint = rightBar.autoSetDimension(.width, toSize: 50)
      bottomBar.dimensionConstraint = bottomBar.autoSetDimension(.height, toSize: 50)
      leftBar.dimensionConstraint = leftBar.autoSetDimension(.width, toSize: 50)
    }

    self.bars.values.forEach { $0.relayout() }

    mainView.autoPinEdge(.top, to: .bottom, of: topBar)
    mainView.autoPinEdge(.right, to: .left, of: rightBar)
    mainView.autoPinEdge(.bottom, to: .top, of: bottomBar)
    mainView.autoPinEdge(.left, to: .right, of: leftBar)

    if let barLoc = self.draggedOnBarLocation {
      let proxyBar = self.proxyBar
      self.addSubview(proxyBar)

      let barRect = self.rect(forBar: barLoc)
      switch barLoc {
      case .top:
        proxyBar.autoPinEdge(toSuperviewEdge: .top)
        proxyBar.autoPinEdge(toSuperviewEdge: .right)
        proxyBar.autoPinEdge(toSuperviewEdge: .left)
        proxyBar.autoSetDimension(.height, toSize: barRect.height)

      case .right:
        proxyBar.autoPinEdge(.top, to: .bottom, of: topBar)
        proxyBar.autoPinEdge(toSuperviewEdge: .right)
        proxyBar.autoPinEdge(.bottom, to: .top, of: bottomBar)
        proxyBar.autoSetDimension(.width, toSize: barRect.width)

      case .bottom:
        proxyBar.autoPinEdge(toSuperviewEdge: .right)
        proxyBar.autoPinEdge(toSuperviewEdge: .bottom)
        proxyBar.autoPinEdge(toSuperviewEdge: .left)
        proxyBar.autoSetDimension(.height, toSize: barRect.height)

      case .left:
        proxyBar.autoPinEdge(.top, to: .bottom, of: topBar)
        proxyBar.autoPinEdge(toSuperviewEdge: .left)
        proxyBar.autoPinEdge(.bottom, to: .top, of: bottomBar)
        proxyBar.autoSetDimension(.width, toSize: barRect.width)
      }
    }

    self.needsDisplay = true
  }
}
