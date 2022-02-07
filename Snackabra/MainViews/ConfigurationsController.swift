//
//  ConfigurationsController.swift
//  Snackabra
//
//  Created by Yash on 2/2/22.
//

import Foundation
import UIKit
import CoreData

class ConfigurationsController: UITableViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var roomServerTextView: UITextField!
    @IBOutlet weak var storageServerTextView: UITextField!
    
    // MARK: - IBActions
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        self.updateServers();
    }
    
    var container: NSPersistentContainer!
    
    // MARK: - View Lifecycle
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
    
    func updateServers() {
        let roomServer = roomServerTextView.text ?? "";
        let storageServer = storageServerTextView.text ?? ""
        var user: NSManagedObject? = nil;
        if let fetchResults = getCoreData(container: container, entityName: "User", predicate: NSPredicate(format: "id = 1"), sortDescriptors: nil), fetchResults.count != 0{
                user = fetchResults[0];
        }
        let args: [String: Any] = ["id": 1, "roomServer": roomServer, "storageServer": storageServer];
        putCoreData(container: container, entityName: "User", args: args, mo: user)
    }
}
