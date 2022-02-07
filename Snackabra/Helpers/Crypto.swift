//
//  Crypto.swift
//  Snackabra
//
//  Created by Yash on 1/14/22.
//

import Foundation
import CryptoKit
import CommonCrypto
// MARK: - Protocols for Keychain storage

struct KeyStoreError: Error, CustomStringConvertible {
    var message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        return message
    }
}

protocol SecKeyConvertible: CustomStringConvertible {
    /// Creates a key from an X9.63 representation.
    init<Bytes>(x963Representation: Bytes) throws where Bytes: ContiguousBytes
    
    /// An X9.63 representation of the key.
    var x963Representation: Data { get }
}
extension P384.KeyAgreement.PrivateKey: SecKeyConvertible {
    public var description: String {
        return self.pemRepresentation
    }
}

extension P384.KeyAgreement.PublicKey: SecKeyConvertible {
    public var description: String {
        return self.pemRepresentation
    }
}

// MARK: - Keychain retrieval

func retrieveKey(label: String) throws -> SecKey? {
    let query = [kSecClass: kSecClassKey,
  kSecAttrApplicationLabel: label,
           kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
kSecUseDataProtectionKeychain: true,
             kSecReturnRef: true] as [String: Any]
    
    // Find and cast the result as a SecKey instance.
    var item: CFTypeRef?
    var secKey: SecKey
    switch SecItemCopyMatching(query as CFDictionary, &item) {
    case errSecSuccess: secKey = item as! SecKey
    case errSecItemNotFound: return nil
    case let status: throw KeyStoreError("Keychain read failed: \(status)")
    }
    return secKey
}

func convertSecKeyToCryptoKit (secKey: SecKey) throws -> P384.KeyAgreement.PrivateKey {
    var error: Unmanaged<CFError>?
    guard let data = SecKeyCopyExternalRepresentation(secKey, &error) as Data? else {
        throw KeyStoreError(error.debugDescription)
    }
    let key = try P384.KeyAgreement.PrivateKey(x963Representation: data)
    return key
}

// MARK: - Keychain Storage

func storeKey<T: SecKeyConvertible>(_ key: T, label: String) throws {
    let attributes = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                     kSecAttrKeyClass: kSecAttrKeyClassPrivate] as [String: Any]
    
    // Get a SecKey representation.
    guard let secKey = SecKeyCreateWithData(key.x963Representation as CFData,
                                            attributes as CFDictionary,
                                            nil)
    else {
        throw KeyStoreError("Unable to create SecKey representation.")
    }
    // Describe the add operation.
    let query = [kSecClass: kSecClassKey,
  kSecAttrApplicationLabel: label,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
kSecUseDataProtectionKeychain: true,
              kSecValueRef: secKey] as [String: Any]
    
    // Add the key to the keychain.
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeyStoreError("Unable to store item: \(status)")
    }
}

func importKeysToKeychain(jsonData: NSDictionary) {
    if let roomData = jsonData["roomData"] as? [String : [String : String]]{
        for (key, val) in roomData {
            do{
                let keyString: String = val["key"]!
                let _key = try P384.KeyAgreement.PrivateKey(pemRepresentation: keyString )
                try storeKey(_key, label: key)
            } catch{
                print("Error importing/storing key for \(key): \(error)")
            }
        }
    } else {
        print("Incorrect formatting of roomdata")
    }
}

// MARK: - Cryptokit operations

func encrypt(contents: Data, key: SymmetricKey, outputType: String = "string", _iv: Data?) -> [String: Any] {
    do{
        var sealedBox: AES.GCM.SealedBox;
        if let iv = _iv {
            sealedBox = try AES.GCM.seal(contents, using: key, nonce: AES.GCM.Nonce(data: iv))
        } else {
            sealedBox = try AES.GCM.seal(contents, using: key);
        }
        var encryptedData = sealedBox.ciphertext;
        encryptedData.append(sealedBox.tag);
        let ivData = sealedBox.nonce.withUnsafeBytes({Data(Array($0))})
        var returnObj : [String: Any] = ["content": encryptedData, "iv": ivData]
        if outputType == "string" {
            let encryptedString = encryptedData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedCharSet.js)
            let returnIv = ivData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedCharSet.js)
            returnObj = ["content": encryptedString, "iv": returnIv]
        }
        return returnObj;
    } catch {
        return ["error": error];
    }
}

func decryptData(contents: [String: Data], key: SymmetricKey) throws -> Data {
    if let iv = contents["iv"], let encryptedContent = contents["encryptedContent"], let authTag = contents["authTag"]{
        let encrypted = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: encryptedContent, tag: authTag)
        // print(encrypted);
        let decryptedData = try AES.GCM.open(encrypted, using: key);
        // print(decryptedData)
        return decryptedData;
    }
    return Data(count:0);
}

