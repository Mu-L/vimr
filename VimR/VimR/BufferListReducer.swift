/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Foundation

final class BuffersListReducer: ReducerType {
  typealias StateType = MainWindow.State
  typealias ActionType = UuidAction<BuffersList.Action>

  func typedReduce(_ tuple: ReduceTuple<StateType, ActionType>)
    -> ReduceTuple<StateType, ActionType>
  {
    var state = tuple.state

    switch tuple.action.payload {
    case let .open(buffer):
      state.currentBufferToSet = buffer
    }

    return ReduceTuple(state: state, action: tuple.action, modified: true)
  }
}
