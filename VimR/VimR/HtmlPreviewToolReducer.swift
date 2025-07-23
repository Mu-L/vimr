/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Foundation

final class HtmlPreviewReducer {
  static let basePath = "tools/html-preview"

  static func serverUrl(baseUrl: URL, uuid: UUID) -> URL {
    baseUrl.appendingPathComponent("\(uuid)/\(self.basePath)/index.html")
  }

  let mainWindow: MainWindowReducer
  let htmlPreview: HtmlPreviewToolReducer

  init(baseServerUrl: URL) {
    self.mainWindow = MainWindowReducer(baseServerUrl: baseServerUrl)
    self.htmlPreview = HtmlPreviewToolReducer(baseServerUrl: baseServerUrl)
  }

  class MainWindowReducer: ReducerType {
    typealias StateType = MainWindow.State
    typealias ActionType = UuidAction<MainWindow.Action>

    init(baseServerUrl: URL) { self.baseServerUrl = baseServerUrl }

    func typedReduce(_ tuple: ReduceTuple<StateType, ActionType>)
      -> ReduceTuple<StateType, ActionType>
    {
      var state = tuple.state

      switch tuple.action.payload {
      case .setTheme:
        guard state.htmlPreview.htmlFile == nil else { return tuple }
        state.htmlPreview.server = Marked(
          HtmlPreviewReducer.serverUrl(baseUrl: self.baseServerUrl, uuid: state.uuid)
        )

      default:
        return tuple
      }

      return ReduceTuple(state: state, action: tuple.action, modified: true)
    }

    private let baseServerUrl: URL
  }

  class HtmlPreviewToolReducer: ReducerType {
    typealias StateType = MainWindow.State
    typealias ActionType = UuidAction<HtmlPreviewTool.Action>

    init(baseServerUrl: URL) { self.baseServerUrl = baseServerUrl }

    func typedReduce(_ tuple: ReduceTuple<StateType, ActionType>)
      -> ReduceTuple<StateType, ActionType>
    {
      var state = tuple.state
      switch tuple.action.payload {
      case let .selectHtmlFile(url):
        state.htmlPreview.htmlFile = url
        state.htmlPreview.server = Marked(
          HtmlPreviewReducer.serverUrl(baseUrl: self.baseServerUrl, uuid: state.uuid)
        )
      }

      return ReduceTuple(state: state, action: tuple.action, modified: true)
    }

    private let baseServerUrl: URL
  }
}
