//
//  Utils.swift
//  Snackabra
//
//  Created by Yash on 1/20/22.
//

import Foundation
import CoreData
import UIKit

// JS Parallel for encodeURIComponent
enum allowedCharSet {
    static let js = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()");
}

func JSONStringify(jsonObject: [String: Any]) -> String? {
    if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
        return String(data: jsonData, encoding: .utf8);
    }
    return nil;
}

func JSONParse(jsonString: String) -> [String: Any]? {
    if let data = jsonString.data(using: .utf8), let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]{
        return jsonObject
    }
    return nil;
}

// The base64url to base 64 and vice versa are needed for conversions from jwk to pem and vice versa

func base64urlToBase64(base64url: String) -> String {
    var base64 = base64url
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    if base64.count % 4 != 0 {
        base64.append(String(repeating: "=", count: 4 - base64.count % 4))
    }
    return base64
}

func base64ToBase64url(base64: String) -> String {
    let base64url = base64
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return base64url
}

/*

func extractPayload(payload:Data, storeReq: Bool = false) -> [String: Data] {
    var data: [String: Data] = [:];
    print(payload.count, payload.subdata(in: payload.startIndex ..< payload.startIndex + 4).withUnsafeBytes{ Array($0.bindMemory(to: UInt32.self))})
    let metadataSize = Int(payload.subdata(in: payload.startIndex ..< payload.startIndex + 4).withUnsafeBytes{ Array($0.bindMemory(to: UInt32.self))}[0]);
    print(metadataSize);
    if let metadataString = String(data: payload.subdata(in: payload.startIndex + 4 ..< payload.startIndex + 4 + metadataSize), encoding: .utf8), let metadata = JSONParse(jsonString: metadataString) as? [String: Int]{
        var startIndex = payload.startIndex + 4 + metadataSize;
        if storeReq {
            data["salt"] = payload.subdata(in: startIndex ..< startIndex + 16);
            startIndex += 16;
            data["iv"] = payload.subdata(in: startIndex ..< startIndex + 12);
            return data;
        }
        data["iv"] = payload.subdata(in: startIndex ..< startIndex + 12);
        startIndex += 12;
        data["salt"] = payload.subdata(in: startIndex ..< startIndex + 16);
        startIndex += 16;
        data["image"] = payload.subdata(in: startIndex ..< startIndex + metadata["image"]!);
    }
    return data;
}

func assemblePayload(data: [String: Data]) -> Data{
    var metadata: [String: Int] = [:];
    for (key, val) in data {
        metadata[key] = val.count;
    }
    let metadataString = JSONStringify(jsonObject: metadata);
    var metadataBuffer = metadataString!.data(using: .utf8);
    var metadataSizeBuffer = UInt32(metadataBuffer!.count)
    let metadataSize = Data(bytes: &metadataSizeBuffer, count: MemoryLayout<UInt32>.size);
    print(metadataSize);
    print(metadataBuffer?.count)
    var payload: Data = metadataSize;
    payload.append(metadataBuffer!);
    if let iv = data["iv"], let salt = data["salt"], let image = data["image"], let storageToken = data["storageToken"], let vid = data["vid"] {
        payload.append(iv);
        payload.append(salt);
        payload.append(image)
        payload.append(storageToken);
        payload.append(vid);
    }
    return payload;
}

*/

func updateUI(completion: @escaping ()->()) {
    DispatchQueue.main.async {
        completion();
    }
}

func getCoreData(container: NSPersistentContainer, entityName: String, predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?) -> [NSManagedObject]? {
    let managedContext = container.viewContext
    let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
    if predicate != nil {
        fetchRequest.predicate = predicate;
    }
    if sortDescriptors != nil {
        fetchRequest.sortDescriptors = sortDescriptors;
    }
    if let fetchResults = try? managedContext.fetch(fetchRequest) {
        return fetchResults
    }
    return nil;
}

func putCoreData(container: NSPersistentContainer, entityName: String, args: [String: Any], mo: NSManagedObject?) {
    let managedContext = container.viewContext
    let entity = NSEntityDescription.entity(forEntityName: entityName, in: managedContext)!
    let obj = mo ?? NSManagedObject(entity: entity, insertInto: managedContext)
    
    for (key, val) in args {
        obj.setValue(val, forKey: key);
    }
    do {
        try managedContext.save()
    } catch let error as NSError {
        print("Could not save \(entityName)/s. \(error), \(error.userInfo)")
    }
}

