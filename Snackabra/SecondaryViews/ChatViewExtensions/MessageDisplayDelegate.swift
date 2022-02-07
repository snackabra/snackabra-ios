//
//  MessageDisplayDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import Foundation
import MessageKit
import UIKit

extension ChatViewController: MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let mkMessage = mkMessages[indexPath.section];
        if mkMessage.status == messageStatusDefaults.whispered {
            return UIColor(red: 255/255, green: 255/255, blue: 0/255, alpha: 1);
        }
        return isFromCurrentSender(message: message) ? UIColor.systemBlue : UIColor.systemGray6;
    }
}
