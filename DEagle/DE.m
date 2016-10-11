//
//  DE.m
//  DETest
//
//  Created by Soroush Khodaii on 2016-09-04.
//  Copyright © 2016 Zororoca. All rights reserved.
//

#import "DE.h"

#import "DEEvent.h"
#import "DELog.h"
#import "UIControl+DE.h"
#import "NSData+GZIP.h"
#import "UIStoryboardSegue+DE.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define IS_DEV              1

#define URL_PREFIX          @"https://"

#define DEV_SERVER_URL      @"192.168.1.100"//@"127.0.0.1"
#define DEV_URL_PORT        @"2001"

#define PROD_SERVER_URL     @"127.0.0.1"
#define PORD_URL_PORT       @"2001"

#define UPLOAD_EVENTS_API   @"events"

#if IS_DEV == 1

#define SERVER_URL  DEV_SERVER_URL
#define SERVER_PORT DEV_URL_PORT

#else

#define SERVER_URL  PROD_SERVER_URL
#define SERVER_PORT PORD_URL_PORT

#endif

@interface DE () {
    NSArray* trustedHosts;
}

@property (nonatomic, strong) NSString* appKey;
@property (nonatomic, strong) NSString* userId;

@property (nonatomic, strong) NSString* devicePushToken;

@property (nonatomic, strong) NSMutableArray* storage;

@property (atomic) UIBackgroundTaskIdentifier bgTaskId;
@property (nonatomic) NSURLConnection* uploadConnection;

@end

@implementation DE

+(void) startWithKey:(NSString*)applicationKey andLaunchOptions:(NSDictionary*)launchOptions {
    
    // setup DE object
    DE* sharedDE = [DE sharedInstance];
    sharedDE.appKey = applicationKey;
    
    //TODO: at some point add tracking to working with shortcut (touch sensitive screen) and notification actions (like liking a comment through a notification without actually opening the app).
    
}

+(DE*) sharedInstance {
    static DE* staticInstance = nil;
    
    if (staticInstance == nil) {
        staticInstance = [[DE alloc] init];
    }
    
    return staticInstance;
}

-(id) init {
    self = [super init];
    
    if (self) {
        
        // setup event storage.
        [self loadStorage];
        
        // Setup app open/close/suspend... tracking
        [self setupSystemEventsTracking];
        
        // Setup push notifications tracking
        [self setupLocalAndRemoteNotificationTracking];
        
        // Setup the UI event tracking.
        [UIControl setupDEUITracking];
        [UIStoryboardSegue setupDEUITracking];
        
        // We want to be able to receive push notifications from APNs, that's how Deagle works!
        [self setupReceivingPushNotifications];
        
        self.uploadConnection = nil;
        
        trustedHosts = @[SERVER_URL];
        
        //TODO: setup purchase events
        
        //TODO: setup location tracking (if location services available that, otherwise through ip)
        
    }
    
    return self;
}

-(void) setupSystemEventsTracking {
    
    // add listeners for UIApplication events
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidFinishLaunching) name:UIApplicationDidFinishLaunchingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
}

-(void) setupLocalAndRemoteNotificationTracking {
    
    // we will add some function to the app delegate... swizzle around if they exist :)
    id<UIApplicationDelegate> appDel = [[UIApplication sharedApplication] delegate];
    
    // there's some fidling around with notification functions due to new iOS behaviour.
    if ([appDel respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
        [DE addOrSwizzleMethod:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:) fromClass:[appDel class] withMethod:@selector(DEapplication:didReceiveRemoteNotification:fetchCompletionHandler:) fromClass:[DE class]];
    }else {
        if ([appDel respondsToSelector:@selector(application:didReceiveRemoteNotification:)]) {
            [DE addOrSwizzleMethod:@selector(application:didReceiveRemoteNotification:) fromClass:[appDel class] withMethod:@selector(DEapplication:didReceiveRemoteNotification:) fromClass:[DE class]];
        }else {
            [DE addOrSwizzleMethod:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:) fromClass:[appDel class] withMethod:@selector(DEapplication:didReceiveRemoteNotification:fetchCompletionHandler:) fromClass:[DE class]];
        }
    }
    
    [DE addOrSwizzleMethod:@selector(application:didReceiveLocalNotification:) fromClass:[appDel class] withMethod:@selector(DEapplication:didReceiveLocalNotification:) fromClass:[DE class]];
    
}

