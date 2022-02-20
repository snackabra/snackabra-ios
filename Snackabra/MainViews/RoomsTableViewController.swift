//
//  RoomsTableViewController.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import UIKit
import CoreData

class RoomsTableViewController: UITableViewController {
    
    // MARK: - Vars
    
    let urlParams:[String:String] = [:];
    var allRooms:[NSManagedObject] = [];
    var filteredRooms:[NSManagedObject] = [];
    var container: NSPersistentContainer!
    let refreshController = UIRefreshControl();
    var lastMessageTime: [String: Double] = [:];
    var config: [String: String] = [:];
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        self.container = appDelegate.persistentContainer;
        if self.container == nil {
            fatalError("This view needs a persistent container.")
        }
        if let config = getConfig(container: self.container) {
            self.config = config;
        } else {
            showConfigError();
            return;
        }
        self.tableView.refreshControl = self.refreshController;
        self.refreshController.addTarget(self, action: #selector(reloadRooms), for: .valueChanged)
        let newRoomButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(showNewRoomAlert))
        newRoomButton.image = UIImage(systemName: "square.and.pencil");
        self.navigationItem.rightBarButtonItem = newRoomButton;
        tableView.tableFooterView = UIView();
        reloadRooms();
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextVC = segue.destination as? KeyImportController {
            nextVC.container = container
        } else if let nextVC = segue.destination as? KeyExportController {
            nextVC.container = container
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return allRooms.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! RoomTableViewCell

        // Configure the cell...
        cell.configure(room: allRooms[indexPath.row])
        return cell
    }
    
