//
//  CoreDataEntities.swift
//  FeedStoreChallenge
//
//  Created by Gustavo Arthur Vollbrecht on 10/01/21.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

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
