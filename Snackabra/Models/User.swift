//
//  User.swift
//  Snackabra
//
//  Created by Yash on 1/6/22.
//

import Foundation
import RealmSwift

class User: Object {
    @objc var id = 1;
    @objc var contacts : String = JSONStringify(jsonObject: [:])!;
    override static func primaryKey() -> String? {
        return "id"
    }
}