func decrypt(contents: [String:String], key: SymmetricKey) throws -> [String: Any] {
    guard let b64iv = (contents["iv"])?.removingPercentEncoding, let iv = Data(base64Encoded: b64iv) else {
        print("Could not load iv: \(contents["iv"])")
        return ["error": true, "plaintext": "(whispered)"];
    };
    guard let b64content = (contents["content"])?.removingPercentEncoding, let content = Data(base64Encoded: b64content) else {
        print("Could not load Data \((contents["content"])?.removingPercentEncoding)")
        return ["error": true, "plaintext": "(whispered)"];
    };
    let encryptedContent = content.subdata(in: content.startIndex..<(content.startIndex + content.endIndex-16));
    let authTag = content.subdata(in: (content.startIndex + content.endIndex-16)..<content.endIndex);
    if let decryptedData = try? decryptData(contents: ["iv": iv, "encryptedContent": encryptedContent, "authTag": authTag], key: key), let decryptedString = String(data: decryptedData, encoding: .utf8){
    // print(decryptedString)
        return ["error": false, "plaintext": decryptedString];
    }
    return ["error": true, "plaintext": "(whispered)"];
}

func deriveKey(privateKey: P384.KeyAgreement.PrivateKey, publicKey: P384.KeyAgreement.PublicKey) -> Any {
    do{
        return try SymmetricKey(data : privateKey.sharedSecretFromKeyAgreement(with: publicKey).withUnsafeBytes({ body in
            return Data(Array(body)).subdata(in: body.startIndex ..< body.startIndex + 32)
        }));
    } catch {
        return ["error": error];
    }
}

func sign(key: SymmetricKey, contents: String) -> String {
    let _sign = Data(HMAC<SHA256>.authenticationCode(for: Data(contents.utf8), using: key))
    return (_sign.base64EncodedString().addingPercentEncoding(withAllowedCharacters: allowedCharSet.js))!;
}

func verify(key: SymmetricKey, sign: String, content: String) -> Bool {
    if let _sign = Data(base64Encoded: (sign.removingPercentEncoding!)) {
        return HMAC<SHA256>.isValidAuthenticationCode([UInt8](_sign), authenticating: [UInt8](content.utf8), using: key)
    }
    print("Could not get data from sign")
    return false;
}

func generateKeys() -> P384.KeyAgreement.PrivateKey {
    return P384.KeyAgreement.PrivateKey();
}

// MARK: - JWK ops

func importJWKECPrivate(key: [String: Any]) -> P384.KeyAgreement.PrivateKey? {
    if var x = key["x"] as? String, var y = key["y"] as? String, var d = key["d"] as? String {
        x = base64ToBase64url(base64: x);
        y = base64ToBase64url(base64: y);
        d = base64ToBase64url(base64: d);
        if let xData = Data(base64Encoded: x), let yData = Data(base64Encoded: y), let dData = Data(base64Encoded: d) {
            let xBytes = [UInt8](xData);
            let yBytes = [UInt8](yData);
            let dBytes = [UInt8](dData);
            let keyData = Data(xBytes + yBytes + dBytes);
            do{
                let key = try P384.KeyAgreement.PrivateKey(rawRepresentation: keyData);
                return key;
            } catch {
                print("Failed to import private key \(key)")
            }
        }
    }
    return nil;
}

func importJWKECPublic(key: [String: Any]) -> P384.KeyAgreement.PublicKey? {
    if var x = key["x"] as? String, var y = key["y"] as? String {
        x = base64urlToBase64(base64url: x);
        y = base64urlToBase64(base64url: y);
        if let xData = Data(base64Encoded: x), let yData = Data(base64Encoded: y){
            let xBytes = [UInt8](xData);
            let yBytes = [UInt8](yData);
            let keyData = Data(xBytes + yBytes);
            do{
                let key = try P384.KeyAgreement.PublicKey(rawRepresentation: keyData);
                return key;
            } catch {
                print("Failed to import private key \(key), \(error)")
            }
        }
    }
    return nil;
}

func getJWKKey(key: P384.KeyAgreement.PublicKey) -> [String: Any] {
    let rawData: Data = key.rawRepresentation;
    let keyLength = rawData.count;
    let partLength = keyLength/2;
    let xBytes = rawData.subdata(in: rawData.startIndex ..< rawData.startIndex+partLength);
    let yBytes = rawData.subdata(in: rawData.startIndex+partLength ..< rawData.endIndex);
    let x = base64ToBase64url(base64: xBytes.base64EncodedString());
    let y = base64ToBase64url(base64: yBytes.base64EncodedString());
    return ["crv": "P-384", "ext": true, "key_ops": [], "kty": "EC", "x": x, "y": y];
}

func areJWKKeysSame(key1: [String: Any], key2: [String: Any]) -> Bool {
    if let x1=key1["x"] as? String, let x2=key2["x"] as? String, let y1=key1["y"] as? String, let y2=key1["y"] as? String, x1==x2, y1==y2{
        return true;
    }
    return false;
}

// MARK: - PBKDF2

func pbkdf2(hash :CCPBKDFAlgorithm, password: UnsafePointer<CChar>, passwordSize: Int, salt: Data, keyByteCount: Int, rounds: Int) -> Data? {
    var derivedKeyData = Data(repeating: 0, count: keyByteCount)
    let derivedCount = derivedKeyData.count
    let derivationStatus: Int32 = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
        let keyBuffer: UnsafeMutablePointer<UInt8> =
        derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
        return salt.withUnsafeBytes { saltBytes -> Int32 in
            let saltBuffer: UnsafePointer<UInt8> = saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                password,
                passwordSize,
                saltBuffer,
                salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(rounds),
                keyBuffer,
                derivedCount)
        }
    }
    return derivationStatus == kCCSuccess ? derivedKeyData : nil
}