-(void) setupReceivingPushNotifications {
    
    // Should we register for push notifications? It could be that they already are and are smart
    //          about it by presenting it to the user the right way.
    //  what we'll do instead is check to see if push notifications are enabled and instead print out a serious warning for the developers.
    id <UIApplicationDelegate> appDel = [[UIApplication sharedApplication] delegate];
    
    // add in function to receive push token.
    [DE addOrSwizzleMethod:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:) fromClass:[appDel class] withMethod:@selector(DEapplication:didRegisterForRemoteNotificationsWithDeviceToken:) fromClass:[DE class]];
    
    if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
        // we call this to get the device APNs token.
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }else {
        // show warning message in log to developer;
        NSLog(@"WARNING: Application not registered for remote notifications. Data Eagle can't take action for you if push notifications aren't enabled!!! You can refer to https://goo.gl/682KJ0 to learn how to register for remote notifications.");
    }
    
}

#pragma mark - storage:

-(void) loadStorage {
    
    // We're storing for short term, so a dictionary/plist would suffice. We may need to store events from a couple sessions if internet isn't available so will need to load existing file.
    
    self.storage = [NSMutableArray arrayWithContentsOfFile:[self storageFilePath]];
    
    // if file doesn't exist for some reason...
    if (!self.storage) {
        // setup new array
        self.storage = [NSMutableArray arrayWithCapacity:32];
        
    }

}

-(void) recordEvent:(DEEvent*)event {   // add in more params
    
    // Add the event to storage.
    
    [self.storage addObject:[event dictionaryRepresentation]];
}

-(void) clearStorage {
    // clear array and also delete local file.
    self.storage = [NSMutableArray arrayWithCapacity:32];
    
    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:[self storageFilePath] error:&error];
    if (error) {
        
        [DELog log:@"DE: failed to remove old storage path" verbosity:1];
    }
    
}

-(void) saveStorageFile {
    [self.storage writeToFile:[self storageFilePath] atomically:YES];
}

-(NSString*) storageFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    
    NSAssert([paths count]>0, @"DE: Couldn't access device documents directory.");
    
    // Path to save dictionary
    NSString* storagePath = [[paths objectAtIndex:0]
                          stringByAppendingPathComponent:@"DEStorage.plist"];
    return storagePath;
    
}

#pragma mark - upload to server:

-(void) uploadEventsToServer {
    
    if (self.uploadConnection) {
        NSLog(@"We are already in the middle of uploading, yet new request sent!! fix this.");
        return;
    }
    
    // initiate background task
    self.bgTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
        // stop request and save storage instead.
        if (self.uploadConnection) {
            [self.uploadConnection cancel];
        }
        
        [self failedUploadCleanup];
    }];
    
    // turn storage into JSON string
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.storage
                                                       options:0
                                                         error:&error];
    
    // compress string
    jsonData = [jsonData gzippedData];
    
    // base64 encode string
    NSString* base64String = [jsonData base64EncodedStringWithOptions:0];
    
    // build up request params based on user and device info
    //TODO: Currently we're using device id for user id as well, though it is ultimately better to have some way of linking a user by getting some info from the client so that users that have multiple devices have their events gathered in one place...
    
    NSString* pushToken = @"";
    if (self.devicePushToken) {
        pushToken = self.devicePushToken;
    }
    
    NSString *post = [NSString stringWithFormat:@"{\"app_key\":\"%@\",\"user_id\":\"%@\",\"events_zip\":\"%@\",\"push_token\":\"%@\",\"device_id\":\"%@\",\"device_type\":\"%@\"}",self.appKey,[[[UIDevice currentDevice] identifierForVendor] UUIDString],base64String,pushToken,[[[UIDevice currentDevice] identifierForVendor] UUIDString],[[UIDevice currentDevice] model]];
    
    
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu",(unsigned long)[postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@:%@/%@",URL_PREFIX,SERVER_URL,SERVER_PORT,UPLOAD_EVENTS_API]]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    // send up to server
    self.uploadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    // check to see if we have connection
    if(self.uploadConnection) {
        NSLog(@"Connection Successful");
        // wait to see results through delegate callbacks.
    } else {
        NSLog(@"Connection could not be made");
        [self failedUploadCleanup];
    }

}

