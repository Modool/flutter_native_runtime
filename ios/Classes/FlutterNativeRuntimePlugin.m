#import <objc/runtime.h>

#import "FlutterNativeRuntimePlugin.h"

typedef NS_ENUM(NSUInteger, FlutterNativeRuntimeTargetType) {
    FlutterNativeRuntimeTargetTypeGlobal,
    FlutterNativeRuntimeTargetTypeClass,
    FlutterNativeRuntimeTargetTypeMethod,
    FlutterNativeRuntimeTargetTypeProperty,
    FlutterNativeRuntimeTargetTypeVariable,
};

static NSString * const FlutterNativeRuntimePluginMethodInvoke = @"invoke";
static NSString * const FlutterNativeRuntimePluginMethodKeep = @"keep";
static NSString * const FlutterNativeRuntimePluginMethodDispose = @"dispose";

@implementation FlutterNativeRuntimePlugin {
    FlutterMethodChannel *_channel;
    
    NSMutableDictionary<NSString *, id> *_cache;
    NSDictionary<NSString *, id> *_globalInstances;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel
               methodChannelWithName:@"com.modool.flutter/plugins/flutter_native_runtime"
               binaryMessenger:[registrar messenger]];
    FlutterNativeRuntimePlugin *plugin = [[FlutterNativeRuntimePlugin alloc] init];
    plugin->_channel = channel;
    
    [registrar addMethodCallDelegate:plugin channel:channel];
}

