//
//  AppDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/5/22.
//

import UIKit
import UserNotifications
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        registerForPushNotifications()
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        // print("Device Token: \(token)")
        registerDevice(token: token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    func registerForPushNotifications() {
        
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                    print("Permission granted: \(granted)")
                    guard granted else { return }
                    self?.getNotificationSettings()
                }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func registerDevice(token: String) {
        print(token);
        let allRoomObjects = getCoreData(container: persistentContainer, entityName: "Room", predicate: nil, sortDescriptors: nil) ?? [];
        var allRooms : [String] = [];
        for room in allRoomObjects {
            allRooms.append(room.value(forKey: "roomId") as! String);
        }
        for room in allRooms {
            if let url = URL(string: "https://s_socket.privacy.app/api/room/\(room)/registerDevice?id=\(token)") {
                var request = URLRequest(url: url)
                request.httpMethod = "GET";
                // print("sending \(postBody.count) bytes")
                let task = URLSession.shared.dataTask(with: request) { (finalData, finalResponse, finalError) in
                    guard let finalData = finalData else {
                        print("could not get final data");
                        return
                    }
                    let finalRespString = String(data: finalData, encoding: .utf8);
                    // print(finalRespString)
                    let finalJson = JSONParse(jsonString: finalRespString!);
                    // print("Response: \(finalJson)")
                }
                task.resume();
            }
        }
    }
    
}

extension AppDelegate: UNUserNotificationCenterDelegate{
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        guard let rootViewController = (UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate)?.window?.rootViewController else {
            return
        }
        guard let tabBarController = rootViewController as? UITabBarController else {
            return
        }
        guard let navigationControllers = tabBarController.viewControllers,
              let listIndex = navigationControllers.firstIndex(where: {
                  if let controller = $0 as? UINavigationController, controller.visibleViewController is RoomsTableViewController {
                      return true;
                  }
                  return false;
              }),
              let selectedNavigationController = navigationControllers[listIndex] as? UINavigationController, let roomsTableViewController = selectedNavigationController.visibleViewController as? RoomsTableViewController else { return }
        if let roomId = response.notification.request.content.userInfo["roomId"] as? String {
            roomsTableViewController.enterRoom(roomId: roomId)
        }
        print("\(response.notification.request.content.userInfo)")
        completionHandler();
    }
}
