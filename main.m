//
//  main.m
//  KeychainEditor
//
//  Created by Nitin Jami on 3/26/15.
//  Copyright (c) 2015 NCC Group. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

/*
 Undocumented functions that are used by the keychain. I need to declare these functions
 in order to use in my tool. Not all three functions are useful now except for 
 SecAccessControlGetConstraints() which returns a Dict containing a value for 
 UserPresence. I will leave the other two functions for future use.
 
 https://opensource.apple.com/source/Security/Security-57031.1.35/Security/sec/Security/SecItem.c
 */

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000

CFDictionaryRef SecAccessControlGetConstraints(SecAccessControlRef access_control);
CFTypeRef SecAccessControlGetProtection(SecAccessControlRef access_control);
CFDataRef SecAccessControlCopyData(SecAccessControlRef access_control);

#endif

/*
 The flag will help in determining, if idb has called or it was command line invocation.
 The primary difference for idb version is kSecValueData needs to be in base64, whether 
 it is editing an item or dumping the keychain. For a command line invocation, for the
 sake of user expierence I would go with strings.
 TODO: I haven't implemented this yet.
 */
unsigned int IF_IDB = 0;

/*
 Function that prints out usage information when a --help command
 is passed as the first argument of cmd line.
 */

void printUsage() {
    
    fprintf(stdout, "\n\e[4;30mUsage:\e[0;31m ./keychaineditor commands \
          \n\e[4;30mCommands can be:\e[0;31m\
          \n\t--help:    Prints the usage.\
          \n\t--action:  Can be either min-dump, dump, edit, delete.\
          \n\t--find:    uses 'CONTAINS' to find strings from the dump.\
          \n\t--account: Account name for the keychain item you want to edit/delete.\
          \n\t--service: Service name for the keychain item you want to edit/delete.\
          \n\t--agroup:  Optional. Access group for the keychain item you want to edit/delete. \
          \n\t--data:    Base64 encoded data that is used to update the keychain item.\
          \n\e[0;32mAccount and service is used to uniquely identify a keychain item.\
          \n\e[0;32mNote: If there is no account name, pass a '' string.\
          \n\e[0;32mNote: --find is an optional command for dump. It search from\
          \n\e[0;32m{Account, Service, EntitlementGroup, Protection}.\
          \n\e[4;30mExamples:\e[0;31m\
          \n\t./keychaineditor --action dump --find XXX\
          \n\tOr\
          \n\t./keychaineditor --action delete --account XXX --service XXX\
          \n\tOr\
          \n\t./keychaineditor --action edit --account XXX --service XXX --data XXX\
          \e[0;30m\n\n");
    
    return;
    
}


/*
 Function to convert OSStatus to human readable error messages.
 I need to do this because iOS does not support SecCopyErrorMessageString()
 
 TODO: I am only converting codes that I think are apt for my tool, I will
 update as and when required, if I encounter anything new.
 */

OSStatus osstatusToHumanReadableString(OSStatus status) {
    
    switch (status) {
        case errSecSuccess:
            fprintf(stdout, "\e[0;32mOperation successfully completed.\e[0;30m\n");
            break;
        case errSecItemNotFound:
            fprintf(stderr, "\e[0;31mThe specified item could not be found in the keychain.\e[0;30m\n");
            break;
        case errSecAuthFailed:
            fprintf(stderr, "\e[0;31mDid you turn off the passcode on device? The item is no longer available.\e[0;30m\n");
            fprintf(stderr, "\e[0;31mIf that is not the case, UserPresence is required. Check your device for the prompt.\e[0;30m\n");
            break;
        case errSecInteractionNotAllowed:
            fprintf(stderr, "\e[0;31mDevice Locked. Cannot dump WhenUnlocked or WhenPasscodeSet items.\e[0;30m\n");
            break;
        case -34018:
            fprintf(stderr, "\e[0;31mError: Client has neither application-identifier nor keychain-access-groups entitlements. Please refer README for further instructions.\e[0;30m\n");
            break;
            
        default:
            fprintf(stderr, "\e[0;31mUnhandled Error: Please contact developer to report this error. Error code: %d\e[0;30m\n", (int)status);
            break;
    }
    
    return status;
}


