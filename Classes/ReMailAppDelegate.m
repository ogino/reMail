//
//  NextMailAppDelegate.m
//  NextMail iPhone Application
//
//  Created by Gabor Cselle on 1/16/09.
//  Copyright 2010 Google Inc.
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//   http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ReMailAppDelegate.h"
#import "Reachability.h"
#import "AppSettings.h"
#import "HomeViewController.h"
#import "HomeViewController.h"
#import "SyncManager.h"
#import "StringUtil.h"
#import "SearchRunner.h"
#import "AccountTypeSelectViewController.h"
#import "GlobalDBFunctions.h"
#import "ActivityIndicator.h"
#import "EmailProcessor.h"
#import "AddEmailDBAccessor.h"
#import	"SearchEmailDBAccessor.h"
#import "ContactDBAccessor.h"
#import "UidDBAccessor.h"
#import "StoreObserver.h"
#import <StoreKit/StoreKit.h>

@implementation ReMailAppDelegate

@synthesize window;
@synthesize pushSetupScreen;

-(void)dealloc {
    [window release];
    [super dealloc];
}

-(void)deactivateAllPurchases {
	// This is debug code, it should never be called in production
	[AppSettings setFeatureUnpurchased:@"RM_NOADS"];
	[AppSettings setFeatureUnpurchased:@"RM_IMAP"];
	[AppSettings setFeatureUnpurchased:@"RM_RACKSPACE"];
}

-(void)activateAllPurchasedFeatures {
	[AppSettings setFeaturePurchased:@"RM_NOADS"];
	[AppSettings setFeaturePurchased:@"RM_IMAP"];
	[AppSettings setFeaturePurchased:@"RM_RACKSPACE"];
}

