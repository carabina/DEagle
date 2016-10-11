//
//  UIStoryboardSegue+DE.m
//  DETest
//
//  Created by Soroush Khodaii on 2016-10-05.
//  Copyright © 2016 DataEagle. All rights reserved.
//

#import "UIStoryboardSegue+DE.h"
#import <objc/runtime.h>
#import <objc/message.h>

#import "DE.h"
#import "DEEvent.h"
#import "DELog.h"

@implementation UIStoryboardSegue (DE)

+(void) setupDEUITracking {
    void (^swizzle)(Class c, SEL orig, SEL new) = ^(Class c, SEL orig, SEL new){
        Method origMethod = class_getInstanceMethod(c, orig);
        Method newMethod = class_getInstanceMethod(c, new);
        if(class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    };
    
    //TODO: test with custom segues (though it should work as they have to call super first).
    swizzle([UIStoryboardSegue class], @selector(initWithIdentifier:source:destination:), @selector(DEinitWithIdentifier:source:destination:));
    
}

- (instancetype)DEinitWithIdentifier:(nullable NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination {
    
    [DELog log:[NSString stringWithFormat:@"init segue with id %@ from %@ to %@",identifier,[source class],[destination class]] verbosity:3];
    
    [[DE sharedInstance] recordEvent:[[DEUITransitionEvent alloc] initWithIdentifier:identifier source:source andDestination:destination]];
    
    return [self DEinitWithIdentifier:identifier source:source destination:destination];
}

@end
