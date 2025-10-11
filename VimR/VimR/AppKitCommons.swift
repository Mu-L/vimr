/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
@preconcurrency import Down

extension NSView {
  @objc var isFirstResponder: Bool { self.window?.firstResponder == self }
}

extension NSAttributedString {
  static func infoLabel(markdown: String) -> NSAttributedString {
    let down = Down(markdownString: markdown)
    guard let result = try? down.toAttributedString(styler: downStyler) else {
      preconditionFailure("Wrong markdown: \(markdown)")
    }

    return result
  }
}

extension NSTableView {
  static func standardTableView() -> NSTableView {
    let tableView = NSTableView(frame: .zero)

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.isEditable = false

    tableView.addTableColumn(column)
    tableView.rowSizeStyle = .default
    tableView.sizeLastColumnToFit()
    tableView.allowsEmptySelection = false
    tableView.allowsMultipleSelection = false
    tableView.headerView = nil
    tableView.focusRingType = .none

    return tableView
  }

  static func standardSourceListTableView() -> NSTableView {
    let tableView = self.standardTableView()
    tableView.style = .sourceList

    return tableView
  }
}

extension NSOutlineView {
  static func standardOutlineView() -> NSOutlineView {
    let outlineView = NSOutlineView(frame: .zero)
    NSOutlineView.configure(toStandard: outlineView)
    return outlineView
  }

  static func configure(toStandard outlineView: NSOutlineView) {
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.resizingMask = .autoresizingMask
    column.isEditable = false

    outlineView.addTableColumn(column)
    outlineView.outlineTableColumn = column
    outlineView.allowsEmptySelection = false
    outlineView.allowsMultipleSelection = false
    outlineView.headerView = nil
    outlineView.focusRingType = .none
  }

  /**
   The selected item. When the selection is empty, then returns `nil`.
   When multiple items are selected, then returns the last selected item.
   */
  var selectedItem: Any? {
    if self.selectedRow < 0 { return nil }

    return self.item(atRow: self.selectedRow)
  }

  var clickedItem: Any? {
    if self.clickedRow < 0 { return nil }

    return self.item(atRow: self.clickedRow)
  }

  func toggle(item: Any?) {
    if self.isItemExpanded(item) {
      self.collapseItem(item)
    } else {
      self.expandItem(item)
    }
  }
}

extension NSTextField {
  static func defaultTitleTextField() -> NSTextField {
    let field = NSTextField(forAutoLayout: ())
    field.backgroundColor = NSColor.clear
    field.isEditable = false
    field.isBordered = false
    return field
  }
}

extension NSScrollView {
  static func standardScrollView() -> NSScrollView {
    let scrollView = NSScrollView(forAutoLayout: ())

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .bezelBorder

    return scrollView
  }
}

private enum AttributedStringMarkdownStyler {
  static func new() -> Styler {
    let fonts = StaticFontCollection(
      body: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
      code: NSFont.userFixedPitchFont(ofSize: NSFont.smallSystemFontSize)!
    )

    let style = DownStylerConfiguration(fonts: fonts, paragraphStyles: ParagraphStyles())
    return DownStyler(configuration: style)
  }
}

private struct ParagraphStyles: ParagraphStyleCollection {
  let heading1: NSParagraphStyle
  let heading2: NSParagraphStyle
  let heading3: NSParagraphStyle
  let heading4: NSParagraphStyle
  let heading5: NSParagraphStyle
  let heading6: NSParagraphStyle
  let body: NSParagraphStyle
  let code: NSParagraphStyle

  init() {
    let headingStyle = NSParagraphStyle()

    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.paragraphSpacingBefore = 2
    bodyStyle.paragraphSpacing = 2
    bodyStyle.lineSpacing = 2

    let codeStyle = NSMutableParagraphStyle()
    codeStyle.paragraphSpacingBefore = 2
    codeStyle.paragraphSpacing = 2

    self.heading1 = headingStyle
    self.heading2 = headingStyle
    self.heading3 = headingStyle
    self.heading4 = headingStyle
    self.heading5 = headingStyle
    self.heading6 = headingStyle
    self.body = bodyStyle
    self.code = codeStyle
  }
}

private let fontCollection = StaticFontCollection(
  body: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
  code: NSFont.userFixedPitchFont(ofSize: NSFont.smallSystemFontSize)!
)

private let downStyler = AttributedStringMarkdownStyler.new()