-(void)pingHomeThread {
	// ping home to www.remail.com - this is for user # tracking only and does not send any
	// personally identifiable or usage information
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];      
	
	NSString* model = [[AppSettings model] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	model = [model stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
	model = [model stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	
	int edition = (int)[AppSettings reMailEdition];
		
	NSString *encodedPostString = [NSString stringWithFormat:@"umd=%@&m=%@&v=%@&sv=%@&e=%i", md5([AppSettings udid]), model, [AppSettings version], [AppSettings systemVersion], edition];
	
	NSLog(@"pingRemail: %@", encodedPostString);
	
	NSData *postData = [encodedPostString dataUsingEncoding:NSUTF8StringEncoding];
	
	[request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.remail.com/ping"]]];
	[request setHTTPMethod:@"POST"];
	
	[request setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"content-type"];
	[request setHTTPBody:postData];	
	
	// Execute HTTP call
	NSHTTPURLResponse *response;
	NSError *error;
	NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	if((!error) && ([(NSHTTPURLResponse *)response statusCode] == 200) && ([responseData length] > 0)) {
		[AppSettings setPinged];
	} else {
		NSLog(@"Invalid ping response %i", [(NSHTTPURLResponse *)response statusCode]);
	}
	
	[request release];
	
	[pool release];	
}

-(void)pingHome {
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(pingHomeThread) object:nil];
	[driverThread start];
	[driverThread release];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
	NSLog(@"Failed push registration with error: %@", error);

	// I feel like this is kind of a hack
	if(self.pushSetupScreen != nil && [self.pushSetupScreen respondsToSelector:@selector(didFailToRegisterForRemoteNotificationsWithError:)]) {
		[self.pushSetupScreen performSelectorOnMainThread:@selector(didFailToRegisterForRemoteNotificationsWithError:) withObject:error waitUntilDone:NO];
	}
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)_deviceToken {
	// Get a hex string from the device token with no spaces or < >
	NSString* deviceToken = [[[[_deviceToken description] stringByReplacingOccurrencesOfString:@"<"withString:@""] 
						 stringByReplacingOccurrencesOfString:@">" withString:@""] 
						stringByReplacingOccurrencesOfString: @" " withString: @""];
	
	NSLog(@"Device Token: %@", deviceToken);
	if(self.pushSetupScreen != nil && [self.pushSetupScreen respondsToSelector:@selector(didRegisterForRemoteNotificationsWithDeviceToken:)]) {
		[self.pushSetupScreen performSelectorOnMainThread:@selector(didRegisterForRemoteNotificationsWithDeviceToken:) withObject:deviceToken waitUntilDone:NO];
	}									   
}

-(void)resetApp {
	// reset - delete all data and settings
	[AppSettings setReset:NO];
	for(int i = 0; i < [AppSettings numAccounts]; i++) {
		[AppSettings setUsername:@"" accountNum:i];
		[AppSettings setPassword:@"" accountNum:i];
		[AppSettings setServer:@"" accountNum:i];
		
		[AppSettings setAccountDeleted:YES accountNum:0];	
	}
		
	[AppSettings setLastpos:@"home"];
	[AppSettings setDataInitVersion];
	[AppSettings setFirstSync:YES];
	[AppSettings setGlobalDBVersion:0];
	
	[AppSettings setNumAccounts:0];
	
	[GlobalDBFunctions deleteAll];
}

-(void)setImapErrorLogPath {
	NSString* mailimapErrorLogPath = [StringUtil filePathInDocumentsDirectoryForFileName:@"mailimap_error.log"];
	const char* a = [mailimapErrorLogPath cStringUsingEncoding:NSASCIIStringEncoding];
	setenv("REMAIL_MAILIMAP_ERROR_LOG_PATH", a, 1);
	
	// delete file that might have been left around
	if ([[NSFileManager defaultManager] fileExistsAtPath:mailimapErrorLogPath]) {
		[[NSFileManager defaultManager] removeItemAtPath:mailimapErrorLogPath error:NULL];
	}
}

-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary*)options {
	[NSThread setThreadPriority:1.0];
	
	// set path for log output to send home
	[self setImapErrorLogPath];
	
	// handle reset and clearing attachments
	// (the user can reset all data in iPhone > Settings)
	if([AppSettings reset]) {
		[self resetApp];
	}
	
	// we're not selling reMail any more, so we can just activate all purchases
	[self activateAllPurchasedFeatures];
	
	BOOL firstSync = [AppSettings firstSync];
	
	if(firstSync) {
		[AppSettings setDatastoreVersion:1];
		
		//Need to set up first account
		AccountTypeSelectViewController* accountTypeVC;
		accountTypeVC = [[AccountTypeSelectViewController alloc] initWithNibName:@"AccountTypeSelect" bundle:nil];
		
		accountTypeVC.firstSetup = YES;
		accountTypeVC.accountNum = 0;
		accountTypeVC.newAccount = YES;
		
		UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:accountTypeVC];
		[self.window addSubview:navController.view];
		[accountTypeVC release];
	} else {
		// already set up - let's go to the home screen
		HomeViewController *homeController = [[HomeViewController alloc] initWithNibName:@"HomeView" bundle:nil];
		UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:homeController];
		navController.navigationBarHidden = NO;
		[self.window addSubview:navController.view];
		
		if(options != nil) {
			[homeController loadIt];
			[homeController toolbarRefreshClicked:nil];
		}
		[homeController release];
	}
	
	[window makeKeyAndVisible];
	
	//removed after I cut out store
	//[[SKPaymentQueue defaultQueue] addTransactionObserver:[StoreObserver getSingleton]];
	
	return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
   
	EmailProcessor *em = [EmailProcessor getSingleton];
	em.shuttingDown = YES;
	
	SearchRunner *sem = [SearchRunner getSingleton];
	[sem cancel];
	
	// write unwritten changes to user defaults to disk
	[NSUserDefaults resetStandardUserDefaults];
	
    [EmailProcessor clearPreparedStmts];
	[EmailProcessor finalClearPreparedStmts];
	[SearchRunner clearPreparedStmts];
    
	// Close the databases
	[[AddEmailDBAccessor sharedManager] close];
	[[SearchEmailDBAccessor sharedManager] close];
	[[ContactDBAccessor sharedManager] close];
	[[UidDBAccessor sharedManager] close];
}

- (void)applicationWillResignActive:(UIApplication *)application {
	//TODO(gabor): Cancel any ongoing sync, remember that a sync was ongoing
	NSLog(@"applicationWillResignActive");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// If a sync was ongoing, restart it
	NSLog(@"applicationDidBecomeActive");
}

@end
