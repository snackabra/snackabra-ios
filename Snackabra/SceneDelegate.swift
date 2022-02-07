//
//  SceneDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/5/22.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        // Get URL components from the incoming user activity.
        guard let userActivity = connectionOptions.userActivities.first,
              let path = getPath(userActivity: userActivity) else { return }

        print("path = \(path)", path.split(separator: "/"))
        let roomId = String(path.split(separator: "/")[1]);
        handleURL(path: roomId)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let _ = (scene as? UIWindowScene) else { return }
        // Get URL components from the incoming user activity.
        guard let path = getPath(userActivity: userActivity) else { return }
        print("path = \(path)", path.split(separator: "/"))
        let roomId = String(path.split(separator: "/")[0]);
        handleURL(path: roomId)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    // URL of the format app.snackabra://main/<roomId> will open the chat room for that roomId
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            if context.url.pathComponents.count > 1 {
                let roomId = context.url.pathComponents[1] as String;
                handleURL(path: roomId)
            }
        }
    }
    
    func handleURL(path: String) {
        guard let tabBarController = window?.rootViewController as? UITabBarController else {
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
        if path.count == 64 {
            roomsTableViewController.enterRoom(roomId: path)
        }
    }
    
    func getPath(userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL,
              let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else {
                  return nil;
              }
        print(components);
        // Check for specific URL components that you need.
        guard let path = components.path else {
            return nil;
        }
        return path;
    }
}
