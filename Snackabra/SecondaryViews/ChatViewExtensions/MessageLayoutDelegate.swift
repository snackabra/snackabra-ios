//
//  MessageLayoutDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import Foundation
import MessageKit
import UIKit

extension ChatViewController: MessagesLayoutDelegate {
    
    // MARK: - Message Bottom label
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 18;
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return isFromCurrentSender(message: message) ? 0 : 20;
    }
}
