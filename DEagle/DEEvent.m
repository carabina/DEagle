//
//  DEEvent.m
//  DETest
//
//  Created by Soroush Khodaii on 2016-09-28.
//  Copyright © 2016 DataEagle. All rights reserved.
//

#import "DEEvent.h"

@implementation DEEvent

-(id) init {
    self = [super init];
    
    if (self) {
        
        self.time = [NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]];
        self.name = @"";
        self.type = @"";
    }
    
    return self;
}

-(NSMutableDictionary*) dictionaryRepresentation {
    NSMutableDictionary* dic = [NSMutableDictionary dictionary];
    [dic setValue:self.time forKey:@"time"];
    [dic setValue:self.type forKey:@"type"];
    [dic setValue:self.name forKey:@"name"];
    
    return dic;
}

-(void) dealloc {
    self.time = nil;
    self.type = nil;
    self.name = nil;
}

@end

@interface DEUIEvent () {
    CGPoint location;
}


@end

@implementation DEUIEvent

-(id) initWithUIEvent:(nullable UIEvent *)event forAction:(SEL)action to:(id)target {
    
    self = [self init];
    
    if (self) {
        self.type = @"ui";
        self.name = [NSString stringWithFormat:@"%@:%@",NSStringFromSelector(action),[target class]];
        
        // add in code to capture more details.
        
        UITouch* touch = [[event allTouches] anyObject];
        if (touch) {
            // location, name of object it belonged to
            location = [touch locationInView:touch.window];
            
        }
        
    }
    
    return self;
}

-(NSMutableDictionary*) dictionaryRepresentation {
    NSMutableDictionary* dic = [super dictionaryRepresentation];
    
    [dic setValue:@(location.x) forKey:@"x"];
    [dic setValue:@(location.y) forKey:@"y"];
    
    return dic;
}

@end

@implementation DESystemEvent

-(id _Nonnull) initWithName:(NSString*)name {
    self = [self init];
    
    if (self) {
        self.type = @"system";
        self.name = name;
    }
    
    return self;
}

@end

@implementation DEUITransitionEvent

-(id _Nonnull) initWithIdentifier:(nullable NSString*)identifier source:(nonnull UIViewController*)source andDestination:(nonnull UIViewController*)destination {
    self = [self init];
    
    if (self) {
        self.type = @"transition";
        
        NSString* identifierName = @"";
        
        if (identifier) {
            identifierName = identifier;
        }
        
        self.name = [NSString stringWithFormat:@"transition:%@:%@ to %@",identifierName,[source class],[destination class]];
        
    }
    
    return self;
}

@end

@implementation DENotificationEvent

-(nonnull id) initWithRemoteNotificationInfoDic:(nonnull NSDictionary*)infoDic {
    self = [self init];
    
    if (self) {
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground || [[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive) {
            self.type = @"remote-notification-out-app";
        }else {
            self.type = @"remote-notification-in-app";
        }
        
        self.name = [NSString stringWithFormat:@"notification titled:%@",[[[infoDic valueForKey:@"aps"] valueForKey:@"alert"] valueForKey:@"title"]];
        
    }
    
    return self;
}

-(nonnull id) initWithLocalNotification:(nonnull UILocalNotification*)notification {
    self = [self init];
    
    if (self) {
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground || [[UIApplication sharedApplication] applicationState] == UIApplicationStateInactive) {
            self.type = @"local-notification-out-app";
        }else {
            self.type = @"local-notification-in-app";
        }
        
        self.name = [NSString stringWithFormat:@"notification titled:%@",notification.alertTitle];
        
    }
    
    return self;
}

@end