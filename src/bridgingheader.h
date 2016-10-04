#ifndef bridgingheader_h
#define bridgingheader_h
#endif

#import <Security/Security.h>
#import "SecAccessControlPriv.h"
#import "CFRuntime.h"

struct __SecAccessControl {
    CFRuntimeBase _base;
    CFMutableDictionaryRef dict;
};

CFDictionaryRef getOperations(SecAccessControlRef access_control);
