//
//  DEEvent.h
//  DETest
//
//  Created by Soroush Khodaii on 2016-09-28.
//  Copyright © 2016 DataEagle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface DEEvent : NSObject

@property (nonatomic, strong, nullable) NSString* time;
@property (nonatomic, strong, nullable) NSString* name;
@property (nonatomic, strong, nullable) NSString* type;

-(nonnull NSMutableDictionary*) dictionaryRepresentation;

@end

@interface DEUIEvent : DEEvent

-(id _Nonnull) initWithUIEvent:(nullable UIEvent *)event forAction:(SEL _Nonnull)action to:(nonnull id)target;

@end

@interface DESystemEvent : DEEvent

-(id _Nonnull) initWithName:(nonnull NSString*)name;

@end

@interface DEUITransitionEvent : DEEvent

-(id _Nonnull) initWithIdentifier:(nullable NSString*)identifier source:(nonnull UIViewController*)source andDestination:(nonnull UIViewController*)destination;

@end

@interface DENotificationEvent : DEEvent

-(nonnull id) initWithRemoteNotificationInfoDic:(nonnull NSDictionary*)infoDic;
-(nonnull id) initWithLocalNotification:(nonnull UILocalNotification*)notification;

@end