    // MARK: - TableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true);
        let room = allRooms[indexPath.row];
        goToRoom(room: room);
    }
    
    // MARK: - Get Rooms
    
    @objc private func reloadRooms () {
        allRooms = getCoreData(container: container, entityName: "Room", predicate: nil, sortDescriptors: [NSSortDescriptor(key: "lastMessageTS", ascending: false)]) ?? [];
        let roomList = allRooms.map({$0.value(forKey: "roomId") as! String})
        getLastMessageTimes(roomList: roomList) {
            // print("In completion")
            self.allRooms.sort {
                (self.lastMessageTime[$0.value(forKey: "roomId") as! String])! > (self.lastMessageTime[$1.value(forKey: "roomId") as! String])!;
            }
            // allRooms = self.realm.objects(Room.self).sorted(byKeyPath: "lastSeenMessageTS", ascending: false).map{$0};
            updateUI {
                self.tableView.reloadData()
                self.refreshController.endRefreshing()
            }
        }
    }
    
    func getLastMessageTimes(roomList: [String], completion: @escaping ()->()) {
        self.allRooms.forEach {
            self.lastMessageTime[$0.value(forKey: "roomId") as! String] = 0;
        }
        if let url = URL(string: "https://\(self.config["roomServer"]!)/api/v1/getLastMessageTimes"), let postBody = try? JSONSerialization.data(withJSONObject: roomList, options: []) {
            var postRequest = URLRequest(url: url)
            postRequest.httpMethod = "POST";
            postRequest.httpBody = postBody
            let task = URLSession.shared.dataTask(with: postRequest) {(requestData, response, error) in
                guard let requestData = requestData else {
                    // print("Could not fetch encryption data");
                    return
                }
                if let jsonString = String(data: requestData, encoding: .utf8), let json = JSONParse(jsonString: jsonString) {
                    // print("Received", jsonString)
                    for (key, val) in json {
                        if let lastMessageTSBinary = val as? String {
                            let lastMessageTS = Double(Int.init(lastMessageTSBinary, radix: 2) ?? 0)
                            self.lastMessageTime[key] = lastMessageTS;
                            if let _room = self.allRooms.first(where: {$0.value(forKey: "roomId") as! String == key}) {
                                // print(lastMessageTS, _room.value(forKey: "lastSeenMessageTS"))
                                _room.setValue(lastMessageTS > _room.value(forKey: "lastSeenMessageTS") as! Double, forKey: "unread")
                                putCoreData(container: self.container, entityName: "Room", args: ["lastMessageTS": lastMessageTS], mo: _room);
                            }
                        }
                    }
                    completion();
                }
            }
            task.resume();
        }
    }
    
    // MARK: - Navigation
    
    private func goToRoom(room: NSManagedObject){
        putCoreData(container: self.container, entityName: "Room", args: ["lastSeenMessageTS": Double(Date.now.timeIntervalSince1970)*1000, "unread": false], mo: room)
        let privateChatView = ChatViewController(roomId: room.value(forKey: "roomId") as! String, roomName: room.value(forKey: "roomName") as! String, username: room.value(forKey: "username") as? String ?? "", container: container);
        privateChatView.hidesBottomBarWhenPushed = true;
        navigationController?.pushViewController(privateChatView, animated: true)
    }
    
    func enterRoom(roomId: String) {
        if roomId.count != 64 {
            self.showInvalidRoomAlert(roomId: roomId);
            return;
        }
        var room : NSManagedObject!;
        room = self.allRooms.first(where: { _room in _room.value(forKey: "roomId") as! String == roomId });
        if room == nil {
            var args: [String: Any] = [:];
            args["roomId"] = roomId;
            args["roomName"] = "Room \(self.allRooms.count + 1)";
            if (try? retrieveKey(label: roomId)) != nil {
                args["keyLoaded"] = true;
            }
            putCoreData(container: container, entityName: "Room", args: args, mo: nil)
            room = getCoreData(container: container, entityName: "Room", predicate: NSPredicate(format: "roomId = %@", roomId), sortDescriptors: nil)![0];
        }
        if let keyLoaded = room.value(forKey: "keyLoaded") as? Bool, !keyLoaded {
            self.showFirstVisitAlert(room: room!)
        } else {
            self.goToRoom(room: room)
        }
    }
    
    // MARK: - Helpers
    
    func showFirstVisitAlert(room: NSManagedObject) {
        let ac = UIAlertController(title: nil, message: "Welcome! If this is the first time you've been to this room, enter your username for this room and press 'Ok' and we will generate fresh cryptographic keys that are unique to you and this room. If you have already been here, then you might want to load your keys from the backup - press 'Cancel' and go to the Settings tab to import your keys.", preferredStyle: .alert)
        ac.addTextField()
        ac.textFields![0].placeholder = "Enter username here"
        let saveAction = UIAlertAction(title: "Ok", style: .default) { [unowned ac] _ in
            if let username = ac.textFields![0].text {
                room.setValue(username, forKey: "username");
                putCoreData(container: self.container, entityName: "Room", args: ["username": username], mo: room)
                self.goToRoom(room: room)
            }
            updateUI {
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            updateUI {
                self.dismiss(animated: true, completion: nil)
            }
        }
        ac.addAction(saveAction);
        ac.addAction(cancelAction);
        updateUI {
            self.present(ac, animated: true);
        }
    }
    
    @objc func showNewRoomAlert() {
        let ac = UIAlertController(title: "Enter new room", message: "Paste/type in the 64 character room name below.", preferredStyle: .alert)
        ac.addTextField()
        let saveAction = UIAlertAction(title: "Enter Room", style: .default) { [unowned ac] _ in
            if let roomId = ac.textFields![0].text {
                updateUI {
                    self.dismiss(animated: true, completion: nil)
                };
                self.enterRoom(roomId: roomId)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            updateUI {
                self.dismiss(animated: true, completion: nil)
            }
        }
        ac.addAction(saveAction);
        ac.addAction(cancelAction);
        // ac.addAction(meAction)
        updateUI {
            self.present(ac, animated: true);
        }
    }
    
    func showInvalidRoomAlert(roomId: String) {
        let ac = UIAlertController(title: nil, message: "\(roomId) is an invalid roomId. Please enter the roomId again.", preferredStyle: .alert);
        let saveAction = UIAlertAction(title: "Ok", style: .default) { [unowned ac] _ in
            updateUI {
                self.dismiss(animated: true, completion: nil)
                self.showNewRoomAlert();
            }
        }
        ac.addAction(saveAction);
        updateUI {
            self.present(ac, animated: true);
        }
    }
    
    func showConfigError() {
        let ac = UIAlertController(title: nil, message: "There was an error loading your configurations. Please save your configurations in the Configuration Settings. You will not be able to chat until the configurations are set.", preferredStyle: .alert);
        let saveAction = UIAlertAction(title: "Ok", style: .default) { [unowned ac] _ in
            updateUI {
                self.dismiss(animated: true, completion: nil)
                // Navigate to settings tab
                self.tabBarController?.selectedIndex = 1
            }
        }
        ac.addAction(saveAction);
        updateUI {
            self.present(ac, animated: true);
        }
    }
}
