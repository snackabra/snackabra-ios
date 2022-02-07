//
//  ChatViewController.swift
//  Snackabra
//
//  Created by Yash on 1/12/22.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Gallery
import CryptoKit
import Photos
import CoreData

class ChatViewController: MessagesViewController {
    
    // MARK: - Vars
    
    private var roomId = ""
    var roomName = ""
    private var isOwner = false;
    private var isVerifiedGuest = false;
    private var keys: [String: Any] = [:];
    private var websocket: URLSessionWebSocketTask?;
    private var urlSession: URLSession?;
    private var locked = false;
    private var jwkPubKeyString = "";
    private var jwkPubKey: [String: Any] = [:];
    private var userKey = "";
    private var ownerJWK: [String: Any] = [:];
    private var guestJWK: [String: Any] = [:];
    private var motd: String = "";
    private var restricted: Bool = false;
    var config: [String: String] = [:];
    var image: UIImage!;
    // let realm = try! Realm(configuration: realmConstants.realmConfig);
    var container: NSPersistentContainer!
    var contacts : [String: String] = [:];
    // private var userId: String;
    // private var displayName: String;
    var currentUser: MKSender = MKSender(senderId: "", displayName: "", isOwner: false, isVerifiedGuest: false);
    let refreshController = UIRefreshControl()
    var mkMessages: [MKMessage] = [];
    var moreMessages: Bool = true;
    var controlMessages: [[String: String]] = [];
    var gallery: GalleryController!
    
    // MARK: - Initializers
    
    init(roomId:String, roomName: String, username: String, container: NSPersistentContainer){
        super.init(nibName: nil, bundle: nil)
        self.roomId = roomId;
        self.roomName = roomName;
        self.currentUser.displayName = username;
        self.container = container;
        setupWebsocket();
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad();
        
        configureNavigationBar();
        configureMessageCollectionView();
        configureMessageInputBar();
        // Do any additional setup after loading the view.
        
        if let config = getConfig(container: self.container) {
            self.config = config;
        } else {
            showConfigError();
        }
        importPersonalKeys();
        loadContacts();
        joinRoom();
    }
    
    // MARK: - Configurations
    
    func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never;
        // self.title = self.roomName;
        let titleButton = UIButton(type: .custom);
        
        titleButton.setTitleColor(UIColor.label, for: .normal)
        titleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        titleButton.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        titleButton.setTitle(self.roomName, for: .normal);
        titleButton.addTarget(self, action: #selector(showRoomSettings), for: .touchUpInside)
        titleButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        titleButton.semanticContentAttribute = .forceRightToLeft;
        self.navigationItem.titleView = titleButton;
        self.navigationItem.backButtonTitle = "";
        let whisperButton = UIBarButtonItem(image: UIImage(systemName: "person"), style: .plain, target: self, action: #selector(showWhisper));
        self.navigationItem.rightBarButtonItem = whisperButton
    }
    private func configureMessageCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messageCellDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messagesLayoutDelegate = self
        
        maintainPositionOnKeyboardFrameChanged = true
        messagesCollectionView.refreshControl = refreshController
    }
    
    private func configureMessageInputBar() {
        
        messageInputBar.delegate = self;
        let attachButton = InputBarButtonItem()
        attachButton.image = UIImage(systemName: "plus")
        
        attachButton.setSize(CGSize(width: 30, height: 30), animated: false)
        
        attachButton.onTouchUpInside {
            item in
            self.showActionSheet();
        }
        
        messageInputBar.setStackViewItems([attachButton], forStack: .left, animated: false)
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.sendButton.isEnabled = true;
        messageInputBar.inputTextView.isImagePasteEnabled = false;
        messageInputBar.backgroundView.backgroundColor = .systemBackground
        messageInputBar.inputTextView.backgroundColor = .systemBackground
    }
    
    // MARK: - Room initializers
    
