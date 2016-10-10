import Foundation

func errorMessage(for status: OSStatus) -> String {
    switch status {
    case errSecSuccess:
        return "Operation successfully completed."
    case errSecItemNotFound:
        return "Item not found."
    case errSecInteractionNotAllowed:
        return "Device locked. Item unavailable."
    case errSecItemNotFound:
        return "The specified item could not be found in the keychain."
    case errSecAuthFailed:
        return "Authentication/Authorization failed."
    case errSecParam:
        return "One or more parameters passed to the function were not valid."
    case errSecDuplicateItem:
        return "The item already exists."
    case -34018:
        return "Entitlement not found. Please refer README."
    case -1:
        return "Error in SecAccessControl!"
    default:
        return "Unhandled Error: Please contact developer to report this error. Error code: \(status)"
    }
}

func decodeSecAccessControl(sacObj: Any?) -> String {

    var finalDecodedValue: String = String()

    // If there is no SecAccessControl object you will get a nil.
    // usually, happens when device does not support it or An item is not added
    // with SecAccessControl.
    if let unwrappedSACObj = sacObj {
      // iOS 8 behaves a bit differently. The SAC object is returned even though
      // the device does not support it. SAC contains the AccessibilityConstant.
      // Guess it has been refined in iOS9, where SAC only contains any value
      // if the device supports it.
      // Secondary check to make sure that we have something in SAC.
        if let operations = getOperations(unwrappedSACObj as! SecAccessControl)?.takeUnretainedValue() as? Dictionary<String, Any> {
            for eachOperation in operations.keys {
                switch eachOperation {
                case "dacl": return "Default ACL"
                case "od":
                    let constraints = operations["od"] as! Dictionary<String, AnyObject>
                    for eachConstraint in constraints.keys {
                        switch eachConstraint {
                        case "cpo": finalDecodedValue += " UserPresence "
                        case "cup": finalDecodedValue += " DevicePasscode "
                        case "pkofn": finalDecodedValue += (constraints["pkofn"] as! Int == 1 ? " Or " : " And ")
                        case "cbio": finalDecodedValue += ((constraints["cbio"]?.count)! == 1 ? " TouchIDAny " : " TouchIDCurrentSet ")
                        default: break
                        }
                    }
                case "osgn":
                    finalDecodedValue += "PrivateKeyUsage "
                    let constraints = operations["od"] as! Dictionary<String, AnyObject>
                    for eachConstraint in constraints.keys {
                        switch eachConstraint {
                        case "cpo": finalDecodedValue += " UserPresence "
                        case "cup": finalDecodedValue += " DevicePasscode "
                        case "pkofn": finalDecodedValue += (constraints["pkofn"] as! Int == 1 ? " Or " : " And ")
                        case "cbio": finalDecodedValue += ((constraints["cbio"]?.count)! == 1 ? " TouchIDAny " : " TouchIDCurrentSet ")
                        default: break
                        }
                    }
                case "prp": finalDecodedValue += "ApplicationPassword"
                default: break
                }
            }
            return finalDecodedValue
        }
    }
    return "Not Applicable"
}

func determineTypeAndReturnString(value: Any?) -> String {

    if let unwrappedValue = value {
        if unwrappedValue is Data {
            if let unwrappedString = String(data: (unwrappedValue as! Data), encoding: String.Encoding.utf8) {
                return unwrappedString
            } else {
                return "[Warning] Encoding Shenanigans"
            }
        } else if unwrappedValue is NSDate {
            let dateFMT = DateFormatter()
            dateFMT.dateFormat = "MMM dd, yyyy, hh:mm:ss zzz"
            return dateFMT.string(from: unwrappedValue as! Date)
        }
        switch (unwrappedValue as! String) {
        case "ak": return "kSecAttrAccessibleWhenUnlocked"
        case "ck": return "kSecAttrAccessibleAfterFirstUnlock"
        case "dk": return "kSecAttrAccessibleAlways"
        case "aku": return "kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
        case "cku": return "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"
        case "dku": return "kSecAttrAccessibleAlwaysThisDeviceOnly"
        case "akpu": return "kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly"
        case "": return ""
        default: return (unwrappedValue as! String)
        }
    } else {
        return ""
    }
}

func canonicalizeTypesInReturnedDicts(items: [Dictionary<String, Any>]) -> [Dictionary<String, String>] {

    var dict = Dictionary<String, String>()
    var arrayOfDict = [Dictionary<String, String>]()

    for eachDict in items {
        dict["Account"] = determineTypeAndReturnString(value: eachDict[kSecAttrAccount as String])
        dict["Service"] = determineTypeAndReturnString(value: eachDict[kSecAttrService as String])
        dict["Access Group"] = determineTypeAndReturnString(value: eachDict[kSecAttrAccessGroup as String])
        dict["Creation Time"] = determineTypeAndReturnString(value: eachDict[kSecAttrCreationDate as String])
        dict["Modification Time"] = determineTypeAndReturnString(value: eachDict[kSecAttrModificationDate as String])
        dict["Protection"] = determineTypeAndReturnString(value: eachDict[kSecAttrAccessible as String])
        dict["Data"] = determineTypeAndReturnString(value: eachDict[kSecValueData as String])
        dict["AccessControl"] = decodeSecAccessControl(sacObj: eachDict[kSecAttrAccessControl as String])

        arrayOfDict.append(dict)
    }

    return arrayOfDict
}

func search(for query: String, in items: [Dictionary<String, String>]) -> [Dictionary<String, String>] {

    var finalItems = [Dictionary<String, String>]()

    for eachItem in items {
        let predicate = NSPredicate(format: "Account CONTAINS[cd] %@ OR Service CONTAINS[cd] %@ OR EntitlementGroup CONTAINS[cd] %@ OR Protection CONTAINS[cd] %@", query, query, query, query)

        if predicate.evaluate(with: eachItem) {
            finalItems.append(eachItem)
        }
    }

    return finalItems
}

func convertToJSON(for items: [Dictionary<String, String>]) -> String {
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: items, options: JSONSerialization.WritingOptions.prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
            NSLog("convertToJSON() -> Error converting keychain dump to JSON.")
            exit(EXIT_FAILURE)
        }
        return jsonString
    } catch let error as NSError {
        return "Error: \(error.domain)"
    }
}

func decodeIfBase64(for userData: String) -> String {
    if let decodedData = Data(base64Encoded: userData, options: Data.Base64DecodingOptions.ignoreUnknownCharacters) {
        if let decodedString = String(data: decodedData, encoding: String.Encoding.utf8) {
            return decodedString
        }
    }
    return userData
}
