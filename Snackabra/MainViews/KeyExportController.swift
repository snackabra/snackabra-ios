//
//  KeyExportController.swift
//  Snackabra
//
//  Created by Yash on 1/30/22.
//

import UIKit
import CryptoKit
import Security
import Foundation
import CoreData

class KeyExportController: UITableViewController {
    
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
        self.prepareKeyExport();
    }
    
    //MARK: - IBOutlets
    
    @IBOutlet weak var keyExportTextView: UITextView!
    
    @IBOutlet weak var filenameTextView: UITextField!
    
    //MARK: - IBActions
    @IBAction func downloadKeysPressed(_ sender: Any) {
        let filename = (self.filenameTextView.text ?? "SnackabraData") + ".txt";
        let filepath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename);
        do{
            try self.keyExportTextView.text.write(to: filepath, atomically: true, encoding: String.Encoding.utf8);
            // exportFile(filepath: filepath, view: self.view)
            let avc = UIActivityViewController(activityItems: [filepath], applicationActivities: nil)
            updateUI {
                self.present(avc, animated: true)
            }
        } catch {
            print("Error writing data", error);
        }
    }
    
    func prepareKeyExport() {
        let allRooms = getCoreData(container: self.container, entityName: "Room", predicate: nil, sortDescriptors: nil);
        var exportData : [String: Any] = [:];
        let users = getCoreData(container: self.container, entityName: "User", predicate: NSPredicate(format: "id = 1"), sortDescriptors: nil);
        var user : NSManagedObject?
        if users?.count == 1 {
            user = users?[0];
        }
        if let contacts = user?.value(forKey: "contacts") as? String {
            exportData["contacts"] = JSONParse(jsonString: contacts);
        }
        var allRoomsMetaData: [String: [String: Any]] = [:]
        var allRoomsData: [String: [String: Any]] = [:]
        allRooms?.forEach {
            let room = $0;
            let roomId = room.value(forKey: "roomId") as! String;
            var roomMetadata: [String: Any] = [:];
            var roomData: [String: String] = [:];
            roomMetadata["name"] = room.value(forKey: "roomName") as? String;
            roomMetadata["lastMessageTime"] = String(room.value(forKey: "lastMessageTS") as! Int * 1000, radix: 2);
            roomMetadata["username"] = room.value(forKey: "username") as? String;
            roomMetadata["unread"] = room.value(forKey: "unread") as? Bool;
            allRoomsMetaData[roomId] = roomMetadata;
            roomData["lastSeenMessage"] = String(room.value(forKey: "lastSeenMessageTS") as! Int * 1000, radix: 2);
            if let keyLoaded = room.value(forKey: "keyLoaded") as? Bool, keyLoaded, let secKey = try? retrieveKey(label: roomId), let privateKey = try? convertSecKeyToCryptoKit(secKey: secKey) {
                roomData["key"] = privateKey.pemRepresentation;
            }
            allRoomsData[roomId] = roomData;
        }
        exportData["roomData"] = allRoomsData;
        exportData["roomMetadata"] = allRoomsMetaData;
        exportData["pem"] = true;
        var keyString = JSONStringify(jsonObject: exportData) ?? "Could not export data";
        keyString = keyString.replacingOccurrences(of: "\n", with: "");
        self.keyExportTextView.text = keyString;
    }
}
