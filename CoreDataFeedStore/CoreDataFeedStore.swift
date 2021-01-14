//
//  CoreDataFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Gustavo Arthur Vollbrecht on 10/01/21.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

public class CoreDataFeedStore : FeedStore {
	
	private let context : NSManagedObjectContext
	
	private let modelName = "DataModel"
	private let feedEntityName = "FeedDTO"
	
	public init(storeURL : URL, bundle: Bundle) throws {
		let model = try NSManagedObjectModel.load(modelName: self.modelName,
											   bundle: bundle)
		
		self.context = try NSPersistentContainer.loadBackgroundContext(modelName: self.modelName,
																   managedObjectModel: model,
																   storeURL: storeURL)
	}
	
	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		self.context.perform {
			do {
				try self.clearCache()
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}
	
	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		self.context.perform {
			do {
				try self.clearCache()
				try self.insert(feed, timestamp: timestamp)
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}
	
	public func retrieve(completion: @escaping RetrievalCompletion) {
		let fetchRequest  = NSFetchRequest<FeedDTO>(entityName: self.feedEntityName)
		
		do {
			let feed = try context.fetch(fetchRequest)
			
			if let latestFeed = feed.first {
				completion(.found(feed: DTOToLocal(DTO: latestFeed.feed), timestamp: latestFeed.timestamp))
			} else {
				completion(.empty)
			}
		} catch {
			completion(.failure(error))
		}
	}
	
	private func clearCache() throws {
		let deleteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: self.feedEntityName)
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetchRequest)
		
		try self.context.execute(deleteRequest)
		try self.context.saveIfNeeded()
	}
	
	private func insert(_ feed: [LocalFeedImage], timestamp: Date) throws {
		let feedManagedObject = FeedDTO(context: self.context)
		feedManagedObject.timestamp = timestamp
		feedManagedObject.feed = self.localToDTO(feed: feed)
		
		try self.context.saveIfNeeded()
	}
	
	private func localToDTO(feed: [LocalFeedImage]) -> NSOrderedSet {
		var feedImagesManagedObject : [LocalFeedImageDTO] = []
		
		feed.forEach {
			let image = LocalFeedImageDTO(context: self.context)
			image.id = $0.id
			image.imageDescription = $0.description
			image.location = $0.location
			image.url = $0.url
			
			feedImagesManagedObject.append(image)
		}
		
		return NSOrderedSet(array: feedImagesManagedObject)
	}
	
	private func DTOToLocal(DTO: NSOrderedSet) -> [LocalFeedImage] {
		return DTO.compactMap {
			if let image = $0 as? LocalFeedImageDTO {
				return LocalFeedImage(id: image.id,
									  description: image.imageDescription,
									  location: image.location,
									  url: image.url)
			}
			
			return nil
		}
	}
}

fileprivate extension NSManagedObjectContext {
	func saveIfNeeded() throws {
		if self.hasChanges {
			try self.save()
		}
	}
}

fileprivate extension NSManagedObjectModel {
	static func load(modelName: String, bundle: Bundle) throws -> NSManagedObjectModel {
		let model = bundle.url(forResource: modelName, withExtension: "momd").flatMap { NSManagedObjectModel(contentsOf: $0) }
		
		if let loadedModel = model {
			return loadedModel
		} else {
			throw NSError(domain: "Failed to load \(modelName) on Bundle \(bundle)", code: 0)
		}
	}
}

fileprivate extension NSPersistentContainer {
	static func loadBackgroundContext(modelName: String, managedObjectModel: NSManagedObjectModel, storeURL: URL) throws -> NSManagedObjectContext {
		let container = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
			
		var receivedError : Error? = nil
		container.loadPersistentStores { _, error in
			receivedError = error
		}
		
		if let error = receivedError {
			throw error
		}

		return container.newBackgroundContext()
	}
}