-(void) failedUploadCleanup {
    
    self.uploadConnection = nil;
    
    [self saveStorageFile];
    
    [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskId];
}

// This method is used to receive the data which we get using post method.
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData*)data {
    NSLog(@"connection did receive data, %@",[data description]);
}

// This method receives the error report in case of connection is not made to server.
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"connection failed, %@",[error description]);
    
    // if failed, then save for future.
    [self failedUploadCleanup];
}

// This method is used to process the data after connection has made successfully.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"connection finished loading");
    
    // if process completes, clear storage
    self.uploadConnection = nil;
    [self clearStorage];
    [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskId];
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return YES;
}

//- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
//    NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
//    if ([protectionSpace authenticationMethod] == NSURLAuthenticationMethodServerTrust) {
//        SecTrustRef trust = [protectionSpace serverTrust];
//        
//        /***** Make specific changes to the trust policy here. *****/
//        SecPolicyRef policyRef = SecPolicyCreateSSL(true, CFSTR("127.0.0.1"));
//        
//        SecTrustSetPolicies(trust, policyRef);
//        
//        /* Re-evaluate the trust policy. */
//        SecTrustResultType secresult = kSecTrustResultInvalid;
//        if (SecTrustEvaluate(trust, &secresult) != errSecSuccess) {
//            /* Trust evaluation failed. */
//            
//            [connection cancel];
//            
//            // Perform other cleanup here, as needed.
//            return;
//        }
//        
//        switch (secresult) {
//            case kSecTrustResultUnspecified: // The OS trusts this certificate implicitly.
//            case kSecTrustResultProceed: // The user explicitly told the OS to trust it.
//            {
//                NSURLCredential *credential =
//                [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
//                [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
//                return;
//            }
//            
//                /* It's somebody else's key. Fall through. */
//        }
//        /* The server sent a key other than the trusted key. */
//        [connection cancel];
//        
//        // Perform other cleanup here, as needed.
//    }
//}


- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    NSLog(@"%@",challenge.protectionSpace.host);
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
        if ([trustedHosts containsObject:challenge.protectionSpace.host])
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

#pragma mark - system events:

-(void) appDidBecomeActive {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"didBecomeActive"]];
}

-(void) appDidEnterBackground {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"didEnterBackground"]];
    
    // send events to server,
    //TODO: check to see if we should also have something in app will terminate.
    [self uploadEventsToServer];
}

-(void) appWillEnterForeground {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"willEnterForeground"]];
}

-(void) appDidFinishLaunching {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"didFinishLaunching"]];
}

-(void) appWillResignActive {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"willResignActive"]];
}

-(void) appWillTerminate {
    [self recordEvent:[[DESystemEvent alloc] initWithName:@"willTerminate"]];
}

#pragma mark - notification events

- (void)DEapplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    
    // store event for it.
    [[DE sharedInstance] recordEvent:[[DENotificationEvent alloc] initWithRemoteNotificationInfoDic:userInfo]];
    
    //TODO: if this event is related to us, then we might need to do some deep linking or showing of in-app message.
    
    // call this to continue running original function, as it has been switched out.
    if ([self respondsToSelector:@selector(DEapplication:didReceiveRemoteNotification:)]) {
        [self DEapplication:application didReceiveRemoteNotification:userInfo];
    }
}

