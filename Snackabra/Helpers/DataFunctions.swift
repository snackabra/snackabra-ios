//
//  DataFunctions.swift
//  Snackabra
//
//  Created by Yash on 1/21/22.
//

import Foundation
import CryptoKit
import CommonCrypto
import UIKit

func retrieveData(metadata: [String: String], controlMessage: [String: String], completion: @escaping (Data?)->()) {
    if let id = controlMessage["id"]?.addingPercentEncoding(withAllowedCharacters: allowedCharSet.js), let verification = controlMessage["verificationToken"], let url = URL(string: "https://s4.privacy.app/api/v1/fetchData?id=\(id)&verification_token=\(verification)"){
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else {
                print("Could not fetch data")
                return completion(nil);
            }
            print(String(data: data, encoding: .utf8));
            if let jsonResp = JSONParse(jsonString: String(data: data, encoding: .utf8) ?? ""), let err = jsonResp["error"] as? String {
                print("Error: ", err)
                completion(nil);
                return;
            }
            let extractedData = extractPayload(payload: data);
            if let iv = extractedData["iv"], let salt = extractedData["salt"], let _imageHash = metadata["previewKey"],
               let content = extractedData["image"], let dataKey = getDataKey(imageHash: _imageHash, salt: salt){
                do {
                    let paddedData = try decryptData(contents: ["encryptedContent": content.subdata(in: content.startIndex..<(content.startIndex + content.endIndex-16)), "iv": iv, "authTag" : content.subdata(in: (content.startIndex + content.endIndex-16)..<content.endIndex)], key: dataKey)
                    let decrypted = unpadData(data: paddedData);
                    completion(decrypted);
                } catch {
                    print(error);
                    completion(nil)
                }
            } else{
                print("DECRYPTION FAILED");
            }
        }
        task.resume()
    } else {
        print("Could not create url with \(controlMessage["id"]), \(controlMessage["verificationToken"])")
        return completion(nil);
    }
}

func unpadData(data: Data) -> Data {
    print(data);
    let size = Int(data.subdata(in: data.endIndex-4 ..< data.endIndex).withUnsafeBytes{ Array($0.bindMemory(to: UInt32.self))}[0])
    print(size)
    return data.subdata(in: data.startIndex ..< data.startIndex + size);
}

func padData(data: Data) -> Data{
    let _sizes = [128*1024, 256*1024, 512*1024, 1024*1024, 2048*1024, 4096*1024]  //Sizes in Bytes
    let dataSize = data.count;
    var _target: Int = 0;
    if dataSize < _sizes.last! {
        for _size in _sizes {
            if (dataSize + 21) < _size {
                _target = _size;
                break;
            }
        }
    } else {
        _target = Int(ceil(Float(dataSize)/Float(1024*1024)) * 1024 * 1024);
        if (dataSize + 21) >= _target {
            _target += 1024;
        }
    }
    let paddingSize = _target - dataSize - 21;
    var finalData = data;
    print("SIZE BEFORE PADDING", dataSize)
    var sizeBuffer = UInt32(dataSize);
    finalData.append(Data([UInt8(128)]));
    finalData.append(Data(repeating: 0, count: paddingSize));
    finalData.append(Data(bytes: &sizeBuffer, count: MemoryLayout<UInt32>.size))
    return finalData
}

func getDataKey(imageHash: String, salt: Data) -> SymmetricKey? {
    let passwordData = Data(base64Encoded: imageHash.removingPercentEncoding!);
    var key : SymmetricKey? = nil;
    passwordData?.withUnsafeBytes { bytes in
        let passwordBytes: UnsafePointer<CChar> = bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
        if let keyMaterial = pbkdf2(hash: CCPBKDFAlgorithm(kCCPBKDF2), password: passwordBytes, passwordSize: passwordData!.count, salt: salt, keyByteCount: 32, rounds: 100000){
            key = SymmetricKey(data: keyMaterial);
        }
    }
    /*
    if let keyMaterialString = imageHash.removingPercentEncoding, let keyMaterial = try? PKCS5.PBKDF2(password: Array(Data(base64Encoded: keyMaterialString)!), salt: Array(salt), iterations: 100000, keyLength: 32, variant: .sha2(.sha256)).calculate(){
        print(keyMaterial.toBase64())
        return SymmetricKey(data: keyMaterial);
    }
     */
    return key;
}