    private func initializeRoom(data: [String: Any]) {
        if let keys = data["keys"] as? [String: String] {
            importRoomKeys(keys: keys);
            if let ready_msg_str = JSONStringify(jsonObject: ["ready": true]){
                self.websocket!.send(URLSessionWebSocketTask.Message.string(ready_msg_str), completionHandler: {
                    [weak self] (err) in guard self != nil else {
                        print(err);
                        return
                    }
                })
            } else {
                print("Could not send ready message")
            }
            // print(keys)
        } else {
            print(data)
            print("Could not convert keys to string:string");
        }
        if let motd = data["motd"] as? String, self.motd != motd {
            self.motd = motd;
            if motd != "" {
                self.sendSystemMessage(text: motd);
            }
        }
        if let locked = data["roomLocked"] as? Bool {
            self.restricted = locked;
        }
    }
    
    func loadContacts() {
        if let res = getCoreData(container: container, entityName: "User", predicate: nil, sortDescriptors: nil), res.count>0 {
            let _user = res[0]
            if let contactString = _user.value(forKey: "contacts") as? String, let _saved_contacts = JSONParse(jsonString: contactString) as? [String: String]{
                self.contacts = _saved_contacts;
            }
        }
    }
    
    // MARK: - Key retrieval and loading
    
    private func importPersonalKeys(){
        do{
            var privateKey: P384.KeyAgreement.PrivateKey;
            if let secKey = try retrieveKey(label: self.roomId) {
                privateKey = try convertSecKeyToCryptoKit(secKey: secKey)
            } else {
                print("Creating new keys");
                privateKey = P384.KeyAgreement.PrivateKey(compactRepresentable: false);
                try storeKey(privateKey, label: self.roomId)
            }
            self.keys["privateKey"] = privateKey;
            self.keys["publicKey"] = privateKey.publicKey;
            let jwkPub = getJWKKey(key: privateKey.publicKey);
            self.jwkPubKey = jwkPub;
            self.jwkPubKeyString = JSONStringify(jsonObject: jwkPub)!;
            self.userKey = (jwkPub["x"] as? String ?? "") + " " + (jwkPub["y"] as? String ?? "")
            self.currentUser.senderId = userKey;
        } catch {
            print("Failed to import personal key")
        }
    }
    
    private func importRoomKeys(keys: [String: String]){
        for (keyType, keyValue) in keys {
            do{
                switch keyType{
                case "encryptionKey":
                    if let data = Data(base64Encoded: keyValue) {
                        self.keys["encryptionKey"] = SymmetricKey.init(data: data)
                    } else {
                        print("Could not decode")
                    }
                case "signKey":
                    let signKey = try P384.KeyAgreement.PrivateKey.init(pemRepresentation: keyValue)
                    self.keys["signKey"] = signKey;
                    if let pubKey = self.keys["publicKey"] as? P384.KeyAgreement.PublicKey{
                        self.keys["personal_signKey"] = deriveKey(privateKey: signKey, publicKey: pubKey);
                    }
                
                default:
                    self.keys[keyType] = try P384.KeyAgreement.PublicKey.init(pemRepresentation: keyValue)
                    
                }
                if let ownerKey = self.keys["ownerKey"] as? P384.KeyAgreement.PublicKey{
                    self.ownerJWK = getJWKKey(key: ownerKey);
                    if let pubKey = self.keys["publicKey"] as? P384.KeyAgreement.PublicKey{
                        self.isOwner = ownerKey.rawRepresentation == pubKey.rawRepresentation;
                        if let guestKey = self.keys["guestKey"] as? P384.KeyAgreement.PublicKey {
                            self.guestJWK = getJWKKey(key: guestKey);
                            self.isVerifiedGuest = pubKey.rawRepresentation == guestKey.rawRepresentation;
                        }
                        if let privateKey = self.keys["privateKey"] as? P384.KeyAgreement.PrivateKey{
                            self.keys["sharedKey"] = deriveKey(privateKey: privateKey, publicKey: ownerKey);
                        }
                    }
                }
                if let locked_key_encrypted = keys["locked_key"], let locked_key_obj = JSONParse(jsonString: locked_key_encrypted) as? [String: String], let shared_key = self.keys["sharedKey"] as? SymmetricKey, let decryptedObj = try? decrypt(contents: locked_key_obj, key: shared_key), let err = decryptedObj["error"] as? Bool, !err, let exportable_locked_key = JSONParse(jsonString: decryptedObj["plaintext"] as? String ?? ""), let k = exportable_locked_key["k"] as? String{
                    let b64k = base64urlToBase64(base64url: k);
                    if let keyData = Data(base64Encoded: b64k){
                        self.keys["lockedKey"] = SymmetricKey(data: keyData);
                    }
                }
            } catch {
                print("Could not import \(keyType) with value \(keyValue)");
                continue;
            }
        }
    }
    
