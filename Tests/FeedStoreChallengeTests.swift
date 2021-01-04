//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import XCTest
import FeedStoreChallenge

@objc(LocalFeedImageDTO)
public class LocalFeedImageDTO: NSManagedObject {
	@NSManaged public var id               : UUID
	@NSManaged public var imageDescription : String?
	@NSManaged public var location         : String?
	@NSManaged public var url              : URL
}

@objc(FeedDTO)
public class FeedDTO: NSManagedObject {
	@NSManaged public var feed      : NSOrderedSet
	@NSManaged public var timestamp : Date
}

class CoreDataFeedStore : FeedStore {
	
	private let model : NSManagedObjectModel
	private let context : NSManagedObjectContext
	private let storeURL : URL
	
	private let modelName = "DataModel"
	private let imageEntityName = "LocalFeedImageDTO"
	private let feedEntityName = "FeedDTO"
	
	init(storeURL : URL, bundle: Bundle) {
		self.storeURL = storeURL
		
		self.model = NSManagedObjectModel.load(modelName: self.modelName,
											   bundle: bundle)
		
		self.context = NSPersistentContainer.loadBackgroundContext(modelName: self.modelName,
																   managedObjectModel: self.model,
																   storeURL: storeURL)
	}
	
	func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let deleteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: self.feedEntityName)
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetchRequest)
		_ = try? context.execute(deleteRequest)
		completion(nil)
	}
	
	func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		
		self.context.perform {
			let feedManagedObject = NSEntityDescription.insertNewObject(forEntityName: self.feedEntityName, into: self.context) as! FeedDTO
			var feedImagesManagedObject : [LocalFeedImageDTO] = []
			
			feed.forEach {
				let image = LocalFeedImageDTO(context: self.context)
				image.id = $0.id
				image.imageDescription = $0.description
				image.location = $0.location
				image.url = $0.url
				
				feedImagesManagedObject.append(image)
			}
			
			feedManagedObject.timestamp = timestamp
			feedManagedObject.feed = NSOrderedSet(array: feedImagesManagedObject)

			try? self.context.save()
			completion(nil)
		}
	}
	
	func retrieve(completion: @escaping RetrievalCompletion) {
		let fetchRequest  = NSFetchRequest<FeedDTO>(entityName: self.feedEntityName)
		guard let feed = try? context.fetch(fetchRequest) else {
			completion(.failure(NSError(domain: "any error", code: 0)));
			return
		}
		
		guard let latestFeed = feed.last else {
			completion(.empty)
			return
		}

		completion(.found(feed: DTOToLocal(DTO: latestFeed.feed), timestamp: latestFeed.timestamp))
	}
	
	private func DTOToLocal(DTO: NSOrderedSet) -> [LocalFeedImage] {
		return DTO.map {
			let image = $0 as! LocalFeedImageDTO
			return LocalFeedImage(id: image.id,
								  description: image.imageDescription,
								  location: image.location,
								  url: image.url)
		}
	}
}

extension NSManagedObjectModel {
	static func load(modelName: String, bundle: Bundle) -> NSManagedObjectModel {
		return bundle.url(forResource: modelName, withExtension: "momd").flatMap { NSManagedObjectModel(contentsOf: $0) }!
	}
}

extension NSPersistentContainer {
	static func loadBackgroundContext(modelName: String, managedObjectModel: NSManagedObjectModel, storeURL: URL) -> NSManagedObjectContext {
		let container = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
		container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
				
		container.loadPersistentStores { _,_ in }

		return container.newBackgroundContext()
	}
}

class FeedStoreChallengeTests: XCTestCase, FeedStoreSpecs {
	
	//  ***********************
	//
	//  Follow the TDD process:
	//
	//  1. Uncomment and run one test at a time (run tests with CMD+U).
	//  2. Do the minimum to make the test pass and commit.
	//  3. Refactor if needed and commit again.
	//
	//  Repeat this process until all tests are passing.
	//
	//  ***********************
	
	func test_retrieve_deliversEmptyOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveDeliversEmptyOnEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnEmptyCache(on: sut)
	}

	func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveDeliversFoundValuesOnNonEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_insert_overridesPreviouslyInsertedCacheValues() {
		let sut = makeSUT()

		assertThatInsertOverridesPreviouslyInsertedCacheValues(on: sut)
	}
	
	func test_delete_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_delete_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_delete_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_delete_emptiesPreviouslyInsertedCache() {
		let sut = makeSUT()

		assertThatDeleteEmptiesPreviouslyInsertedCache(on: sut)
	}
	
	func test_storeSideEffects_runSerially() {
		//		let sut = makeSUT()
		//
		//		assertThatSideEffectsRunSerially(on: sut)
	}
	
	// - MARK: Helpers
	
	private func makeSUT() -> FeedStore {
		let storeURL = URL(fileURLWithPath: "/dev/null")
		let bundle = Bundle(for: CoreDataFeedStore.self)
		let sut = CoreDataFeedStore(storeURL: storeURL, bundle: bundle)
		trackForMemoryLeaks(sut)
		return sut
	}
}

//  ***********************
//
//  Uncomment the following tests if your implementation has failable operations.
//
//  Otherwise, delete the commented out code!
//
//  ***********************

//extension FeedStoreChallengeTests: FailableRetrieveFeedStoreSpecs {
//
//	func test_retrieve_deliversFailureOnRetrievalError() {
////		let sut = makeSUT()
////
////		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
//	}
//
//	func test_retrieve_hasNoSideEffectsOnFailure() {
////		let sut = makeSUT()
////
////		assertThatRetrieveHasNoSideEffectsOnFailure(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableInsertFeedStoreSpecs {
//
//	func test_insert_deliversErrorOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertDeliversErrorOnInsertionError(on: sut)
//	}
//
//	func test_insert_hasNoSideEffectsOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertHasNoSideEffectsOnInsertionError(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableDeleteFeedStoreSpecs {
//
//	func test_delete_deliversErrorOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteDeliversErrorOnDeletionError(on: sut)
//	}
//
//	func test_delete_hasNoSideEffectsOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteHasNoSideEffectsOnDeletionError(on: sut)
//	}
//
//}