// MARK: - Image processing
//
//// (reference) https://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage
//extension UIImage {
//    func resized(to size: CGSize) -> UIImage {
//        return UIGraphicsImageRenderer(size: size).image { _ in
//            draw(in: CGRect(origin: .zero, size: size))
//        }
//    }
//}
//
//func restrictPhoto(photo: inout UIImage, maxSizeKB: Int, imageType: String? = "jpeg", qualityArgument: CGFloat = 0.92, completion: (Data?)->()) {
//    // starting point (what is size to start)
//    let testImage = photo.jpegData(compressionQuality: qualityArgument)
//    let canvas = UIImage(data: testImage!) // extract baseline h/w
//    let h = CGFloat(canvas!.size.height), w = CGFloat(canvas!.size.width)
//    var s = CGFloat(testImage!.count)
//    let target = CGFloat(maxSizeKB * 1024)
//    // our goal is to figure out what ratio gives the right answer
//    var ratio = CGFloat(1.0)
//    s = CGFloat(testImage!.count)
//    var i = 12
//    print("starting size", s)
//    while (s > target) {
//        // binary intervals until we're closer to target
//        ratio *= 0.5
//        s = resizeImage(photo: &photo, h: h, w: w, ratio: ratio, qualityArgument: qualityArgument)
//        print("cut it down to size ", s)
//    }
//    while ((s > target) || (s < (target * 0.97))) {
//        // now interpolation should be reliable
//        ratio *= (target / s)
//        s = resizeImage(photo: &photo, h: h, w: w, ratio: ratio, qualityArgument: qualityArgument)
//        print("changed it to size ", s)
//        i -= 1
//        if (i < 0) {
//            print("ERROR - could not figure out image reduction within iteration limit")
//            completion(nil)
//            return
//        }
//    }
//    let linear_ratio = sqrt(ratio) * 0.99 // and fudge factor to under-shoot
//    let resized_photo = photo.resized(to: CGSize(width: w * linear_ratio, height: h * linear_ratio))
//    let finalImage = resized_photo.jpegData(compressionQuality: qualityArgument)
//    completion(finalImage)
//}
//
//extension UIImage {
//    func resizeImage2(_ dimension: CGFloat, opaque: Bool, contentMode: UIView.ContentMode = .scaleAspectFit) -> UIImage {
//        var width: CGFloat
//        var height: CGFloat
//        var newImage: UIImage
//
//        let size = self.size
//        let aspectRatio =  size.width/size.height
//
//        switch contentMode {
//        case .scaleAspectFit:
//            if aspectRatio > 1 {                            // Landscape image
//                width = dimension
//                height = dimension / aspectRatio
//            } else {                                        // Portrait image
//                height = dimension
//                width = dimension * aspectRatio
//            }
//
//        default:
//            fatalError("UIIMage.resizeToFit(): FATAL: Unimplemented ContentMode")
//        }
//
//        if #available(iOS 10.0, *) {
//            let renderFormat = UIGraphicsImageRendererFormat.default()
//            renderFormat.opaque = opaque
//            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: renderFormat)
//            newImage = renderer.image {
//                (context) in
//                self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
//            }
//        } else {
//            UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), opaque, 0)
//            self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
//            newImage = UIGraphicsGetImageFromCurrentImageContext()!
//            UIGraphicsEndImageContext()
//        }
//
//        return newImage
//    }
//}
//
//
//// resizes as instructed and returns size of result
//func resizeImage(photo: inout UIImage, h: CGFloat, w: CGFloat, ratio: CGFloat, qualityArgument: CGFloat = 0.92) -> CGFloat {
//    let linear_ratio = sqrt(ratio) * 0.99 // and fudge factor to under-shoot
//    let resized_photo = photo.resized(to: CGSize(width: w * linear_ratio, height: h * linear_ratio))
//    let newImage = resized_photo.jpegData(compressionQuality: qualityArgument)
//    return(CGFloat(newImage!.count))
//}
//
//