/*
 Helper function that converts pdmn values to Accessible constants
 and stringify the constant.
 */

NSString *mapKeychainConstants(NSString *pdmn) {
    
    if ([pdmn isEqualToString:@"ak"])
        return @"kSecAttrAccessibleWhenUnlocked";
    else if ([pdmn isEqualToString:@"ck"])
        return @"kSecAttrAccessibleAfterFirstUnlock";
    else if ([pdmn isEqualToString:@"dk"])
        return @"kSecAttrAccessibleAlways";
    else if ([pdmn isEqualToString:@"aku"])
        return @"kSecAttrAccessibleWhenUnlockedThisDeviceOnly";
    else if ([pdmn isEqualToString:@"cku"])
        return @"kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly";
    else if ([pdmn isEqualToString:@"dku"])
        return @"kSecAttrAccessibleAlwaysThisDeviceOnly";
    else if ([pdmn isEqualToString:@"akpu"])
        return @"kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly";
    else
        return @"Unexpected Error";
    
}


/*
 Helper function for identifying the type of object both Account
 and Service return. Developers often just write as NSData or 
 they write as NSString.
 */
NSString* determineTypeAndReturnNSString(id accountValue) {
    
    // If NSData, convert it to NSString and return...
    if ([accountValue isKindOfClass:[NSData class]]) {
        return [[NSString alloc] initWithData:accountValue encoding:NSUTF8StringEncoding];
    }
    
    return accountValue;
}


/*
 Helper function to check if the ACL for the keychain item requires
 a UserPresence or not.
 A UserPresence further requires a form of user authentication, i.e. either 
 via TouchID or Device Passcode.
 
 TODO: I will develop this as and when Apple updates their functionality. Right
 now it's just whether a UserPresence is required or not.
 */

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000

NSString* checkUserPresence(SecAccessControlRef sacObj) {
    
    /*
     SecAccessControlGetConstraints() returns a dictionary with values 
     for UserPresence. I am not going to specifically check for that, since
     Apple's implementation of UserPresence is either you have it or 
     not, in which case it returns a null.
     
     SecAccessControlGetConstraints() is not exactly a documented API. But, 
     since Apple Open Sourced part of thier keychain implementation, I learnt
     of such methods and used here.
     
     https://opensource.apple.com/source/Security/Security-57031.1.35/Security/sec/Security/SecItem.c
     
     TODO: If the kSecAccessControl is modified later then check for exact 
     values.
     */
    
    if (SecAccessControlGetConstraints(sacObj)) {
        return @"Yes";
    }
    
    return @"No";
}

#endif

/*
 Helper function to deal with items having no data. The return value for this case is NULL.
 And NULL doesn't go well with JSON/Dictionary. https://github.com/NitinJami/keychaineditor/issues/1
 Just return a "null" string for no data and base64 encode it for idb to parse it properly.
 */
NSString* checkForNoDataValue(NSData* dataValue) {
    
    if (dataValue != NULL) {
        return [dataValue base64EncodedStringWithOptions:0];
    }
    
    return [[@"null" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}


/*
 Helper function to limit the output according to the search query
 from the --find cmd line argument. The search operation will perform 
 on Account array, Service array, Entitlement group array and Protection classes.
 */

NSMutableDictionary* limitOutputFromSearchQuery(NSMutableDictionary *dumpedDict, NSString *query) {
    
    NSMutableDictionary *limitedDict = [[NSMutableDictionary alloc] init];
    NSInteger index = 0;
    
    for (NSDictionary *topLevelIterator in [dumpedDict allValues]) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"Account CONTAINS[cd] %@ OR \
                                      Service CONTAINS[cd] %@ OR EntitlementGroup CONTAINS[cd] %@ OR \
                                      Protection CONTAINS[cd] %@", query, query, query, query];
        
        if ([predicate evaluateWithObject:topLevelIterator]) {
            [limitedDict setObject:topLevelIterator forKey:[NSString stringWithFormat:@"%lu", (unsigned long)++index]];
        }
    }
    
    return limitedDict;
}


/*
 Helper function that prepares JSON output of the keychain dump from 
 a dictionary of results.
 */