- (instancetype)init {
    if (self = [super init]) {
        _cache = [NSMutableDictionary dictionary];
        _globalInstances = @{
#if TARGET_OS_OSX
            @"NSScreen": NSScreen.mainScreen,
            @"NSApplication": NSApplication.sharedApplication,
#else
            @"UIScreen": UIScreen.mainScreen,
            @"UIDevice": UIDevice.currentDevice,
            @"UIApplication": UIApplication.sharedApplication,
            @"UIMenuController": UIMenuController.sharedMenuController,
#endif
            @"NSBundle": NSBundle.mainBundle,
            @"NSProcessInfo": ^id (void) {
                return NSProcessInfo.processInfo;
            },
            @"NSFileManager": NSFileManager.defaultManager,
            @"NSUserDefaults": NSUserDefaults.standardUserDefaults,
            @"NSNotificationCenter": NSNotificationCenter.defaultCenter,
            @"NSCalendar": NSCalendar.currentCalendar,
            @"NSTimeZone": NSTimeZone.defaultTimeZone,
        };
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    id args = call.arguments;
    
    FlutterError *error = nil;
    id object = nil;
    if ([FlutterNativeRuntimePluginMethodInvoke isEqualToString:call.method]) {
        object = [self _invoke:args error:&error];
    } else if ([FlutterNativeRuntimePluginMethodKeep isEqualToString:call.method]) {
        object = [self _keep:args error:&error];
    } else if ([FlutterNativeRuntimePluginMethodDispose isEqual:call.method]) {
        [self _dispose:args];
    } else {
        result(FlutterMethodNotImplemented);
        return;
    }
    result(error ?: object);
}

- (id)_gloalInstanceByName:(NSString *)name {
    id target = _globalInstances[name];
    if ([NSStringFromClass([target class]) containsString:@"Block"]) {
        id (^block)(void) = target;
        return block();
    }
    
    return target;
}

- (id)_invoke:(NSDictionary *)dictionary error:(FlutterError **)errorPtr {
    NSError *error = nil;
    id result = [self _invokeWithDictionary:dictionary error:&error];
    if (!error) return result;
    if (errorPtr) *errorPtr = [FlutterError errorWithCode:@(error.code).stringValue message:error.localizedDescription details:error.userInfo.description];
    
    return nil;
}

- (id)_keep:(NSDictionary *)dictionary error:(FlutterError **)errorPtr {
    NSString *uuid = dictionary[@"id"];
    
    NSError *error = nil;
    id result = [self _invokeWithDictionary:dictionary error:&error];
    
    if (!error && result) _cache[uuid] = result;
    if (error && errorPtr) *errorPtr = [FlutterError errorWithCode:@(error.code).stringValue message:error.localizedDescription details:error.userInfo.description];
    
    return nil;
}

- (void)_dispose:(NSString *)uuid {
    [_cache removeObjectForKey:uuid];
}

- (NSError *)_errorResultWithMessage:(NSString *)message {
    return [NSError errorWithDomain:@"com.modool.flutter.native.runtime.plugin" code:0 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (id)_invokeWithDictionary:(NSDictionary *)dictionary error:(NSError **)errorPtr {
    //    'n': _name,
    //    't': _type.index,
    //    'a': _arguments ?? [],
    //    'p': map
    //    'id': uuid
    
    NSString *name = dictionary[@"n"];
    if (!name.length) {
        if (errorPtr != NULL) *errorPtr = [self _errorResultWithMessage:@"Target name can't be empty"];
        return nil;
    }

    NSString *uuid = dictionary[@"id"];
    if ([_cache.allKeys containsObject:uuid]) return _cache[uuid];

    NSArray *arguments = dictionary[@"a"];
    NSDictionary *parent = dictionary[@"p"];
    FlutterNativeRuntimeTargetType type = [dictionary[@"t"] integerValue];

    id target = nil;
    if (parent != nil) {
        NSError *error = nil;
        target = [self _invokeWithDictionary:parent error:&error];
        if (error) {
            if (errorPtr) *errorPtr = error;
            return nil;
        }
        return [self _invokeWithTarget:target type:type name:name arguments:arguments error:errorPtr];
    } else {
        if (type != FlutterNativeRuntimeTargetTypeGlobal && type != FlutterNativeRuntimeTargetTypeClass) {
            if (errorPtr != NULL) *errorPtr = [self _errorResultWithMessage:@"No implementation."];
            return nil;
        }
        
        target = type == FlutterNativeRuntimeTargetTypeGlobal ? [self _gloalInstanceByName:name] : NSClassFromString(name);
        if (!target) {
            if (errorPtr != NULL) *errorPtr = [self _errorResultWithMessage:[NSString stringWithFormat:@"Can't find an target named %@", name]];
            return nil;
        }
    }
    
    return target;
}

- (id)_invokeWithTarget:(id)target type:(FlutterNativeRuntimeTargetType)type name:(NSString *)name arguments:(NSArray *)arguments error:(NSError **)errorPtr {
    switch (type) {
        case FlutterNativeRuntimeTargetTypeMethod: return [self _invokeWithTarget:target methodName:name arguments:arguments error:errorPtr];
        case FlutterNativeRuntimeTargetTypeProperty: return [self _invokePropertyWithTarget:target propertyName:name arguments:arguments error:errorPtr];
//        case FlutterNativeRuntimeTargetTypeVariable: return [self _invokeIvarWithTarget:target ivarName:name arguments:arguments error:errorPtr];
        default: {
            if (errorPtr != NULL) *errorPtr = [self _errorResultWithMessage:@"No implementation."];
            return nil;
        }
    }
}

- (id)_invokePropertyWithTarget:(id)target propertyName:(NSString *)propertyName arguments:(NSArray *)arguments error:(NSError **)errorPtr {
    if (arguments.count) {
        id value = arguments.firstObject;
        BOOL valid = [target validateValue:&value forKeyPath:propertyName error:errorPtr];
        if (valid) [target setValue:value forKeyPath:propertyName];
    } else {
        return [target valueForKeyPath:propertyName];
    }
    return nil;
}

- (NSInvocation *)_invocationWithTarget:(id)target methodName:(NSString *)methodName arguments:(NSArray *)arguments {
    arguments = [arguments isKindOfClass:NSArray.class] ? arguments : @[arguments ?:NSNull.null];

    Class class = [target class];
    BOOL isClassMethod = class == target;

    Method method = [self _methodInClass:[target class] isClassMethod:isClassMethod forName:methodName];
    if (!method) return nil;

    return [self _invocationFromMethod:method arguments:arguments];
}

- (id)_invokeWithTarget:(id)target methodName:(NSString *)methodName arguments:(NSArray *)arguments error:(NSError **)error {
    NSInvocation *invocation = [self _invocationWithTarget:target methodName:methodName arguments:arguments];
    if (!invocation) {
        if (error) *error = [self _errorResultWithMessage:[NSString stringWithFormat:@"Can't find method %@", methodName]];
        return nil;
    }

    [invocation retainArguments];
    [invocation invokeWithTarget:target];

    return [self _returnObjectOfInvocation:invocation];
}

- (NSInvocation *)_invocationFromMethod:(Method)method arguments:(NSArray *)arguments {
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = method_getName(method);

    NSUInteger actualArgumentsCount = arguments.count;
    NSUInteger requiredArgumentsCount = signature.numberOfArguments;

    for (int i = 2; i < requiredArgumentsCount; i++) {
        if ((i - 2) >= actualArgumentsCount) break;

        id argument = arguments[i - 2];
        argument = argument == NSNull.null ? nil : argument;

        [self _setInvocationArgument:invocation index:i value:argument];
    }
    return invocation;
}

- (Method)_methodInClass:(Class)class isClassMethod:(BOOL)isClassMethod forName:(NSString *)name {
    SEL selector = NSSelectorFromString(name);
    Method method = NULL;
    if (isClassMethod) {
        method = class_getClassMethod(class, selector);
    } else {
        method = class_getInstanceMethod(class, selector);
    }

    if (method != NULL) return method;

    Class superClass = class_getSuperclass(class);
    if (superClass) return [self _methodInClass:superClass isClassMethod:isClassMethod forName:name];

    return NULL;
}


#define INVOCATION_SET_RETURN_NUMBER_VALUE(ENCODING, TYPE, DEFAULT)   \
INVOCATION_SET_RETURN(ENCODING, TYPE, DEFAULT, @(value))

#define INVOCATION_SET_RETURN_VALUE(ENCODING, TYPE, DEFAULT, VALUE_METHOD)   \
INVOCATION_SET_RETURN(ENCODING, TYPE, DEFAULT, [NSValue VALUE_METHOD:value])

#define INVOCATION_SET_RETURN_OBJECT(ENCODING, TYPE, DEFAULT)           \
INVOCATION_SET_RETURN(ENCODING, TYPE, DEFAULT, value)

#define INVOCATION_SET_RETURN(ENCODING, TYPE, DEFAULT, RESULT)          \
(strcmp(ENCODING, @encode(TYPE)) == 0) {                             \
    TYPE value = DEFAULT;                                               \
    [invocation getReturnValue:&value];                                 \
    return RESULT;                                                     \
}

- (id)_returnObjectOfInvocation:(NSInvocation *)invocation {
    const char *type = invocation.methodSignature.methodReturnType;

    if (strcmp(type, @encode(void)) == 0) return nil;
    else if (strcmp(type, @encode(id)) == 0) {
        void *value = NULL;
        if (invocation.methodSignature.methodReturnLength) {
            [invocation getReturnValue:&value];
        }
        return (__bridge id)value;
    }
    else if INVOCATION_SET_RETURN_VALUE(type, CGPoint, CGPointZero, valueWithCGPoint)
    else if INVOCATION_SET_RETURN_VALUE(type, CGSize, CGSizeZero, valueWithCGSize)
    else if INVOCATION_SET_RETURN_VALUE(type, CGRect, CGRectZero, valueWithCGRect)
    else if INVOCATION_SET_RETURN_VALUE(type, CGVector, CGVectorMake(0, 0), valueWithCGVector)
    else if INVOCATION_SET_RETURN_VALUE(type, CGAffineTransform, CGAffineTransformIdentity, valueWithCGAffineTransform)
    else if INVOCATION_SET_RETURN_VALUE(type, UIOffset, UIOffsetZero, valueWithUIOffset)
    else if INVOCATION_SET_RETURN_VALUE(type, UIEdgeInsets, UIEdgeInsetsZero, valueWithUIEdgeInsets)
    else if INVOCATION_SET_RETURN_VALUE(type, NSRange, NSMakeRange(0, 0), valueWithRange)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, double, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, float, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, bool, false)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, int, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, char, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, short, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, long, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, unsigned int, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, unsigned char, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, unsigned short, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, unsigned long, 0)
    else if INVOCATION_SET_RETURN_NUMBER_VALUE(type, unsigned long long, 0)
    else if (@available(iOS 11, *)) {
        if INVOCATION_SET_RETURN_VALUE(type, NSDirectionalEdgeInsets, NSDirectionalEdgeInsetsZero, valueWithDirectionalEdgeInsets)
    }
    return nil;
}

#define SET_INVOCATION_ARGUMENT(ENCODING, TYPE, METHOD, INDEX)      \
(strcmp(ENCODING, @encode(TYPE)) == 0) {                            \
    TYPE result = [number METHOD];                                  \
    [invocation setArgument:&result atIndex:INDEX];                 \
    return;                                                         \
}

- (void)_setInvocationArgument:(NSInvocation *)invocation index:(int)index value:(id)value {
    NSMethodSignature *signature = [invocation methodSignature];
    const char *type = [signature getArgumentTypeAtIndex:index];

    if (strcmp(type, @encode(id)) == 0) {
        [invocation setArgument:&value atIndex:index];
        return;
    }
    NSNumber *number = value;
    if SET_INVOCATION_ARGUMENT(type, CGPoint, CGPointValue, index)
    else if SET_INVOCATION_ARGUMENT(type, CGSize, CGSizeValue, index)
    else if SET_INVOCATION_ARGUMENT(type, CGRect, CGRectValue, index)
    else if SET_INVOCATION_ARGUMENT(type, CGVector, CGVectorValue, index)
    else if SET_INVOCATION_ARGUMENT(type, CGAffineTransform, CGAffineTransformValue, index)
    else if SET_INVOCATION_ARGUMENT(type, UIOffset, UIOffsetValue, index)
    else if SET_INVOCATION_ARGUMENT(type, UIEdgeInsets, UIEdgeInsetsValue, index)
    else if SET_INVOCATION_ARGUMENT(type, NSRange, rangeValue, index)
    else if SET_INVOCATION_ARGUMENT(type, double, doubleValue, index)
    else if SET_INVOCATION_ARGUMENT(type, float, floatValue, index)
    else if SET_INVOCATION_ARGUMENT(type, bool, boolValue, index)
    else if SET_INVOCATION_ARGUMENT(type, int, intValue, index)
    else if SET_INVOCATION_ARGUMENT(type, char, charValue, index)
    else if SET_INVOCATION_ARGUMENT(type, short, shortValue, index)
    else if SET_INVOCATION_ARGUMENT(type, long, longValue, index)
    else if SET_INVOCATION_ARGUMENT(type, unsigned int, unsignedIntValue, index)
    else if SET_INVOCATION_ARGUMENT(type, unsigned char, unsignedCharValue, index)
    else if SET_INVOCATION_ARGUMENT(type, unsigned short, unsignedShortValue, index)
    else if SET_INVOCATION_ARGUMENT(type, unsigned long, unsignedLongValue, index)
    else if SET_INVOCATION_ARGUMENT(type, unsigned long long, unsignedLongLongValue, index)
    else if (@available(iOS 11, *)) {
        if ([value isKindOfClass:[NSValue class]]) {
            if SET_INVOCATION_ARGUMENT(type, NSDirectionalEdgeInsets, directionalEdgeInsetsValue, index)
        }
    }
}
@end