- (void)DEapplication:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    
    // store event for it.
    [[DE sharedInstance] recordEvent:[[DENotificationEvent alloc] initWithRemoteNotificationInfoDic:userInfo]];
    
    //TODO: if this event is related to us, then we might need to do some deep linking or showing of in-app message.
    
    // call this to continue running original function, as it has been switched out.
    if ([self respondsToSelector:@selector(DEapplication:didReceiveRemoteNotification:fetchCompletionHandler:)]) {
        [self DEapplication:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
    }
}

- (void)DEapplication:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    
    //TODO: store event for it.
    [[DE sharedInstance] recordEvent:[[DENotificationEvent alloc] initWithLocalNotification:notification]];
    
    // call this to continue running original function, as it has been switched out.
    if ([self respondsToSelector:@selector(DEapplication:didReceiveLocalNotification:)]) {
        [self DEapplication:application didReceiveLocalNotification:notification];
    }
}

- (void)DEapplication:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    // store token and do other setup tasks.
    [DE sharedInstance].devicePushToken = [deviceToken base64EncodedStringWithOptions:0];
    
    // call this to continue running original function, as it has been switched out.
    if ([self respondsToSelector:@selector(DEapplication:didRegisterForRemoteNotificationsWithDeviceToken:)]) {
        [self DEapplication:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(nullable NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void(^)())completionHandler {
    //TODO: store event for it.
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(nullable NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void(^)())completionHandler {
    //TODO: store event for it.
}

// Called when your app has been activated by the user selecting an action from a remote notification.
// A nil action identifier indicates the default action.
// You should call the completion handler as soon as you've finished handling the action.
- (void)application:(UIApplication *)application handleActionWithIdentifier:(nullable NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void(^)())completionHandler {
    //TODO: store event for it.
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(nullable NSString *)identifier forLocalNotification:(UILocalNotification *)notification withResponseInfo:(NSDictionary *)responseInfo completionHandler:(void(^)())completionHandler {
    //TODO: store event for it.
}


#pragma mark - Custom Analytics events

//TODO: override analytics function calls from Mixpanel, flurry, google, localytics...
//      that give additional info like user demographic and whatnot.

#pragma mark - Location events

//TODO: track user location... if at some point we decide to use more precise location data (than ip).

#pragma mark - Helper functions

+(void) addOrSwizzleMethod:(SEL)originalSelector fromClass:(Class)c1 withMethod:(SEL)newSelector fromClass:(Class)c2{
    
    Method origMethod = class_getInstanceMethod(c1, originalSelector);
    Method newMethod = class_getInstanceMethod(c2, newSelector);
    
    // checks to see if the method exists in the class or not.
    if(!class_addMethod(c1, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        
        // since c1 has the originalSelector implemented already, we have to take a few extra steps.
        
        // we'll go ahead and add in our new method with it's old name for safe keeping.
        class_addMethod(c1, newSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
        
        // then switch up the two functions. We do this so class properties used in the original method will still work afterwards.
        newMethod = class_getInstanceMethod(c1, newSelector);
        method_exchangeImplementations(origMethod, newMethod);
    }
}

/*
+(UIImage*) takeScreenshot {
    
    UIWindow* window = [[[UIApplication sharedApplication] delegate] window];
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(window.bounds.size, NO, [UIScreen mainScreen].scale);
    } else {
        UIGraphicsBeginImageContext(window.bounds.size);
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    if ([paths count] > 0)
    {
        NSLog(@"˚˚˚˚˚˚˚ Documents path:%@",[paths objectAtIndex:0]);
    }

    
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *imageData = UIImageJPEGRepresentation(image, 0.2);
    if (imageData) {
        [imageData writeToFile:[NSString stringWithFormat:@"%@/screenshot.jpg",[paths objectAtIndex:0]] atomically:YES];
        NSLog(@"∆∆∆∆∆∆∆∆ Screenshot saved");
    } else {
        NSLog(@"error while taking screenshot");
    }
    
    return image;
    
}
 */

@end