void prepareJsonOutput(NSArray *results, NSString *find) {
    
    /*
     The output will be in JSON style for other applications to easily parse it.
     The representation would be something like this:
     {
      index : {
       Account :
       Service :
       Entitlement Group :
       Creation Time :
       Modified Time :
       Protection :
       Data :
      },
      ...
     }
     
     TODO: After I get iphone 6, I should look into kSecAttrAccessControl.
     */
    
    NSMutableDictionary *parentJSON = [[NSMutableDictionary alloc] init];
    NSDictionary *eachItemFromResults = [[NSDictionary alloc] init];
    NSInteger index = 0;
    
    /*
     When this loop is finished. It will have the above JSON structure that 
     I explained in the form of dictionary within dictionary. After this, I 
     just need to JSONify it.
     */
    for (eachItemFromResults in results) {
        
        NSMutableDictionary *innerJSON = [[NSMutableDictionary alloc] init];
        
        /*
         I have encountered Account as NSData type, but mostly are NSString. I am 
         checking for thier type and then displaying the result as a string.
         In an abudance of caution, I am checking for service as well.
         */
        [innerJSON setObject:determineTypeAndReturnNSString([eachItemFromResults \
                        objectForKey:(__bridge id)kSecAttrService]) forKey:@"Service"];
        
        [innerJSON setObject:determineTypeAndReturnNSString([eachItemFromResults \
                        objectForKey:(__bridge id)kSecAttrAccount]) forKey:@"Account"];
        
        [innerJSON setObject:[NSString stringWithFormat:@"%@", \
                                [eachItemFromResults objectForKey:(__bridge id)kSecAttrAccessGroup]] \
                        forKey:@"EntitlementGroup"];
        
        [innerJSON setObject:mapKeychainConstants([eachItemFromResults \
                                                     objectForKey:(__bridge id)kSecAttrAccessible]) forKey:@"Protection"];
        
        [innerJSON setObject:[NSString stringWithFormat:@"%@", \
                                [eachItemFromResults objectForKey:(__bridge id)kSecAttrModificationDate]] \
                        forKey:@"Modified Time"];
        
        [innerJSON setObject:[NSString stringWithFormat:@"%@", \
                                [eachItemFromResults objectForKey:(__bridge id)kSecAttrCreationDate]] \
                        forKey:@"Creation Time"];
        
        [innerJSON setObject:checkForNoDataValue([eachItemFromResults objectForKey:(__bridge id)kSecValueData]) forKey:@"Data"];
        
        #if __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000
            [innerJSON setObject:checkUserPresence((__bridge SecAccessControlRef) \
                        ([eachItemFromResults objectForKey:(__bridge id)(kSecAttrAccessControl)])) forKey:@"UserPresence"];
        #else
            [innerJSON setObject:@"NA" forKey:@"UserPresence"];
        #endif
        
        [parentJSON setObject:innerJSON forKey:[NSString stringWithFormat:@"%lu", (unsigned long)++index]];
    }
    
    /*
     Should we limit the output. Check If --find has any value and perform
     appropriate search from the parentJSON dictionary.
     */
    if (find != nil) {
        parentJSON = limitOutputFromSearchQuery(parentJSON, find);
    }
    
    /*
     Okay the dictionary is set. Let's convert it to JSON object.
     */
    NSError* error = nil;
    NSData* json = nil;
    
    json = [NSJSONSerialization dataWithJSONObject:parentJSON \
                                           options:NSJSONWritingPrettyPrinted error:&error];
    
    /*
     If I have the JSON data, let's print it.
     
     TODO: Maybe send the error code back to the callee, so that the callee would know there is an error
     with JSON. It's just good practice, do it.
     */
    if (json != nil && error == nil) {
        fprintf(stdout, "%s\n", [[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] UTF8String]);
    }
    else {
        fprintf(stderr, "\n\e[0;31mInternal error when preparing JSON output. Error: %s\e[0;30m\n", [[error localizedDescription] UTF8String]);
    }
}


/*
 Helper function to just print the minimal dump.
 This would be Account, Service and Entitlement Group.
 */