    // MARK: - Websocket functions
    
    func setupWebsocket() {
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        self.websocket = self.urlSession?.webSocketTask(with: URL(string: "wss://\(self.config["roomServer"])/api/room/\(roomId)/websocket")!);
    }
    
    func joinRoom() {
        let webSocketTask = self.websocket!;
        webSocketTask.resume();
        if let keyMessage = JSONStringify(jsonObject: ["name": self.jwkPubKeyString, "pem": true]) as String? {
            webSocketTask.send(URLSessionWebSocketTask.Message.string(keyMessage), completionHandler: {
                [weak self] (err) in guard self != nil else {
                    print("In join room", err)
                    return
                }
            })
            self.webSocketListener();
        } else {
            print("Could not create ready message string")
        }
    }
    
    private func webSocketListener(){
        self.websocket!.receive(completionHandler: {
            [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .failure(let error as NSError):
                print(error);
                let reloadAlert = loader(message: "Lost connection to the room. Trying to reconnect...");
                updateUI {
                    self.present(reloadAlert, animated: true);
                }
                self.setupWebsocket();
                self.joinRoom();
                stopLoader(loader: reloadAlert)
                return;
            case .success(let message):
                // 4
                switch message {
                case .data(let data):
                    print("Data \(data)")
                case .string(let str):
                    if let jsonData = JSONParse(jsonString: str){
                        if let ready = jsonData["ready"] as? Bool {
                            if ready{
                                self.initializeRoom(data: jsonData)
                            }
                        }
                        else{
                            let messages = self.unwrapMessages(data: jsonData);
                            self.addChatMessages(receivedMessages: messages, oldMessages: false)
                        }
                    }
                @unknown default:
                    break
                }
            }
            self.webSocketListener()
        })
    }
    
    // MARK: - Message handlers
    
    private func unwrapMessages(data: [String: Any]) -> [String: [String: Any]]{
        // print(data);
        var _messages: [String: [String:Any]] = [:];
        for (messageId, value) in data {
            if let encryptedContents = value as? [String: Any]{
                if let contents = encryptedContents["encrypted_contents"] as? [String:String]{
                    if let encryptionKey = self.keys["encryptionKey"] as? SymmetricKey, let decryptResult = try? decrypt(contents: contents, key: encryptionKey), let decryptError = decryptResult["error"] as? Bool, !decryptError, let decryptedString = decryptResult["plaintext"] as? String , var decrypted = JSONParse(jsonString: decryptedString){
                        if let control = decrypted["control"] as? Bool, control {
                            decrypted.removeValue(forKey: "control")
                            if let controlMsg = decrypted as? [String: String]{
                                self.controlMessages.append(controlMsg)
                            }
                        } else {
                            _messages[messageId] = decrypted;
                        }
                    }
                } else {
                    // print("FAILED", value)
                }
            }
        }
        return _messages;
    }
    
    private func wrapMessages(contents:[String: Any]) -> [String: Any] {
        var encKey: SymmetricKey? = nil;
        let errorMessage = ["error": "Could not send message. The encryption key seems to be corrupted"];
        if self.locked {
            if let _lockedKey = self.keys["lockedKey"] as? SymmetricKey {
                encKey = _lockedKey;
            }
        } else if contents["encrypted"] as? Bool ?? true || !self.locked {
            if let encryptionKey = self.keys["encryptionKey"] as? SymmetricKey {
                encKey = encryptionKey;
            }
        }
        
        if encKey == nil {
            return errorMessage;
        }
        if let jsonString = JSONStringify(jsonObject: contents){
            let encryptedDict = encrypt(contents: Data(jsonString.utf8), key: encKey!, _iv: nil);
            return ["encrypted_contents": encryptedDict];
        }
        return errorMessage;
    }
    