//func restrictPhoto(photo: UIImage, maxSizeKB: Int, imageType: String? = "jpeg", qualityArgument: CGFloat = 0.92, completion: (Data?)->()) {
//    let maxSize = maxSizeKB * 1024;
//    if var finalImage = photo.jpegData(compressionQuality: qualityArgument) {
//        var _size = finalImage.count;
//        if (_size <= maxSize) {
//            completion(finalImage);
//            return;
//        }
//        var _old_size: Int = _size;
//        if var canvas = UIImage(data: finalImage){
//            while _size > maxSize {
//                canvas = resizeImage(image: canvas, ratio: 0.5);
//                finalImage = canvas.jpegData(compressionQuality: qualityArgument)!;
//                _old_size = _size;
//                _size = finalImage.count;
//            }
//            var _ratio : Float = Float(maxSize)/Float(_old_size);
//            var _maxIteration = 12;
//
//            repeat {
//                canvas = resizeImage(image: canvas, ratio: sqrt(_ratio)*0.99);
//                finalImage = canvas.jpegData(compressionQuality: qualityArgument)!;
//                _ratio *= (Float(maxSize) / Float(finalImage.count));
//                _maxIteration -= 1;
//            } while ( ( (finalImage.count > maxSize) || ( ( Float(abs(finalImage.count - maxSize)) / Float(maxSize) ) > 0.02 ) ) && (_maxIteration > 0) )
//            completion(finalImage);
//            return;
//        }
//    }
//    completion(nil);
//}

//// Corresponds to scaleCanvas on JS https://stackoverflow.com/questions/29726643/how-to-compress-of-reduce-the-size-of-an-image-before-uploading-to-parse-as-pffi
//func resizeImage(image: UIImage, ratio: Float) -> UIImage {
//    let actualHeight: Float = Float(image.size.height)
//    let actualWidth: Float = Float(image.size.width)
//    let newHeight = actualHeight * ratio;
//    let newWidth = actualWidth * ratio;
//
//    let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(newWidth), height: CGFloat(newHeight))
//    UIGraphicsBeginImageContext(rect.size)
//    image.draw(in: rect)
//    let img = UIGraphicsGetImageFromCurrentImageContext()
//    let imageData = img!.jpegData(compressionQuality: 1.0)
//    UIGraphicsEndImageContext()
//    return UIImage(data: imageData!)!
//}




func restrictPhoto(photo: inout UIImage, maxSizeKB: Int, imageType: String? = "jpeg", qualityArgument: CGFloat = 0.92, completion: (Data?)->()) {
    let maxSize = maxSizeKB * 1024;
    if var finalImage = photo.jpegData(compressionQuality: qualityArgument) {
        var _size = finalImage.count;
        if (_size <= maxSize) {
            completion(finalImage);
            return;
        }
        var _old_size: Int = _size;
        if var base_canvas = UIImage(data: finalImage){
            var ratio = Float(1.0)
            while _size > maxSize {
                ratio *= 0.5
                let canvas = resizeImage(image: &base_canvas, ratio: ratio);
                finalImage = canvas.jpegData(compressionQuality: qualityArgument)!;
                _old_size = _size;
                _size = finalImage.count;
            }
            var _ratio : Float = Float(maxSize)/Float(_old_size);
            var _maxIteration = 12;

            // var base_canvas = canvas
            
            repeat {
                let canvas = resizeImage(image: &base_canvas, ratio: sqrt(_ratio)*0.99);
                finalImage = canvas.jpegData(compressionQuality: qualityArgument)!;
                _ratio *= (Float(maxSize) / Float(finalImage.count));
                _maxIteration -= 1;
            } while ( ( (finalImage.count > maxSize) || ( ( Float(abs(finalImage.count - maxSize)) / Float(maxSize) ) > 0.02 ) ) && (_maxIteration > 0) )
            completion(finalImage);
            return;
        }
    }
    completion(nil);
}

// Corresponds to scaleCanvas on JS https://stackoverflow.com/questions/29726643/how-to-compress-of-reduce-the-size-of-an-image-before-uploading-to-parse-as-pffi
func resizeImage(image: inout UIImage, ratio: Float) -> UIImage {
    let actualHeight: Float = Float(image.size.height)
    let actualWidth: Float = Float(image.size.width)
    let newHeight = actualHeight * ratio;
    let newWidth = actualWidth * ratio;

    let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(newWidth), height: CGFloat(newHeight))
    UIGraphicsBeginImageContext(rect.size)
    image.draw(in: rect)
    let img = UIGraphicsGetImageFromCurrentImageContext()
    let imageData = img!.jpegData(compressionQuality: 1.0)
    UIGraphicsEndImageContext()
    return UIImage(data: imageData!)!
}


func getDataHash(data: Data) -> [String: String] {
    let digest = SHA512.hash(data: data);
    let hashData = Data(digest);
    let idData = hashData.subdata(in: hashData.startIndex ..< hashData.startIndex + 32);
    let keyData = hashData.subdata(in: hashData.endIndex-32 ..< hashData.endIndex);
    if let _id = idData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedCharSet.js), let _key = keyData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedCharSet.js) {
        return [ "id": _id, "key": _key]
    }
    return [:]
}
