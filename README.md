# keychaineditor
KeychainEditor is a CLI to interact with iOS's [Keychain](https://developer.apple.com/library/ios/documentation/Security/Conceptual/keychainServConcepts/01introduction/introduction.html) on a jailbroken iDevice. Keychain is a secure storage provided by the iOS to save client-side secrets/certificates onto the device. KeychainEditor is useful to dump/edit/delete a keychain item. The tool will greatly help pentesters and security researches alike who would want to poke at application's keychain usage during iOS APT (Application Penetration Test). It should be noted that the tool currently supports Generic Passwords (Genp) only. Support for Internet Passwords and Certificates will soon be added!

## Features
1. Support for iOS8+ and the new changes in Keychain.

2. A Minimal dump of the keychain, which only outputs AccountNames and ServiceNames.
  * **./keychaineditor --action min-dump**

3. A search feature to limit the output to only what the user desired for. The search can be performed on Account, Service, AccessGroup or Accessibility values.
  * **./keychaineditor --action dump --find "WhenUnlocked"**

4. Works with [idb!](http://www.idbtool.com/blog/2015/04/20/new-keychain-editor/)

*Note:* Please check --help command for more options/examples.

## Build Notes

1. To build the tool, Run 'make' in the current directory.<br/>
Note: You should have xcode command line tools installed for the toolchain.

2. Creating Symlinks:<br/> 
Always properly check that you have symlinks for 'sdk' and 'toolchain' in the current directory.
 * To find the exact SDK installed on your machine, type the following command:<br/>
   **$ xcodebuild -showsdks**<br/>
 * To get the actual path of the SDK:<br/>
   **$ xcrun -sdk iphoneos8.2 --show-sdk-path**
 * For example, you should see something like this after you have created symlinks:<br/>
   **$ toolchain -> /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/**<br/>
   **$ sdk -> /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.2.sdk**

3. Make errors:<br/>
You may have a lower sdk version installed on your machine, and the makefile will not be able to 
find the exact path for the SDK installed. Follow the above steps to find the SDK installed 
and update it with the appropriate SDK version for the *'isysroot'* flag.

4. Error Code -34018:<br/>
The above error code is caused because you did not code sign the binary and did not provide 
the keychain access entitlements.<br/>
**$ codesign -fs "YOUR_SELF_SIGNED_CERT" --entitlements entitlements.xml keychaineditor**
 * To get a list of certificates that are already available in your keychain to sign your binary, you can use the following command:<br/>
   **$ security find-identity -v -p codesigning**
