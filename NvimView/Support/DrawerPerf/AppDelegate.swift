/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import GameKit
import os

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var window: NSWindow!
  var result = [[[FontGlyphRun]]](repeating: [], count: count)

  func applicationDidFinishLaunching(_: Notification) {
    var results = [CFTimeInterval]()
    let repeatCount = 5
    for _ in 0..<repeatCount {
      let rd = GKRandomDistribution(
        randomSource: GKMersenneTwisterRandomSource(seed: 129_384_832),
        lowestValue: 0,
        highestValue: repeatCount - 1
      )
      let indices = (0..<count).map { _ in rd.nextInt() % 3 }

      let time = self.measure {
        for i in 0..<count {
          self.result[i] = self.perf.render(indices[i])
        }
      }
      results.append(time)
    }

    self.log.default(
      "\(results.reduce(0, +) / Double(results.count))s: \(results)"
    )

    NSApp.terminate(self)
  }

  private let perf = PerfTester()

  private let log = OSLog(
    subsystem: "com.qvacua.DrawerPerf",
    category: "perf-tester"
  )

  private func measure(_ body: () -> Void) -> CFTimeInterval {
    let start = CFAbsoluteTimeGetCurrent()
    body()
    return CFAbsoluteTimeGetCurrent() - start
  }
}

private let count = 500
