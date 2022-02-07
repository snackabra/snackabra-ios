//
//  InputBarAccessoryViewDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import Foundation
import InputBarAccessoryView

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        var text: String? = nil;
        for component in inputBar.inputTextView.components {
            text = component as? String;
        }
        if text != nil || self.image != nil {
            self.sendMessage(text: text ?? "", whispered: false, whisperKey: nil, recipient: nil);
            messageInputBar.inputTextView.text="";
            messageInputBar.invalidatePlugins();
            self.messageInputBar.setStackViewItems([], forStack: .top, animated: false);
            self.image = nil;
        }
    }
}
