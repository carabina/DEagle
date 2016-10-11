//
//  DE.h
//  DETest
//
//  Created by Soroush Khodaii on 2016-09-04.
//  Copyright © 2016 Zororoca. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class DEEvent;
@interface DE : NSObject <NSURLConnectionDelegate>

+(void) startWithKey:(nonnull NSString*)applicationKey andLaunchOptions:(nonnull NSDictionary*)launchOptions;

+(DE* _Nonnull) sharedInstance;

-(void) recordEvent:(nonnull DEEvent*)event;

@end
