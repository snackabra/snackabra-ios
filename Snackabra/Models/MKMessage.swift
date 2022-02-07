//
//  MKMessage.swift
//  Snackabra
//
//  Created by Yash on 1/13/22.
//

import Foundation
import MessageKit
import UIKit

class MKMessage: NSObject, MessageType {
    
    var mkSender: MKSender
    var sender: SenderType { return mkSender }
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
    var incoming: Bool
    var senderInitials: String
    var status: Int
    var image: String
    var imageMetaData: [String: String]
    
    init(mid: String, messageSender: MKSender, messageStatus: Int, messageText: String, messageDate: Date, isReceiver: Bool, userInitials: String, image: String, imageMetadata: [String: String] ) {
        self.messageId = mid;
        self.mkSender = messageSender;
        self.status = messageStatus;
        self.senderInitials = userInitials;
        self.sentDate = messageDate;
        self.incoming = isReceiver;
        self.imageMetaData = imageMetadata;
        // self.kind = MessageKind.text(messageText);
        self.image = image;
        let attributedText = NSMutableAttributedString()
        if image != "" {
            if let imageData = Data(base64Encoded: image){
                let image = UIImage(data: imageData);
                let imgAttachment = NSTextAttachment()
                imgAttachment.image = image;
                // imgAttachment.bounds = Put constraints here
                let imgString = NSAttributedString(attachment: imgAttachment)
                attributedText.append(imgString);
                if messageText != ""{
                    attributedText.append(NSAttributedString(string: "\n\n\n"))
                }
            }
        }
        var fontColor = UIColor.label;
        if (isReceiver && (messageStatus != messageStatusDefaults.whispered)) {
            fontColor = UIColor.white;
        } else if messageStatus == messageStatusDefaults.whispered {
            fontColor = UIColor.black
        }
        var font = UIFont.systemFont(ofSize: 16.0)
        if(messageStatus == messageStatusDefaults.system || messageStatus == messageStatusDefaults.whispered) {
            font = UIFont.italicSystemFont(ofSize: 16)
        }
        attributedText.append(NSAttributedString(string: messageText, attributes: [.font: font, .foregroundColor: fontColor]))
        self.kind = .attributedText(attributedText);
    }
    
}