    func sendSystemMessage(text: String){
        let systemMessage = MKMessage(mid: String(self.mkMessages.count+1), messageSender: MKSender(senderId: "system", displayName: "System Message", isOwner: false, isVerifiedGuest: false), messageStatus: messageStatusDefaults.system, messageText: text, messageDate: Date.now, isReceiver: false, userInitials: "SM", image: "", imageMetadata: [:])
        self.mkMessages.append(systemMessage)
    }
    
    private func addChatMessages(receivedMessages: [String: [String: Any]], oldMessages: Bool = false) {
        var messages: [MKMessage] = [];
        var _text_verified = true;
        var _image_verified = true;
        var _imageMetadata_verified = true;
        for (messageId, message) in receivedMessages {
            var messageStatus = messageStatusDefaults.verified;
            var messageText: String = "";
            if let sender_pubKey = message["sender_pubKey"] as? [String: Any], let senderCryptoKey = importJWKECPublic(key: sender_pubKey), let privateKey = self.keys["privateKey"] as? P384.KeyAgreement.PrivateKey {
                if let whispered = message["encrypted"] as? Bool, whispered {
                    messageStatus = messageStatusDefaults.whispered;
                    var sharedKey = self.keys["sharedKey"] as? SymmetricKey;
                    if(!areJWKKeysSame(key1: self.jwkPubKey, key2: sender_pubKey)){
                        sharedKey = deriveKey(privateKey: privateKey, publicKey: senderCryptoKey) as? SymmetricKey
                    }
                    if self.isOwner, let recipient = message["recipient"] as? [String: Any], let recipientCryptoKey = importJWKECPublic(key: recipient) {
                        sharedKey = deriveKey(privateKey: privateKey, publicKey: recipientCryptoKey) as? SymmetricKey
                    }
                    if let decryptionKey = sharedKey {
                        if let encrypted_contents = message["contents"] as? [String: String], let decrypted_contents = try? decrypt(contents: encrypted_contents, key: decryptionKey), let plaintext = decrypted_contents["plaintext"] as? String {
                            messageText = plaintext;
                        } else {
                            messageText = "(whispered)"
                        }
                    } else {
                        print("Could not derive decryption key")
                    }
                } else if let privateSignKey = self.keys["signKey"] as? P384.KeyAgreement.PrivateKey, let verificationKey = deriveKey(privateKey: privateSignKey, publicKey: senderCryptoKey) as? SymmetricKey {
                    let _sign = message["sign"];
                    let _image_sign = message["image_sign"];
                    let _imageMetadata_sign = message["imageMetadata_sign"];
                    if ((_sign == nil) || (_image_sign==nil) || (_imageMetadata_sign==nil)) {
                        _text_verified = false;
                    }
                    _text_verified = verify(key: verificationKey, sign: _sign as? String ?? "", content: message["contents"] as? String ?? "");
                    if let image = message["image"] as? String {
                        _image_verified = verify(key: verificationKey, sign: _image_sign as? String ?? "", content: image);
                    }
                    if let _imageMetaDataString = message["imageMetaData"] as? String {
                        // print(_imageMetaDataString)
                        _imageMetadata_verified = verify(key: verificationKey, sign: _imageMetadata_sign as? String ?? "", content: _imageMetaDataString );
                    }
                    messageText = message["contents"] as? String ?? "";
                    
                    if !(_image_verified && _text_verified && _imageMetadata_verified) {
                        messageStatus = messageStatusDefaults.unverified;
                    }
                    // print("Text verified: \(_text_verified), Image verified: \(_image_verified), Image metadata verified: \(_imageMetadata_verified)");
                }
                
                var user_key = (sender_pubKey["x"] as? String ?? "") + " " + (sender_pubKey["y"] as? String ?? "");
                var username = "";
                var local_username: String;
                // var user_id = JSONStringify(jsonObject: sender_pubKey) ?? "";
                if let _localUsername = self.contacts[user_key], !_localUsername.starts(with: "User"){
                    local_username = _localUsername;
                } else {
                    local_username = "Unnamed";
                }
                contacts[user_key] = local_username;
                let alias: String = message["sender_username"] as? String ?? "";
                let isOwner = areJWKKeysSame(key1: sender_pubKey, key2: self.ownerJWK )
                let isVerifiedGuest = areJWKKeysSame(key1: sender_pubKey, key2: self.guestJWK )
                if user_key == self.userKey || local_username == "Me" {
                    contacts[user_key] = "Me";
                    username = "Me";
                    user_key = self.userKey;
                } else {
                    if alias != "" {
                        username = (local_username == alias || local_username == "Unnamed") ? alias : alias + "  (\(local_username))";
                    } else {
                        username = "(" + local_username + ")";
                    }
                    if isVerifiedGuest{
                        username += "  (Verified)";
                    } else if isOwner {
                        username += "  (Owner)";
                    }
                }
                var userInitials = "";
                let name = username.uppercased().filter({ !(["(", ")"].contains($0))}).split(separator: " ")
                if name.count == 1 {
                    userInitials = String(name[name.startIndex].prefix(1));
                } else if name.count > 1 {
                    userInitials = String(name[name.startIndex].prefix(1)) + String(name[name.startIndex + 1].prefix(1))
                }
                let ts = Double(Int.init(messageId.suffix(42), radix: 2) ?? 0);
                var imgString = "";
                if let imageURL = message["image"] as? String, imageURL.split(separator: ",").count>1 {
                    imgString = String(imageURL.split(separator: ",")[1]);
                }
                    
                    // let message_image = MKMessage(mid: "\(messageId)_image", messageSender: MKSender(senderId: user_id, displayName: username, isOwner: isOwner, isVerifiedGuest: isVerifiedGuest), messageStatus: messageStatus, messageText: "", messageDate: Date(timeIntervalSince1970: ts/1000), isReceiver: user_key==self.userKey, userInitials: userInitials, image: image, imageMetadata: message["imageMetaData"] as? [String: String] ?? [:])
                    // messages.append(message_image)
                var imageMetaData: [String: String] = [:]
                if let parsedMetadata = JSONParse(jsonString: message["imageMetaData"] as? String ?? "") as? [String: String] {
                    imageMetaData = parsedMetadata
                } else if let metadata = message["imageMetaData"] as? [String: String] {
                    imageMetaData = metadata;
                }
                let new_message = MKMessage(mid: messageId, messageSender: MKSender(senderId: user_key, displayName: username, isOwner: isOwner, isVerifiedGuest: isVerifiedGuest), messageStatus: messageStatus, messageText: messageText, messageDate: Date(timeIntervalSince1970: ts/1000), isReceiver: user_key==self.userKey, userInitials: userInitials, image: imgString, imageMetadata: imageMetaData);
                let duplicate = self.mkMessages.contains { $0.messageId == messageId };
                if !duplicate{
                    messages.append(new_message)
                }
            }
        }
        messages.sort {$0.sentDate < $1.sentDate}
        self.mkMessages = oldMessages ? messages + self.mkMessages : self.mkMessages + messages;
        self.updateChatView(scrollToBottom: !oldMessages && messages.count>0);
    }
    
