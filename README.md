# keychaineditor
KeychainEditor is a CLI to interact with iOS's [Keychain](https://developer.apple.com/library/ios/documentation/Security/Conceptual/keychainServConcepts/01introduction/introduction.html) on a jailbroken iDevice. Keychain is a secure storage provided by the iOS to save client-side secrets/certificates onto the device. KeychainEditor is useful to dump/edit/delete a keychain item. The tool will greatly help pentesters and security researches alike who would want to poke at application's keychain usage during iOS APT (Application Penetration Test). It should be noted that the tool currently supports Generic Passwords (Genp) only and can decode the new constrainsts applied on an item.

## Talk

For more information on the journey in decoding the `SecAccessControl` flags.

Slides: [bsides_ROC_2016-04-23.pdf](https://github.com/NitinJami/slides/blob/master/bsides_ROC_2016-04-23.pdf)

Video: [Exploring SecAccessControl Obj in iOS 9 Keychain](https://www.youtube.com/watch?v=JLwS-QZ2kWU)

## Features
1. Support for iOS8+ and the new changes in Keychain. Completely re-written in Swift.

2. Can now dump the actual `kSecAttrAccessControl` constraints used on a keychain item. (https://developer.apple.com/reference/security/secaccesscontrolcreateflags)

3. A search feature to limit the output to only what the user desired for. The search can be performed on Account, Service, AccessGroup or Accessibility values.
  * **./keychaineditor -f "WhenUnlocked"**

4. While updating the data for a keychain item using the `Edit` (-e) command. You can either pass a STRING or base64 encoded values for complex data.

4. Works with [idb!](http://www.idbtool.com/blog/2015/04/20/new-keychain-editor/)

*Note:* Please check --help command for more options/examples.

## Usage

**Attention:** command line arguments have been changed for simplicity.

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
 * Search is from the following group {Account, Service, AccessGroup, Protection} and is case in-sensitive.
EXAMPLES:
 * To Dump entire keychain: $ keychaineditor
 * Limit dump by searching: $ keychaineditor -f "test"
 * Edit a keychain item:    $ keychaineditor -e --account "TestAccount" --service "TestService" --data "TestData"
 * Delete a keychain item:  $ keychaineditor -d --account "TestAccount" --service "TestService"
```

## Installation

Recommended approach is to install using the `dpkg` command. SCP the .deb file into the device and run the following command:

`dpkg -i keychaineditor.deb`

To Un-install:

`dpkg -r com.nitin.keychaineditor`

*Note:* For manual installation, iOS devices do not come with Swift Runtime dylibs. You need to manually copy them to the device with the binary. The required frameworks are included in the repository.

## Build Notes

To build the tool, Run 'make' in the current directory. The final outcome will be a `.deb` package.

*Note:* You should have xcode command line tools installed for the toolchain.

*Note:* You should also have `ldid` and `dpkg-deb` (can be instaled via Homebrew).

The tool is currently only built for 64-bit architectures. However, it is very easy to build for 32-bit arch as well. Just modify the `ARCH_FLAGS` and `TARGET` in Makefile with corresponding 32-bit arch values.

```
ARCH_FLAGS      =  -arch armv7s
TARGET          =  -target armv7s-apple-ios9
```
