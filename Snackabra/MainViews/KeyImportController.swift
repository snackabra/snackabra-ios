//
//  KeyImportExportController.swift
//  Snackabra
//
//  Created by Yash on 1/6/22.
//

import UIKit
import CryptoKit
import Security
import Foundation
import CoreData

//MARK: - Update Core Data

func updateRooms(jsonData: NSDictionary, container: NSPersistentContainer) {
    if let roomMetaData = jsonData["roomMetadata"] as? [String: [String: Any]]{
        let roomData = jsonData["roomData"] as? [String : [String : String]] ?? [:];
        print(roomMetaData)
        for (key, val) in roomMetaData {
            
            var args: [String: Any] = [:];
            var room: NSManagedObject? = nil;
            if let fetchResults = getCoreData(container: container, entityName: "Room", predicate: NSPredicate(format: "roomId = %@", key), sortDescriptors: nil) {
                if fetchResults.count != 0{
                    room = fetchResults[0];
                }
            }
            var allRooms: [NSManagedObject] = [];
            if let fetchResults = getCoreData(container: container, entityName: "Room", predicate: nil, sortDescriptors: nil) {
                allRooms = fetchResults;
            }
            args["roomId"] = key;
            args["roomName"] = val["name"] as? String ?? "Room" + String(format:"%03d", allRooms.count+1);
            args["unread"] = val["unread"] as? Bool ?? false;
            args["lastSeenMessageTS"] = Double(Int.init(val["lastSeenMessage"] as? String ?? "0", radix: 2) ?? 0);
            args["lastMessageTS"] = Double(Int.init(val["lastMessageTime"] as? String ?? "0", radix: 2) ?? 0);
            args["username"] = val["username"] as? String ?? "";
            if let roomData = jsonData["roomData"] as? [String : [String : String]] {
                args["keyLoaded"] = roomData[key] != nil;
            }
            putCoreData(container: container, entityName: "Room", args: args, mo: room);
            
            /* REALM
             do{
             print(val)
             let _room = Room();
             _room.roomId = key;
             _room.unread = val["unread"] as? Bool ?? false;
             _room.lastSeenMessageTS = Int(val["lastMessageTime"] as? String ?? "0", radix: 2)!;
             _room.roomName = val["name"] as? String ?? "Room" + String(format:"%03d", realm.objects(Room.self).count+1);
             _room.username = val["username"] as? String ?? ""
             if let roomData = jsonData["roomData"] as? [String : [String : String]] {
             _room.keyLoaded = roomData[key] != nil;
             }
             try realm.write{
             realm.add(_room, update: .modified);
             }
             } catch {
             print("Write failed for \(key)")
             }
             */
        }
    }
    else{
        print("Failed to update rooms")
    }
}

func updateContacts(contacts: [String: String], container: NSPersistentContainer) {
    
    var user: NSManagedObject? = nil;
    var savedContacts: [String: String] = [:]
    if let fetchResults = getCoreData(container: container, entityName: "User", predicate: NSPredicate(format: "id = 1"), sortDescriptors: nil) {
        if fetchResults.count != 0{
            user = fetchResults[0];
            if let contactString = user?.value(forKey: "contacts") as? String{
                savedContacts = JSONParse(jsonString: contactString) as? [String: String] ?? [:]
            }
        }
    }
    savedContacts.merge(contacts) {(_, new) in new};
    let newContactsString = JSONStringify(jsonObject: savedContacts);
    let args: [String: Any] = ["id": 1, "contacts": newContactsString ?? ""];
    putCoreData(container: container, entityName: "User", args: args, mo: user)
}


//MARK: - Helper functions

func parseJSON (jsonText:String) -> NSDictionary {
    var dictionary:NSDictionary?
    
    if let data = jsonText.data(using: String.Encoding.utf8) {
        
        do {
            dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject] as NSDictionary?
            
        } catch let error as NSError {
            print(error)
        }
    }
    return dictionary ?? ["error": "Error parsing json"];
}

class KeyImportController: UITableViewController {
    
    var container: NSPersistentContainer!
    // let realm = try! Realm(configuration: realmConstants.realmConfig)
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.container = appDelegate.persistentContainer;
        if self.container == nil {
            fatalError("This view needs a persistent container.")
        }
        self.tableView.tableHeaderView = nil;
        self.tableView.tableFooterView = nil;
    }
    
    //MARK: - IBOutlets
    
    //textViews
    @IBOutlet weak var keyImportTextView: UITextView!
    
    //MARK: - IBActions
    
    @IBAction func selectFilePressed(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText]);
        documentPicker.delegate = self;
        present(documentPicker, animated: true, completion: nil)
        print("Select file pressed")
    }
    
    @IBAction func uploadKeysPressed(_ sender: Any) {
        if let text = keyImportTextView.text {
            let jsonData = parseJSON(jsonText: text);
            importKeysToKeychain(jsonData: jsonData);
            updateRooms(jsonData: jsonData, container: container);
            if let contacts = jsonData["contacts"] as? [String: String] {
                updateContacts(contacts: contacts, container: container);
            }
            print("Key upload complete");
        }
    }
}

extension KeyImportController : UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let url = urls[0];
        print(urls)
        guard url.startAccessingSecurityScopedResource() else {
            // Handle the failure here.
            return
        }
        
        // Make sure you release the security-scoped resource when you finish.
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Use file coordination for reading and writing any of the URL’s content.
        var error: NSError? = nil
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { url in
            if let str = try? String(contentsOfFile: url.path) {
                self.keyImportTextView.text = str;
            } else {
                print("Failed reading");
            }
        }
    }
    
}
