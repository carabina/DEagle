//
//  DELog.h
//  DETest
//
//  Created by Soroush Khodaii on 2016-09-28.
//  Copyright © 2016 DataEagle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DELog : NSObject

+(void) log:(NSString*)str verbosity:(NSInteger)verbosity;

@end