void prepareMinimumOutput(NSArray *results) {
    
    NSDictionary *eachItemFromResults = [[NSDictionary alloc] init];
    NSString *account = [[NSString alloc] init];
    NSString *service = [[NSString alloc] init];
    
    fprintf(stdout, "\e[0;31mWarning: The names are truncated to max width of 35 charaters. Please use this dump as a reference, and use --find to get full details.\n\e[0;30m");
    
    // Prettify the output.
    fprintf(stdout, "Account%28s | Service\n", "");
    fprintf(stdout, "%s | %s\n", [[@"" stringByPaddingToLength:35 withString:@"-" startingAtIndex:0] UTF8String], \
            [[@"" stringByPaddingToLength:35 withString:@"-" startingAtIndex:0] UTF8String]);
    
    // This is simple iterate through the results and print out Account and Service.
    for (eachItemFromResults in results) {
        
        service = determineTypeAndReturnNSString([eachItemFromResults objectForKey:(__bridge id)kSecAttrService]);
        account = determineTypeAndReturnNSString([eachItemFromResults objectForKey:(__bridge id)kSecAttrAccount]);
        
        /*
         %*.* --> allows to specify the width and precision for a string.
         width = -35 --> tells the field width is 35, if the string is smaller than 35 in 
         length, trailling spaces are added. Hence, the negative 35.
         precision = 35 --> restricts the string to be printed to only 35 characters in length.
         */
        fprintf(stdout, "%*.*s   %*.*s\n", -35, 35, [account UTF8String], -35, 35, [service UTF8String]);
    }
}

/*
 Function that dumps all the keychain items.
 
 TODO: Do I want to get rid of the standard apple entries.
 */

