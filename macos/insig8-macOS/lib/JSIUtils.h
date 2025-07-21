#ifndef JSIUtils_h
#define JSIUtils_h

#import <jsi/jsi.h>

namespace insig8 {

namespace jsi = facebook::jsi;

NSString* jsiValueToNSString(jsi::Runtime &rt, const jsi::Value &v);
double jsiValueToDouble(jsi::Runtime &rt, const jsi::Value &v);
NSDate* jsiValueToNSDate(jsi::Runtime &rt, const jsi::Value &v);
jsi::Value NSDateToJsiValue(jsi::Runtime &rt, NSDate* date);
jsi::Value NSStringToJsiValue(jsi::Runtime &rt, NSString* v);

}

#endif /* JSIUtils_h */
