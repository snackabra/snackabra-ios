//
//  WebsocketDelegate.swift
//  Snackabra
//
//  Created by Yash on 1/26/22.
//

import Foundation

extension ChatViewController: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Web Socket did connect");
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Code: ", closeCode.rawValue);
        print("Reason: ", String(data: reason!, encoding: .utf8))
        print("Web Socket disconnected. Will try to rejoin");
        self.setupWebsocket();
        self.joinRoom();
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("Invalid", error)
    }
}