OSStatus dumpKeychain(NSString *action, NSString *find) {
    
    NSMutableDictionary* query = [[NSMutableDictionary alloc] init];
    NSMutableArray* finalResult = [[NSMutableArray alloc] init];
    
    NSString *eachConstant = [[NSString alloc] init];
    OSStatus status = 0;
    
    //NSArray *secClasses = @[(__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClassKey];
    
    NSArray *constants = @[(__bridge NSString *)kSecAttrAccessibleAfterFirstUnlock,
                           (__bridge NSString *)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                           (__bridge NSString *)kSecAttrAccessibleAlways,
                           (__bridge NSString *)kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                           (__bridge NSString *)kSecAttrAccessibleAlwaysThisDeviceOnly,
                           (__bridge NSString *)kSecAttrAccessibleWhenUnlocked,
                           (__bridge NSString *)kSecAttrAccessibleWhenUnlockedThisDeviceOnly];
    
    /*
     Prepare a query to dump all the items.
     Class = Generic Password.
     kSecMatchLimit = kSecMatchLimitAll, will actually dump all the items.
     kSecReturnAttributes = True, will return the Attributes associated with the item.
     kSecReturnData = True, will return the data associated with the item.
     
     TODO: I am just dealing with genp class of items, if a requirment occurs
     to other items like inetp, certs, I will extend it.
     */
    
    for (eachConstant in constants) {
        
        [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
        [query setObject:eachConstant forKey:(__bridge id<NSCopying>)(kSecAttrAccessible)];
        [query setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
        [query setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
        [query setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
        
        /*
         On success, a dictionary of all the items are returned.
         */
        CFTypeRef results = nil;
        
        status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &results);
        
        if (status == errSecSuccess) {
            
            [finalResult addObjectsFromArray: (__bridge NSArray *)results];
        }
    }
    
    /*
     Handling the return status would be bit diffrent from other actions.
     On Success, I should print out the items instead of "Operation completed" message.
     On Failure, regular call to osstatusToHumanReadableString() is called.
     */
    if ([finalResult count] != 0) {
        if ([action isEqualToString:@"min-dump"]) {
            prepareMinimumOutput(finalResult);
        }
        else {
            prepareJsonOutput(finalResult, find);
        }
    }
    else {
        status = osstatusToHumanReadableString(status);
    }
    
    return status;
}


/*
 Function that queries an item in keychain and updates the item value.
 Account and service are used to uniquely identify an item.

 TODO: To identify an item uniquely {Account, Service} tuple is more
 than enough on most cases. There may be a case occasionaly where there
 might be two entries with the same {Accoubt, Service} tuple. This happens
 espcially when dealing with enterprise app store. So, in this case
 {Account, Service, AccessGroup} 3-tuple is necessary to uniquely identify
 an item. For the sake of user experience, I am going with an optional --agroup
 command. So, users do not have to pass --agroup everytime.
 If a need arises in furture, that agroup be mandatory. I will change it.
 */

OSStatus editKeychainItem(NSString* account, NSString* service, NSString* agroup, NSData* data) {
    
    NSMutableDictionary* query = [[NSMutableDictionary alloc] init];
    
    /*
     Prepare a query for SecItemUpdate().
     Class = Generic Password.
     Account = account name provided by the user from cmd line.
     Service = service name provided by the user from cmd line.
     AccessGroup = Optional. access group name by the user from cmd line.
     
     TODO: I am just dealing with genp class of items, if a requirment occurs
     to other items like inetp, certs, I will extend it.
     */
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:service forKey:(__bridge id)kSecAttrService];
    if (agroup != nil) {
        [query setObject:agroup forKey:(__bridge id<NSCopying>)(kSecAttrAccessGroup)];
    }
    
    /*
     Prepare the second parameter for SecItemUpdate().
     kSecValueData = data provided by the user from cmd line.
     */
    NSDictionary* updateValue = [NSDictionary dictionaryWithObjectsAndKeys: \
                                 (id)data, (__bridge id)kSecValueData, nil];
    
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, \
                                    (__bridge CFDictionaryRef)updateValue);
    
    /*
     Handle the return status.
     */
    status = osstatusToHumanReadableString(status);
    
    return status;
    
}


/*
 Function that queries an item in keychain and deletes the item.
 Account and service are used to uniquely identify an item.
 
 TODO: To identify an item uniquely {Account, Service} tuple is more
 than enough on most cases. There may be a case occasionaly where there
 might be two entries with the same {Accoubt, Service} tuple. This happens
 espcially when dealing with enterprise app store. So, in this case 
 {Account, Service, AccessGroup} 3-tuple is necessary to uniquely identify 
 an item. For the sake of user experience, I am going with an optional --agroup
 command. So, users do not have to pass --agroup everytime.
 If a need arises in furture, that agroup be mandatory. I will change it.
 */

OSStatus deleteKeychainItem(NSString* account, NSString* service, NSString* agroup) {
    
    NSMutableDictionary* query = [[NSMutableDictionary alloc] init];
    
    /*
     Prepare a query for SecItemDelete().
     Class = Generic Password.
     Account = account name provided by the user from cmd line.
     Service = service name provided by the user from cmd line.
     AccessGroup = Optional. access group name by the user from cmd line.
     
     TODO: I am just dealing with genp class of items, if a requirment occurs
     to other items like inetp, certs, I will extend it.
     */
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:service forKey:(__bridge id)kSecAttrService];
    if (agroup != nil) {
        [query setObject:agroup forKey:(__bridge id<NSCopying>)(kSecAttrAccessGroup)];
    }
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    /*
     Handle the return status.
     */
    status = osstatusToHumanReadableString(status);
    
    return status;
}


// FOR TESTING PURPOSES.

/*
void additem() {
    
    NSMutableDictionary *attrbs = [[NSMutableDictionary alloc] init];
    
    [attrbs setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [attrbs setObject:@"testaccount" forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [attrbs setObject:@"testservice" forKey:(__bridge id<NSCopying>)(kSecAttrService)];
    [attrbs setObject:(__bridge id)(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) forKey:(__bridge id<NSCopying>)(kSecAttrAccessible)];
    //[attrbs setObject:[@"testing" dataUsingEncoding:NSUTF8StringEncoding] forKey:(__bridge id<NSCopying>)(kSecValueData)];
    
    //SecAccessControlRef sac = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, kSecAccessControlUserPresence, nil);
    
    //[attrbs setObject:(__bridge id)(sac) forKey:(__bridge id<NSCopying>)(kSecAttrAccessControl)];
    
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)(attrbs), nil);
    
    status = osstatusToHumanReadableString(status);
    
    return;
}*/

