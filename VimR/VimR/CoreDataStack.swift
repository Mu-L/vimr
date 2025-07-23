/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Commons
import CoreData
import Foundation
import os

final class CoreDataStack {
  enum Error: Swift.Error {
    case noCacheFolder
    case pathDoesNotExit
    case pathNotFolder

    case unableToComplete(Swift.Error)
  }

  enum StoreLocation {
    case temp(String)
    case cache(String)
    case path(String)
  }

  let container: NSPersistentContainer
  let storeFile: URL
  var storeLocation: URL { self.storeFile.parent }

  func newBackgroundContext() -> NSManagedObjectContext {
    let context = self.container.newBackgroundContext()
    context.undoManager = nil

    return context
  }

  init(modelName: String, storeLocation: StoreLocation) throws {
    self.container = NSPersistentContainer(name: modelName)

    let fileManager = FileManager.default
    let url: URL
    switch storeLocation {
    case let .temp(folderName):
      let parentUrl = fileManager
        .temporaryDirectory
        .appendingPathComponent(folderName)
      try fileManager.createDirectory(at: parentUrl, withIntermediateDirectories: true)
      url = parentUrl.appendingPathComponent(modelName)

    case let .cache(folderName):
      guard let cacheUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        throw Error.noCacheFolder
      }
      let parentUrl = cacheUrl.appendingPathComponent(folderName)
      try fileManager.createDirectory(at: parentUrl, withIntermediateDirectories: true)

      url = parentUrl.appendingPathComponent(modelName)

    case let .path(path):
      guard fileManager.fileExists(atPath: path) else { throw Error.pathDoesNotExit }

      let parentFolder = URL(fileURLWithPath: path)
      guard parentFolder.hasDirectoryPath else { throw Error.pathNotFolder }

      url = parentFolder.appendingPathComponent(modelName)
    }

    self.container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
    self.storeFile = url

    self.log.info("Created Core Data store in \(self.storeLocation)")

    let condition = ConditionVariable()
    var error: Swift.Error?
    self.container.loadPersistentStores { _, err in
      error = err
      condition.broadcast()
    }
    condition.wait(for: 5)

    if let err = error { throw Error.unableToComplete(err) }

    self.container.viewContext.undoManager = nil
  }

  func deleteStore() throws {
    guard let store = self.container.persistentStoreCoordinator.persistentStore(
      for: self.storeFile
    ) else { return }

    try self.container.persistentStoreCoordinator.remove(store)
    let parentFolder = self.storeLocation

    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: parentFolder.path) else { return }

    try fileManager.removeItem(at: parentFolder)
    self.log.info("Deleted store at \(self.storeLocation)")
  }

  deinit {
    do {
      try self.deleteStore()
    } catch {
      self.log.error("Could not delete store at \(self.storeLocation): \(error)")
    }
  }

  private let log = OSLog(subsystem: Defs.loggerSubsystem, category: Defs.LoggerCategory.service)
}
