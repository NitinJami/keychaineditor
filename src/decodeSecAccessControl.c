#include <stdio.h>
#include "bridgingheader.h"
#include <MacTypes.h>
#include <CoreFoundation/CoreFoundation.h>

CFDictionaryRef getOperations(SecAccessControlRef access_control) {
    CFDictionaryRef ops = (CFDictionaryRef)CFDictionaryGetValue(access_control->dict, CFSTR("acl"));
    return ops;
}