int main(int argc, char *argv[]) {
    @autoreleasepool {
        
        /*
         Let's check what we have for cmd line arguments.
         */
        if (argc < 2) {
            printUsage();
            return EXIT_FAILURE;
        }
        
        if ([[NSString stringWithFormat:@"%s", argv[1]] isEqualToString:@"--help"]) {
            printUsage();
            return EXIT_SUCCESS;
        }
        
        /*
         The first argument should either be --help or --action. I have already taken
         care for --help; will deal with --action here.
         */
        
        if (![[NSString stringWithFormat:@"%s", argv[1]] isEqualToString:@"--action"]) {
            fprintf(stderr, "\e[0;31mInvalid command passed as first argument. Please use --help to get usage information.\e[0;30m");
            return EXIT_FAILURE;
        }
        
        /*
         Use the NSUserDefaults to process the cmd line args instead 
         of manually dealing with argv. Note that NSUserDefaults adds a '-' before
         the string we specified. So, '-action' becomes '--action'. Also, I don't 
         need to deal with the order in which commands are passed, expect anyways
         '--action' is the first command.
         This also allows me to only process commands I want for. Garbage commands
         will not enter into my program. YOU HACKERS.
         */
        NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
        
        NSString *action = [args stringForKey:@"-action"];
        NSString *acct = [args stringForKey:@"-account"];
        NSString *srvc = [args stringForKey:@"-service"];
        NSString *data = [args stringForKey:@"-data"];
        NSString *find = [args stringForKey:@"-find"];
        NSString *agroup = [args stringForKey:@"-agroup"];
        
        // FOR TESTING PURPOSES.
        
        if ([action isEqualToString:@"test"]) {
            //additem();
            NSLog(@"%d", __IPHONE_OS_VERSION_MIN_REQUIRED);
            return EXIT_SUCCESS;
        }
        
        /*
         '--action' can only be min-dump, dump, edit or delete.
         */
        
        if (![@[@"min-dump", @"dump", @"edit", @"delete"] containsObject:action]) {
            fprintf(stderr, "\e[0;31mInvalid action passed. Please use --help to get usage information.\n\e[0;30m");
            return EXIT_FAILURE;
        }
        
        /*
         At this point I should have valid action command, let's call appropriate functions.
         --find is used to narrow down the keychain dump.
         */
        
        if ([action isEqualToString:@"dump"] || [action isEqualToString:@"min-dump"]) {
            
            if (errSecSuccess != dumpKeychain(action, find)) {
                return EXIT_FAILURE;
            }
        }
        else if ([action isEqualToString:@"edit"]) {
            
            /*
             Edit should have account, service and data commands.
             */
            
            if ( (acct == nil) || (srvc == nil) || (data == nil) ) {
                fprintf(stderr, "\e[0;31mEdit requires account, service and data. Please use --help to get usage information.\n\e[0;30m");
                return EXIT_FAILURE;
            }
            
            /*
             Decode the base64 encoded data that I accept. I only accept base64 because
             no information will be lost when the data is in xml format, or some other format other than
             a string.
             TODO: I know this is painful when dealing with simple strings. I will deal with 
             this when I have better understanding on how can differentiate base64 data with
             simple ascii string.
             */
            
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
            
            if (decodedData == nil) {
                fprintf(stderr, "\e[0;31mData only accepts base64 strings. Please use --help to get usage information.\n\e[0;30m");
                return EXIT_FAILURE;
            }
            
            if (errSecSuccess != editKeychainItem(acct, srvc, agroup, decodedData)) {
                return EXIT_FAILURE;
            }
        }
        else if ([action isEqualToString:@"delete"]) {
            
            /*
             Delete should have account and service.
             */
            
            if ( (acct == nil) || (srvc == nil) ) {
                fprintf(stderr, "\e[0;31mDelete requires account, service. Please use --help to get usage information.\n\e[0;30m");
                return EXIT_FAILURE;
            }
            
            if (errSecSuccess != deleteKeychainItem(acct, srvc, agroup)) {
                return EXIT_FAILURE;
            }
        }
    }
    
    return EXIT_SUCCESS;
}