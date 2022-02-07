//
//  RoomSettingsViewController.swift
//  Snackabra
//
//  Created by Yash on 1/27/22.
//

import UIKit
import CoreData

class RoomSettingsViewController: UIViewController {

    
    // MARK: - IBOutlets
    
    @IBOutlet weak var motdLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var roomNameTextField: UITextField!
    
    // MARK: - Vars
    
    var roomId: String!;
    var username: String!;
    var motd: String!;
    var roomName: String!;
    var container: NSPersistentContainer!
    
    // MARK: - IBActions
    
    @IBAction func saveButtonPressed(_ sender: Any) {
        let loader = loader(message: "Updating room...");
        updateUI {
            self.present(loader, animated: true);
        }
        let username = usernameTextField.text!;
        let roomName = roomNameTextField.text!;
        updateRoom(args: ["username": username, "roomName": roomName]);
        stopLoader(loader: loader);
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        self.usernameTextField.text = self.username;
        self.roomNameTextField.text = self.roomName;
        if self.motd != "" {
            self.motdLabel.text = "Message of the day: \(self.motd!)";
        }
        // Do any additional setup after loading the view.
    }
    
    
    // MARK: - Settings functions
    
    func updateRoom(args: [String: Any]) {
        print("Updating room");
        var room: NSManagedObject? = nil;
        if let res = getCoreData(container: container, entityName: "Room", predicate: NSPredicate(format: "roomId = %@", self.roomId), sortDescriptors: nil), res.count>0 {
            print("Found room");
            room = res[0];
            putCoreData(container: container, entityName: "Room", args: args, mo: room)
        }
        if let navController = self.navigationController, navController.viewControllers.count >= 2, let viewController = navController.viewControllers[navController.viewControllers.count - 2] as? ChatViewController {
            viewController.roomName = args["roomName"] as? String ?? viewController.roomName;
            viewController.currentUser.displayName = args["username"] as? String ?? viewController.currentUser.displayName;
            viewController.configureNavigationBar();
            self.navigationController?.popViewController(animated: true)
        }
    }

}
