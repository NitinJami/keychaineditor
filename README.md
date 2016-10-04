# keychaineditor
KeychainEditor is a CLI to interact with iOS's [Keychain](https://developer.apple.com/library/ios/documentation/Security/Conceptual/keychainServConcepts/01introduction/introduction.html) on a jailbroken iDevice. Keychain is a secure storage provided by the iOS to save client-side secrets/certificates onto the device. KeychainEditor is useful to dump/edit/delete a keychain item. The tool will greatly help pentesters and security researches alike who would want to poke at application's keychain usage during iOS APT (Application Penetration Test). It should be noted that the tool currently supports Generic Passwords (Genp) only. Support for Internet Passwords and Certificates will soon be added!

## Features
1. Support for iOS8+ and the new changes in Keychain. Completely re-written in Swift.

2. Can now dump the actual `kSecAttrAccessControl` constraints used on a keychain item. (https://developer.apple.com/reference/security/secaccesscontrolcreateflags)

3. A search feature to limit the output to only what the user desired for. The search can be performed on Account, Service, AccessGroup or Accessibility values.
  * **./keychaineditor -f "WhenUnlocked"**

4. While updating the data for a keychain item using the `Edit` (-e) command. You can either pass a STRING or base64 encoded values for complex data.

4. Works with [idb!](http://www.idbtool.com/blog/2015/04/20/new-keychain-editor/)

*Note:* Please check --help command for more options/examples.

## Usage

```
USAGE: keychaineditor [commands]
Commands Description
  -v     version
  -f     Search. Requires a query string as the second argument.
  -e     Edit. Requires --account STRING --service STRING [--agroup STRING] --data (STRING or Base64)
  -d     Delete. Requires --account STRING --service STRING [--agroup STRING]
NOTES:
 * Account and Service names are used to uniquely identify a item. An optional AccessGroup can also be passed to identify the item.
 * If there is no Account name pass an empty string.
 * Search is from the following group {Account, Service, AccessGroup, Protection}
```

## Build Notes

1. To build the tool, Run 'make' in the current directory.

Note: You should have xcode command line tools installed for the toolchain.

Note: You should also have `ldid` and `dpkg-deb`.