    func getOldMessages(jsonResp: [String: Any]) {
        if jsonResp.count > 0 {
            // print(jsonResp);
            let old_messages = self.unwrapMessages(data: jsonResp);
            // print(old_messages)
            self.addChatMessages(receivedMessages: old_messages, oldMessages: true);
        } else {
            self.moreMessages = false;
        }
    }
    
    func sendMessage(text: String, whispered: Bool, whisperKey: SymmetricKey?, recipient: [String: Any]?) {
        var contents: [String: Any] = [:]
        var fileMetadata : [String: String] = [:];
        var thumbnail = Data("".utf8);
        if var image = self.image {
            restrictPhoto(photo: &image, maxSizeKB: 20) { data in
                if (data != nil){
                    thumbnail = data!;
                    print("Got thumbnail \(thumbnail.count)")
                }
            }
            let imageData = self.saveImage(image: &image);
            print("Result from saveImage \(imageData)");
            if let imgId = imageData["full"] as? String, let imgKey = imageData["fullKey"] as? String, let previewId = imageData["preview"] as? String, let previewKey = imageData["previewKey"] as? String {
                fileMetadata = [ "imageId": imgId, "previewId": previewId, "imageKey": imgKey, "previewKey": previewKey ];
            }
        }
        var thumbnailString = "";
        if thumbnail.count > 0{
            thumbnailString = "data:image/jpeg;base64," + thumbnail.base64EncodedString();
        }
        let metaDataString = JSONStringify(jsonObject: fileMetadata);
        if whispered, whisperKey != nil {
            let encryptedContent = encrypt(contents: Data(text.utf8), key: whisperKey!, _iv: nil);
            let encryptedImg = encrypt(contents: thumbnail, key: whisperKey!, _iv: nil);
            let encryptedImgMetadata = encrypt(contents: Data(metaDataString?.utf8 ?? "".utf8), key: whisperKey!, _iv: nil);
            contents = ["encrypted": true, "contents": encryptedContent, "sender_pubKey": self.jwkPubKey, "image": encryptedImg, "imageMetaData": encryptedImgMetadata];
            if recipient != nil {
                contents["recipient"] = recipient;
            }
        } else if let personal_signKey = self.keys["personal_signKey"] as? SymmetricKey {
            let _sign = sign(key: personal_signKey, contents: text);
            let _image_sign = sign(key: personal_signKey, contents: thumbnailString );
            let _image_Metadata_sign = sign(key: personal_signKey, contents: metaDataString!);
            contents = ["encrypted": false, "contents": text, "sender_pubKey": self.jwkPubKey, "sign": _sign, "image": thumbnailString, "image_sign": _image_sign, "imageMetaData": metaDataString, "imageMetadata_sign": _image_Metadata_sign]
        }
        contents["sender_username"] = self.currentUser.displayName;
        print("Sending \(contents)")
        let msg = wrapMessages(contents: contents)
        if let err = msg["error"] as? Bool, err {
            print("Could not send message \(msg), error: \(err)")
        } else if let msgString = JSONStringify(jsonObject: msg), let websocket = self.websocket {
            // print("Trying to send")
            websocket.send(URLSessionWebSocketTask.Message.string(msgString)) { err in
                print(err)
            }
        } else {
            print("Check websocket or could not stringify")
        }
    }
    
