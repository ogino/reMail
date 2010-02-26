//
//  PushSetupViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 10/22/09.
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

#import "PushSetupViewController.h"
#import "AppSettings.h"
#import "ActivityIndicator.h"
#import "StringUtil.h"
#import "ReMailAppDelegate.h"

@implementation PushSetupViewController

@synthesize timePicker;
@synthesize disableButton;
@synthesize okButton;
@synthesize remindDescriptionLabel;
@synthesize remindTitleLabel;
@synthesize activityIndicator;


- (void)dealloc {
	[disableButton release];
	[okButton release];
	[timePicker release];
	[remindDescriptionLabel release];
	[remindTitleLabel release];
	[activityIndicator release];
	
	[super dealloc];
}


- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.disableButton = nil;
	self.okButton = nil;
	self.timePicker = nil;
	self.remindDescriptionLabel = nil;
	self.remindTitleLabel = nil;
	self.activityIndicator = nil;	
}

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

-(void)viewDidLoad {
	[super viewDidLoad];
	
	if([AppSettings pushDeviceToken] == nil) {
		[self.disableButton setHidden:YES];
	} else {
		[self.disableButton setHidden:NO];
	}
	
	if([AppSettings pushDeviceToken] != nil) {
		self.remindTitleLabel.text = NSLocalizedString(@"Reminders are set up for:", nil);
		self.timePicker.date = [AppSettings pushTime];
	} else {
		self.remindTitleLabel.text = NSLocalizedString(@"Remind every day at:", nil);
	}
	
	self.remindDescriptionLabel.text = NSLocalizedString(@"reMail can remind once a day you to download your newest emails.", nil);
	[self.disableButton setTitle:NSLocalizedString(@"Disable", nil) forState:UIControlStateNormal];
	[self.disableButton setTitle:NSLocalizedString(@"Disable", nil) forState:UIControlStateHighlighted];
	
	[self.activityIndicator setHidden:YES];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

-(void)didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
	[self.okButton setEnabled:YES];
	[self.disableButton setEnabled:YES];
	[self.activityIndicator setHidden:YES];

	UIApplication* uia = [UIApplication sharedApplication];
	
	ReMailAppDelegate* appDelegate = uia.delegate;	
	appDelegate.pushSetupScreen = nil;
	
	NSString* blah = [NSString stringWithFormat:@"%@", error];
	
	UIAlertView* as = [[UIAlertView alloc] initWithTitle:@"Push registration error" message:blah delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[as show];
	[as release];
}

-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSString*)deviceToken {
	// send the deviceToken & settings to our server
	UIApplication* uia = [UIApplication sharedApplication];
	
	ReMailAppDelegate* appDelegate = uia.delegate;	
	appDelegate.pushSetupScreen = nil;
	
	[ActivityIndicator on];
	
	int edition = (int)[AppSettings reMailEdition];

	int gmtDifference = [[NSTimeZone localTimeZone] secondsFromGMT];
	NSDate* date = self.timePicker.date;
	NSDateFormatter* dateF = [[NSDateFormatter alloc] init];
	[dateF setDateFormat:@"HH"];
	NSString* hours = [dateF stringFromDate:date];
	[dateF setDateFormat:@"mm"];
	NSString* minutes = [dateF stringFromDate:date];
	[dateF release];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];  
	NSString *encodedPostString = [NSString stringWithFormat:@"umd=%@&token=%@&aid=%@&sv=%@&e=%i&gmtd=%i&m=%@&h=%@", md5([AppSettings udid]), deviceToken, [AppSettings appID], [AppSettings version], edition, gmtDifference, minutes, hours];
	
	NSLog(@"pushSetup: %@", encodedPostString);
	
	NSData *postData = [encodedPostString dataUsingEncoding:NSUTF8StringEncoding];
	
	[request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.remail.com/push/register"]]];
	[request setHTTPMethod:@"POST"];
	
	[request setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"content-type"];
	[request setHTTPBody:postData];	
	
	//Do the call
	NSHTTPURLResponse *urlResponse;
	NSError *error;
	[NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
	[request release];
	
	if(error == nil) {
		[AppSettings setPushDeviceToken:deviceToken];
		[AppSettings setPushTime:self.timePicker.date];
		
		[self.navigationController popViewControllerAnimated:YES];
	} else {
		NSString* blah = [NSString stringWithFormat:@"%@", error];
		
		UIAlertView* as = [[UIAlertView alloc] initWithTitle:@"Push call error" message:blah delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[as show];
		[as release];
	}
	
	[ActivityIndicator off];
}

-(IBAction)disableClicked {
	[self.activityIndicator setHidden:NO];
	[self.activityIndicator startAnimating];
	
	[self.okButton setEnabled:NO];
	[self.disableButton setEnabled:NO];
	
	// tell both our server and the UIApplication that we're done!
	UIApplication* uia = [UIApplication sharedApplication];
	[uia unregisterForRemoteNotifications];
	
	[ActivityIndicator on];
	
	int edition = (int)[AppSettings reMailEdition];
	NSString *encodedPostString = [NSString stringWithFormat:@"umd=%@&udid=%@&token=%@&aid=%@&sv=%@&e=%i", md5([AppSettings udid]), [AppSettings udid], [AppSettings pushDeviceToken], [AppSettings appID], [AppSettings version], edition];
	
	NSLog(@"pushSetup: %@", encodedPostString);
	
	NSData *postData = [encodedPostString dataUsingEncoding:NSUTF8StringEncoding];
	
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.remail.com/push/unregister"]]];
	[request setHTTPMethod:@"POST"];
	
	[request setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"content-type"];
	[request setHTTPBody:postData];	
	
	//Do the call
	NSHTTPURLResponse *urlResponse;
	NSError *error;
	[NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
	[request release];
	
	[ActivityIndicator off];
	
	[AppSettings setPushDeviceToken:nil];
	
	[self.navigationController popViewControllerAnimated:YES];
}

-(IBAction)okClicked {
	[self.activityIndicator setHidden:NO];
	[self.activityIndicator startAnimating];
	
	[self.okButton setEnabled:NO];
	[self.disableButton setEnabled:NO];
	
	UIApplication* uia = [UIApplication sharedApplication];
	
	ReMailAppDelegate* appDelegate = uia.delegate;	
	appDelegate.pushSetupScreen = self;
	[uia registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}
@end
