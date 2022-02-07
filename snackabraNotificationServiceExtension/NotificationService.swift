//
//  NotificationService.swift
//  snackabraNotificationServiceExtension
//
//  Created by Yash on 1/28/22.
//

import UserNotifications
import CoreData

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    lazy var persistentContainer: NSPersistentContainer = {
        let persistentContainer = NSPersistentContainer(name: "Snackabra");
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.privacy.snackabra") else {
            fatalError("Shared file container could not be created.")
        }

        let storeURL = fileContainer.appendingPathComponent("Snackabra.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return persistentContainer
    }()
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        var rooms : [NSManagedObject] = [];
        rooms = getCoreData(container: persistentContainer, entityName: "Room", predicate: nil) ?? []
        print("Initialized with \(rooms.count) rooms");
        
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            let roomId = bestAttemptContent.title;
            // print(roomId, rooms)
            let room = rooms.first(where: {$0.value(forKey: "roomId") as! String == roomId});
            print(room, room?.value(forKey: "roomName"))
            if let roomName = room?.value(forKey: "roomName") as? String, roomName.count > 0 {
                bestAttemptContent.title = roomName;
                bestAttemptContent.userInfo["roomId"] = roomId;
            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    
    func getCoreData(container: NSPersistentContainer, entityName: String, predicate: NSPredicate?) -> [NSManagedObject]? {
        let managedContext = container.viewContext
        let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        if predicate != nil {
            fetchRequest.predicate = predicate;
        }
        
        if let fetchResults = try? managedContext.fetch(fetchRequest) {
            return fetchResults
        }
        return nil;
    }
}
