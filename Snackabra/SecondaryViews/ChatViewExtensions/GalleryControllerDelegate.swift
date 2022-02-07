//
//  GalleryControllerDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/26/22.
//

import Foundation
import Gallery
import InputBarAccessoryView

extension ChatViewController : GalleryControllerDelegate {
    
    func galleryController(_ controller: GalleryController, didSelectImages images: [Image]) {
        
        controller.dismiss(animated: true, completion: nil)
        if images.count > 0 {
            images.first!.resolve { (image) in
                self.image = image!;
                let imageView = InputBarButtonItem()
                imageView.image = self.image;
                imageView.setSize(CGSize(width: 100, height: 100), animated: false)
                let cancelImage = InputBarButtonItem();
                cancelImage.image = UIImage(systemName: "xmark");
                cancelImage.setSize(CGSize(width: 50, height: 50), animated: false)
                cancelImage.onTouchUpInside { _ in
                    self.messageInputBar.setStackViewItems([], forStack: .top, animated: false);
                    self.image = nil;
                }
                self.messageInputBar.topStackView.alignment = .top;
                self.messageInputBar.topStackViewPadding.top = 0;
                self.messageInputBar.topStackView.axis = .horizontal
                self.messageInputBar.setStackViewItems([imageView, cancelImage], forStack: .top, animated: false);
            }
        }
        
    }
    
    func galleryController(_ controller: GalleryController, didSelectVideo video: Video) {
        // print("selected video")
        
        // self.messageSend(text: nil, photo: nil, video: video, audio: nil, location: nil)
        controller.dismiss(animated: true, completion: nil)
    }
    
    func galleryController(_ controller: GalleryController, requestLightbox images: [Image]) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func galleryControllerDidCancel(_ controller: GalleryController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
    
