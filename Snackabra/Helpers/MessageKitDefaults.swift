//
//  MessageKitDefaults.swift
//  Snackabra
//
//  Created by Yash on 1/13/22.
//

import Foundation
import UIKit
import MessageKit

struct MKSender: SenderType, Equatable {
    var senderId: String
    var displayName: String
    var isOwner: Bool
    var isVerifiedGuest: Bool
}

enum messageDefaults {
    // Bubble color
    static let bubbleColorOutgoing = UIColor(red: 0/255, green: 132/255, blue: 255/255, alpha: 1.0);
    static let bubbleColorIncoming = UIColor(red: 211/255, green: 211/255, blue: 211/255, alpha: 1.0)
}

enum messageStatusDefaults {
    static let verified = 1;
    static let whispered = 2;
    static let unverified = 3;
    static let system = 4;
}