func loader(message: String) -> UIAlertController {
    let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
    let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
    loadingIndicator.hidesWhenStopped = true
    loadingIndicator.style = UIActivityIndicatorView.Style.large
    loadingIndicator.startAnimating()
    alert.view.addSubview(loadingIndicator)
    // present(alert, animated: true, completion: nil)
    return alert
}

func stopLoader(loader : UIAlertController) {
    updateUI {
        loader.dismiss(animated: true, completion: nil)
    }
}

func extractPayload(payload:Data, storeReq: Bool = false) -> [String: Data] {
    var data: [String: Data] = [:];
    print(payload.count, payload.subdata(in: payload.startIndex ..< payload.startIndex + 4).withUnsafeBytes{ Array($0.bindMemory(to: UInt32.self))})
    let metadataSize = Int(payload.subdata(in: payload.startIndex ..< payload.startIndex + 4).withUnsafeBytes{ Array($0.bindMemory(to: UInt32.self))}[0]);
    print(metadataSize);
    if let metadataString = String(data: payload.subdata(in: payload.startIndex + 4 ..< payload.startIndex + 4 + metadataSize), encoding: .utf8), let metadata = JSONParse(jsonString: metadataString) as? [String: Any] {
        let version = metadata["version"] as? String ?? "001";
        if version == "001" {
            print("Got old version");
            var startIndex = payload.startIndex + 4 + metadataSize;
            if storeReq {
                data["salt"] = payload.subdata(in: startIndex ..< startIndex + 16);
                startIndex += 16;
                data["iv"] = payload.subdata(in: startIndex ..< startIndex + 12);
                return data;
            }
            data["iv"] = payload.subdata(in: startIndex ..< startIndex + 12);
            startIndex += 12;
            data["salt"] = payload.subdata(in: startIndex ..< startIndex + 16);
            startIndex += 16;
            data["image"] = payload.subdata(in: startIndex ..< startIndex + (metadata["image"]! as! Int));
        } else if version == "002" {
            print("Got new version", metadata);
            let totalElements = metadata.count;
            var elementIndex = 1;
            repeat {
                let _index = String(elementIndex);
                if let metadataElement = metadata[_index] as? [String:Any], let name = metadataElement["name"] as? String, let relativeStartIndex = metadataElement["start"] as? Int, let size = metadataElement["size"] as? Int {
                    let dataStartIndex = payload.startIndex + 4 + metadataSize;
                    data[name] = payload.subdata(in: dataStartIndex + relativeStartIndex ..< dataStartIndex + relativeStartIndex + size);
                }
                elementIndex += 1;
            } while elementIndex < totalElements
        }
    }
    return data;
}

func assemblePayload(data: [String: Data]) -> Data{
    var metadata: [String: Any] = [:];
    metadata["version"] = "002";
    var keyCount = 0;
    var startIndex = 0;
    var _data = Data(count: 0);
    for (key, val) in data {
        keyCount += 1;
        metadata[String(keyCount)] = [ "name": key, "start": startIndex, "size": val.count];
        startIndex += val.count;
        _data.append(val);
    }
    let metadataString = JSONStringify(jsonObject: metadata);
    let metadataBuffer = metadataString!.data(using: .utf8);
    var metadataSizeBuffer = UInt32(metadataBuffer!.count)
    let metadataSize = Data(bytes: &metadataSizeBuffer, count: MemoryLayout<UInt32>.size);
    print(metadataSize);
    print(metadataBuffer?.count)
    var payload: Data = metadataSize;
    payload.append(metadataBuffer!);
    payload.append(_data);
    return payload;
}

func getConfig(container: NSPersistentContainer) -> [String: String]?{
    if let fetchRes = getCoreData(container: container, entityName: "User", predicate: NSPredicate(format: "id = 1"), sortDescriptors: []), fetchRes.count > 0 {
        let user = fetchRes[0];
        if let roomServer = user.value(forKey: "roomServer") as? String, let storageServer = user.value(forKey: "storageServer") as? String {
            return ["roomServer": roomServer, "storageServer": storageServer];
        }
    }
    return nil;
}
