//
//  Room.swift
//  Snackabra
//
//  Created by Yash on 1/28/22.
//

import Foundation
import RealmSwift

class Room: Object {
    @objc var roomId: String = "";
    @objc var roomName: String = "";
    @objc var lastSeenMessageTS: Int = 0;
    @objc var unread: Bool = false;
    @objc var keyLoaded: Bool = false;
    @objc var username: String = ""
    override static func primaryKey() -> String? {
            return "roomId"
        }
}
