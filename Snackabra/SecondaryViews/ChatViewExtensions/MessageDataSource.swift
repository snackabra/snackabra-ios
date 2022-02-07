//
//  MessageDataSource.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import Foundation
import MessageKit
import UIKit

extension ChatViewController: MessagesDataSource {
    func currentSender() -> SenderType {
        return currentUser;
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return self.mkMessages[indexPath.section];
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return self.mkMessages.count;
    }
    
    // MARK: - Cell labels
    
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let dateString = MessageKitDateFormatter.shared.string(from: message.sentDate);
        return NSAttributedString(string: dateString, attributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.systemGray]);
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        return isFromCurrentSender(message: message) ? nil : NSAttributedString(string: message.sender.displayName, attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.systemGray]);
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        var borderColor: UIColor?;
        let mkMessage = mkMessages[indexPath.section];
        let status = mkMessage.status;
        if mkMessage.mkSender.isVerifiedGuest {
            borderColor = UIColor.purple;
        } else if mkMessage.mkSender.isOwner {
            borderColor = UIColor.green;
        }
        if  status == 3 {
            borderColor = UIColor.red;
        }
        if status == 4 {
            borderColor = UIColor.black;
        }
        return (borderColor != nil) ? .bubbleOutline(borderColor!) : .bubble;
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        avatarView.set(avatar: Avatar(initials: mkMessages[indexPath.section].senderInitials));
    }
}
