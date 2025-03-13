/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import Combine
import Commons
import NvimView
import PureLayout

final class BuffersList: NSView,
  UiComponent,
  NSTableViewDataSource,
  NSTableViewDelegate,
  ThemedView
{
  typealias StateType = MainWindow.State

  enum Action {
    case open(NvimView.Buffer)
  }

  let uuid = UUID()
  private(set) var lastThemeMark = Token()
  private(set) var theme = Theme.default

  required init(context: ReduxContext, emitter: ActionEmitter, state: StateType) {
    self.context = context
    self.emit = emitter.typedEmit()
    self.mainWinUuid = state.uuid

    self.usesTheme = state.appearance.usesTheme
    self.showsFileIcon = state.appearance.showsFileIcon

    super.init(frame: .zero)

    self.bufferList.dataSource = self
    self.bufferList.allowsEmptySelection = true
    self.bufferList.delegate = self
    self.bufferList.target = self
    self.bufferList.doubleAction = #selector(BuffersList.doubleClickAction)

    self.addViews()

    context.subscribe(uuid: self.uuid) { appState in
      guard let state = appState.mainWindows[self.mainWinUuid] else { return }

      if state.viewToBeFocused != nil,
         case .bufferList = state.viewToBeFocused!
      {
        self.beFirstResponder()
      }

      let themeChanged = changeTheme(
        themePrefChanged: state.appearance.usesTheme != self.usesTheme,
        themeChanged: state.appearance.theme.mark != self.lastThemeMark,
        usesTheme: state.appearance.usesTheme,
        forTheme: { self.updateTheme(state.appearance.theme) },
        forDefaultTheme: { self.updateTheme(Marked(Theme.default)) }
      )

      self.usesTheme = state.appearance.usesTheme

      if self.buffers == state.buffers,
         !themeChanged,
         self.showsFileIcon == state.appearance.showsFileIcon
      {
        return
      }

      self.showsFileIcon = state.appearance.showsFileIcon
      self.buffers = state.buffers
      self.bufferList.reloadData()
    }
  }

  func cleanup() {
    self.context.unsubscribe(uuid: self.uuid)
  }

  private let context: ReduxContext
  private let emit: (UuidAction<Action>) -> Void
  private var cancellables = Set<AnyCancellable>()

  private let mainWinUuid: UUID
  private var usesTheme: Bool
  private var showsFileIcon: Bool

  private let bufferList = NSTableView.standardTableView()

  private var buffers = [NvimView.Buffer]()

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func updateTheme(_ theme: Marked<Theme>) {
    self.theme = theme.payload
    self.bufferList.enclosingScrollView?.backgroundColor = self.theme.background
    self.bufferList.backgroundColor = self.theme.background
    self.lastThemeMark = theme.mark
  }

  private func addViews() {
    let scrollView = NSScrollView.standardScrollView()
    scrollView.borderType = .noBorder
    scrollView.documentView = self.bufferList

    self.addSubview(scrollView)
    scrollView.autoPinEdgesToSuperviewEdges()
  }
}

// MARK: - Actions

extension BuffersList {
  @objc func doubleClickAction(_: Any?) {
    let clickedRow = self.bufferList.clickedRow
    guard clickedRow >= 0, clickedRow < self.buffers.count else {
      return
    }

    self.emit(UuidAction(uuid: self.mainWinUuid, action: .open(self.buffers[clickedRow])))
  }
}

// MARK: - NSTableViewDataSource

extension BuffersList {
  @objc(numberOfRowsInTableView:)
  func numberOfRows(in _: NSTableView) -> Int {
    self.buffers.count
  }
}

// MARK: - NSTableViewDelegate

extension BuffersList {
  public func tableView(
    _ tableView: NSTableView,
    rowViewForRow _: Int
  ) -> NSTableRowView? {
    tableView.makeView(
      withIdentifier: NSUserInterfaceItemIdentifier("buffer-row-view"),
      owner: self
    ) as? ThemedTableRow ?? ThemedTableRow(
      withIdentifier: "buffer-row-view",
      themedView: self
    )
  }

  func tableView(
    _ tableView: NSTableView,
    viewFor _: NSTableColumn?,
    row: Int
  ) -> NSView? {
    let cachedCell = (tableView.makeView(
      withIdentifier: NSUserInterfaceItemIdentifier("buffer-cell-view"),
      owner: self
    ) as? ThemedTableCell)?.reset()

    let cell = cachedCell ?? ThemedTableCell(withIdentifier: "buffer-cell-view")

    let buffer = self.buffers[row]
    cell.attributedText = self.text(for: buffer)

    guard self.showsFileIcon else {
      return cell
    }

    cell.image = self.icon(for: buffer)

    return cell
  }

  func tableView(
    _: NSTableView,
    didAdd rowView: NSTableRowView,
    forRow _: Int
  ) {
    guard let cellWidth = (rowView.view(atColumn: 0) as? NSTableCellView)?
      .fittingSize.width
    else {
      return
    }

    self.bufferList.tableColumns[0].width = max(
      self.bufferList.tableColumns[0].width, cellWidth + 10.0
    )
  }

  private func text(for buffer: NvimView.Buffer) -> NSAttributedString {
    guard let name = buffer.name else {
      return NSAttributedString(string: "No Name")
    }

    guard let url = buffer.url else {
      return NSAttributedString(string: name)
    }

    let pathInfo = url.pathComponents
      .dropFirst()
      .dropLast()
      .reversed()
      .joined(separator: " / ") + " /"
    let rowText = NSMutableAttributedString(string: "\(name) — \(pathInfo)")

    rowText.addAttribute(
      NSAttributedString.Key.foregroundColor,
      value: self.theme.foreground,
      range: NSRange(location: 0, length: name.count)
    )

    rowText.addAttribute(
      NSAttributedString.Key.foregroundColor,
      value: self.theme.foreground.brightening(by: 1.15),
      range: NSRange(location: name.count, length: pathInfo.count + 3)
    )

    return rowText
  }

  private func icon(for buffer: NvimView.Buffer) -> NSImage? {
    if let url = buffer.url {
      return FileUtils.icon(forUrl: url)
    }

    return genericIcon
  }
}

private let genericIcon = FileUtils.icon(forType: "public.data")