    private func sendControlMessage(contents: [String: String]) {
        print("Entered control message \(contents)")
        var _contents : [String: Any] = contents;
        _contents["control"] = true;
        let controlMsg = wrapMessages(contents: _contents);
        if let msgString = JSONStringify(jsonObject: controlMsg), let websocket = self.websocket {
            print("Sending control message \(msgString)");
            websocket.send(URLSessionWebSocketTask.Message.string(msgString)) {
                [weak self] (err) in guard self != nil else {return}
            }
        } else {
            print("Check websocket or could not stringify")
        }
    }
    
    private func updateChatView(scrollToBottom: Bool = false) {
        DispatchQueue.main.async {
            if scrollToBottom{
                self.messagesCollectionView.reloadData();
                self.messagesCollectionView.scrollToLastItem();
            } else {
                self.messagesCollectionView.reloadDataAndKeepOffset();
            }
        }
    }
    
    // MARK: - Event listeners
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if refreshController.isRefreshing, self.moreMessages {
            if let url = URL(string: "https://\(self.config["roomServer"])/api/room/\(self.roomId)/oldMessages?currentMessagesLength=\(self.mkMessages.count)"){
                let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                    guard let data = data else { return }
                    if let datastr = String(data: data, encoding: .utf8), let jsonResp = JSONParse(jsonString: datastr) {
                        self.getOldMessages(jsonResp: jsonResp)
                    }
                }
                task.resume()
                
            }
            refreshController.endRefreshing();
        }
    }
    
    // MARK: - UI Related functions
    
    private func showActionSheet() {
        
        messageInputBar.inputTextView.resignFirstResponder()
        
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let takePhotoOrVideo = UIAlertAction(title: "Camera", style: .default) { (alert) in
            
            self.showImageGallery(camera: true)
        }
        
        let shareMedia = UIAlertAction(title: "Library", style: .default) { (alert) in
            // Set to false to also show videos
            self.showImageGallery(camera: false)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        takePhotoOrVideo.setValue(UIImage(systemName: "camera"), forKey: "image")
        shareMedia.setValue(UIImage(systemName: "photo.fill"), forKey: "image")
        
        
        optionMenu.addAction(takePhotoOrVideo)
        optionMenu.addAction(shareMedia)
        optionMenu.addAction(cancelAction)
        
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    func showLoadingScreen(message: String) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        return alert;
    }
    
    @objc func showWhisper() {
        let ac = UIAlertController(title: self.roomName, message: "Whisper to room owner.", preferredStyle: .alert)
        ac.addTextField()
        let saveAction = UIAlertAction(title: "Send", style: .default) { [unowned ac] _ in
            if let whisperText = ac.textFields![0].text, let whisperKey = self.keys["sharedKey"] as? SymmetricKey {
                self.sendMessage(text: whisperText, whispered: true, whisperKey: whisperKey, recipient: nil);
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
        ac.addAction(saveAction);
        ac.addAction(cancelAction);
        // ac.addAction(meAction)
        updateUI {
            self.present(ac, animated: true);
        }
    }
    
    @objc func showRoomSettings() {
        updateUI {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(withIdentifier: "roomSettingsViewController") as? RoomSettingsViewController{
                vc.roomId = self.roomId;
                vc.title = self.roomName;
                vc.motd = self.motd;
                vc.username = self.currentUser.displayName;
                vc.roomName = self.roomName;
                vc.container = self.container;
                updateUI {
                    self.navigationController!.pushViewController(vc, animated: true)
                }
            }
        }
    }
    
    func showConfigError() {
        let ac = UIAlertController(title: nil, message: "There was an error loading your configurations. Please save your configurations in the Configuration Settings. You will not be able to chat until the configurations are set.", preferredStyle: .alert);
        let saveAction = UIAlertAction(title: "Ok", style: .default) { [unowned ac] _ in
            updateUI {
                self.dismiss(animated: true, completion: nil);
                self.navigationController?.popViewController(animated: true);
            }
        }
        ac.addAction(saveAction);
        updateUI {
            self.present(ac, animated: true);
        }
    }
    
    //MARK: - Image Related Functions
    
    private func showImageGallery(camera: Bool) {
        
        gallery = GalleryController()
        gallery.delegate = self
        
        Config.tabsToShow = camera ? [.cameraTab] : [.imageTab]
        Config.Camera.imageLimit = 1
        Config.initialTab = .imageTab
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [unowned self] (status) in
            updateUI {
                self.present(gallery, animated: true, completion: nil)
            }
        }
    }
    
    private func saveImage(image: inout UIImage) -> [String:Any] {
        // print(image.jpegData(compressionQuality: 1.0)!.count)
        // print("in save image now");
        var preview = Data(count: 0);
        var full = Data(count: 0);
        restrictPhoto(photo: &image, maxSizeKB: 4*1024) { data in
            if (data != nil){
                preview = data!;
                // print("Got preview")
            }
        }
        if image.jpegData(compressionQuality: 1.0)!.count > 15*1024*1024 {
            restrictPhoto(photo: &image, maxSizeKB: 15*1024) { data in
                if (data != nil) {
                    full = data!;
                    // print("Got full")
                }
            }
        } else {
            full = image.jpegData(compressionQuality: 1.0)!;
            // print("Got full")
        }
        let previewImage = padData(data: preview);
        // print("PADDED PREVIEW \(previewImage)")
        let previewHash = getDataHash(data: previewImage);
        // print("PREVIEW HASH \(previewHash)")
        let fullImage = padData(data: full);
        // print("PADDED FULL \(fullImage)")
        let fullHash = getDataHash(data: fullImage);
        // print("FULL HASH \(fullHash)")
        if let previewId = previewHash["id"], let previewKey = previewHash["key"], let fullId = fullHash["id"], let fullKey = fullHash["key"] {
            Task {
                // print("Now storing ")
                await self.storeData(data: previewImage, dataId: previewId, dataKey: previewKey, dataType: "p");
                await self.storeData(data: fullImage, dataId: fullId, dataKey: fullKey, dataType: "f");
            }
            // print("Returning from save image");
            return [ "full": fullId, "preview": previewId, "fullKey": fullKey, "previewKey": previewKey ];
        }
        return [:];
    }
    
    
    func storeData(data: Data, dataId: String, dataKey: String, dataType: String) async {
        print("In store data")
        var returnDict: [String : String] = [:];
        if let url = URL(string: "https://\(self.config["storageServer"])/api/v1/storeRequest?name=\(dataId)") {
            let task = URLSession.shared.dataTask(with: url) {(requestData, response, error) in
                guard let requestData = requestData else {
                    // print("Could not fetch encryption data");
                    return
                }
                print(String(data: requestData, encoding: .utf8))
                if let jsonString = String(data: requestData, encoding: .utf8), let json = JSONParse(jsonString: jsonString), let err = json["error"] as? String {
                    // print("Error in first resp \(err)");
                    return;
                }
                let extractedData = extractPayload(payload: requestData, storeReq: true);
                print("Req1 result \(extractedData)")
                if let iv = extractedData["iv"], let salt = extractedData["salt"], let key = getDataKey(imageHash: dataKey, salt: salt) {
                    let encryptedData = encrypt(contents: data, key: key, outputType: "Data", _iv: iv);
                    // print("ENCRYPTED DATA: ", encryptedData)
                    if let socketURL = URL(string: "https://\(self.config["roomServer"])/api/room/\(self.roomId)/storageRequest?size=\(encryptedData.count)") {
                        let storageTokenTask = URLSession.shared.dataTask(with: socketURL) {(storageData, storageResponse, storageError) in
                            guard let storageData = storageData else {
                                // print("Could not fetch storage token data")
                                return
                            }
                            let storageTokenString = String(data: storageData, encoding: .utf8)
                            let storageTokenJSON = JSONParse(jsonString: storageTokenString!);
                            // print("Req2 result \(storageTokenJSON)")
                            if let storageTokenError = storageTokenJSON?["error"] {
                                // print(storageTokenError);
                                return;
                            } else if let storageToken = storageTokenJSON!["token"] as? String {
                                returnDict["storageToken"] = storageToken;
                            }
                            var vidBytes = [Int8](repeating: 0, count: 48)
                            // Fill bytes with secure random data
                            let status = SecRandomCopyBytes(
                                kSecRandomDefault,
                                48,
                                &vidBytes
                            )
                            if let storageUrl = URL(string: "https://\(self.config["storageServer"])/api/v1/storeData?type=\(dataType)&key=\(dataId.addingPercentEncoding(withAllowedCharacters: allowedCharSet.js)!)"), let contents = encryptedData["content"] as? Data, let storageToken = storageTokenString!.data(using: .utf8), status == errSecSuccess {
                                let vidData = Data(bytes: vidBytes, count: 48)
                                let postBody = assemblePayload(data: ["iv": iv, "salt": salt, "image": contents, "storageToken": storageToken, "vid": vidData])
                                var postRequest = URLRequest(url: storageUrl)
                                postRequest.httpMethod = "POST";
                                postRequest.httpBody = postBody
                                // print("sending \(postBody.count) bytes")
                                let finalTask = URLSession.shared.dataTask(with: postRequest) { (finalData, finalResponse, finalError) in
                                    guard let finalData = finalData else {
                                        print("could not get final data");
                                        return
                                    }
                                    let finalRespString = String(data: finalData, encoding: .utf8);
                                    // print(finalRespString)
                                    let finalJson = JSONParse(jsonString: finalRespString!);
                                    print("Req3: \(finalJson)")
                                    if let verificationError = finalJson!["error"] {
                                        print("Error in final storage: ", verificationError);
                                    } else if let verificationToken = finalJson!["verification_token"] as? String, let id = finalJson!["image_id"] as? String{
                                        returnDict["verificationToken"] = verificationToken;
                                        returnDict["id"] = id;
                                        // print("Sending control message");
                                        self.sendControlMessage(contents: returnDict);
                                    }
                                }
                                finalTask.resume();
                            } else {
                                print("Outside creation for final url etc")
                            }
                        }
                        storageTokenTask.resume();
                    } else {
                        print("Outside url creation for socket request")
                    }
                } else{
                    print("Could not get iv etc");
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Helpers
    
    func saveUsername(userKey: String, new: String) {
        self.contacts[userKey] = new;
        updateContacts(contacts: self.contacts, container: self.container)
    }
}

