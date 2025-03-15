/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa

final class UiRoot: UiComponent {
  typealias StateType = AppState

  enum Action {
    case quit
  }

  let uuid = UUID()

  required init(context: ReduxContext, state: StateType) {
    self.context = context
    self.emitter = context.actionEmitter
    self.emit = context.actionEmitter.typedEmit()

    self.openQuicklyWindow = OpenQuicklyWindow(context: context, state: state)
    self.prefWindow = PrefWindow(context: context, state: state)
    self.prefWindow.shortcutService = self.shortcutService

    self.activateAsciiImInInsertMode = state.activateAsciiImInNormalMode

    context.subscribe(uuid: self.uuid) { state in
      let uuidsInState = Set(state.mainWindows.keys)

      uuidsInState
        .subtracting(self.mainWindows.keys)
        .compactMap { state.mainWindows[$0] }
        .map(self.newMainWindow)
        .forEach { mainWindow in
          mainWindow.show()
        }

      if self.mainWindows.isEmpty {
        // We exit here if there are no main windows open.
        // Otherwise, when hide/quit after last main window is active,
        // you have to be really quick to open a new window
        // when re-activating VimR w/o automatic new main window.
        return
      }

      try? self.mainWindows.keys
        .filter { !uuidsInState.contains($0) }
        .forEach(self.removeMainWindow)

      if self.activateAsciiImInInsertMode != state.activateAsciiImInNormalMode {
        self.activateAsciiImInInsertMode = state.activateAsciiImInNormalMode
        self.mainWindows.values
          .forEach { $0.activateAsciiImInInsertMode = self.activateAsciiImInInsertMode }
      }

      guard self.mainWindows.isEmpty else { return }

      switch state.afterLastWindowAction {
      case .doNothing: return
      case .hide: NSApp.hide(self)
      case .quit: self.emit(.quit)
      }
    }
  }

  // The following should only be used when Cmd-Q'ing
  func hasBlockedWindows() async -> Bool {
    for mainWin in self.mainWindows.values {
      if await mainWin.neoVimView.isBlocked() { return true }
    }

    return false
  }

  // The following should only be used when Cmd-Q'ing
  func prepareQuit() async {
    self.mainWindows.values.forEach { $0.prepareClosing() }

    if !self.mainWindows.isEmpty {
      for mainWin in self.mainWindows.values {
        await mainWin.quitNeoVimWithoutSaving()
      }
    }

    self.openQuicklyWindow.cleanUp()
  }

  private let context: ReduxContext
  private let emitter: ActionEmitter
  private let emit: (Action) -> Void

  private let shortcutService = ShortcutService()
  private let openQuicklyWindow: OpenQuicklyWindow
  private let prefWindow: PrefWindow

  private var activateAsciiImInInsertMode = true

  private var mainWindows = [UUID: MainWindow]()

  private func newMainWindow(with state: MainWindow.State) -> MainWindow {
    let mainWin = MainWindow(context: self.context, state: state)
    // sync global self state to child window
    mainWin.shortcutService = self.shortcutService
    mainWin.activateAsciiImInInsertMode = self.activateAsciiImInInsertMode

    self.mainWindows[mainWin.uuid] = mainWin

    return mainWin
  }

  private func removeMainWindow(with uuid: UUID) {
    guard let mainWin = self.mainWindows.removeValue(forKey: uuid) else { return }
    mainWin.cleanup()
  }
}
