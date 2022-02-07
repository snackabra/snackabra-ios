//
//  MessageCellDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import Foundation
import MessageKit
import SKPhotoBrowser

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell){
            let message = self.mkMessages[indexPath.section];
            let metadata = message.imageMetaData;
            if let dataId = metadata["previewId"], let controlMessage = self.controlMessages.first(where: {$0["id"]?.starts(with: dataId) as? Bool ?? false }){
                self.showLoadingScreen(message: "Loading image...");
                retrieveData(metadata: metadata, controlMessage: controlMessage) { data in
                    print(data);
                    if let imageData = data, let image = UIImage(data: imageData){
                        var images = [SKPhoto]();
                        let photo = SKPhoto.photoWithImage(image)
                        images.append(photo);
                        DispatchQueue.main.async {
                            let browser = SKPhotoBrowser(photos: images);
                            browser.initializePageIndex(0);
                            self.dismiss(animated: true){
                                self.present(browser, animated: true, completion: nil);
                            }
                        }
                    }
                };
                self.dismiss(animated: true, completion: nil)
            } else {
                print("Error: Could not find control message or id is nil")
            }
        }
    }
    
    func didTapAvatar(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell){
            let message = self.mkMessages[indexPath.section];
            let userKey = message.mkSender.senderId;
            let currentUsername = self.contacts[userKey] ?? ""
            let ac = UIAlertController(title: "Change Username", message: "If it is you, type in 'Me' in the input and press Save.", preferredStyle: .alert)
            ac.addTextField() {
                textField in
                textField.text = currentUsername;
            }
            let saveAction = UIAlertAction(title: "Save", style: .default) { [unowned ac] _ in
                if let newUsername = ac.textFields![0].text {
                    self.saveUsername(userKey: userKey, new: newUsername)
                }
                updateUI {
                    self.dismiss(animated: true, completion: nil)
                }
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                updateUI {
                    self.dismiss(animated: true, completion: nil)
                }
            }
            /*
            let meAction = UIAlertAction(title: "Me", style: .default) {  _ in
                let newUsername = "Me"
                self.saveUsername(current: currentUsername, new: newUsername)
                
                updateUI {
                    self.dismiss(animated: true, completion: nil)
                }
            }
             */
            ac.addAction(saveAction);
            ac.addAction(cancelAction);
            // ac.addAction(meAction)
            updateUI {
                self.present(ac, animated: true) {
                    ac.textFields?[0].selectAll(nil);
                }
            }
        }
    }
    
}
