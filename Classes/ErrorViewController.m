//
//  ErrorViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 9/1/09.
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

#import "AppSettings.h"
#import "ErrorViewController.h"
#import "SyncManager.h"

@implementation ErrorViewController

@synthesize skipButton;
@synthesize textView;
@synthesize detailText;
@synthesize showSkip;

- (void)dealloc {
	[skipButton release];
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.skipButton = nil;
	self.textView = nil;
	self.detailText = nil;	
}

-(IBAction)tryAgainButtonClicked {
	SyncManager* sm = [SyncManager getSingleton];
	
	[sm requestSyncIfNoneInProgressAndConnected];
	
	// and pop this view controller
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
	return;
}

-(IBAction)skipButtonClicked {
	SyncManager* sm = [SyncManager getSingleton];
	
	sm.skipMessageAccountNum = sm.lastErrorAccountNum;
	sm.skipMessageStartSeq = sm.lastErrorStartSeq;
	sm.skipMessageFolderNum = sm.lastErrorFolderNum;
	
	// and pop this view controller
	[self.navigationController popViewControllerAnimated:YES];
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.textView.text = self.detailText;
}

-(void)sendButtonWasPressed {
	if ([MFMailComposeViewController canSendMail] != YES) {
		//TODO(gabor): Show warning - this device is not configured to send email.
		return;
	}
	
	MFMailComposeViewController *mailCtrl = [[MFMailComposeViewController alloc] init];
	mailCtrl.mailComposeDelegate = self;

	[mailCtrl setSubject:[NSString stringWithFormat:@"Error Report %@/%@", [AppSettings udid], [AppSettings version]]];
	
	NSString* body = [NSString stringWithFormat:@"Error:\n\n%@", self.detailText];
	[mailCtrl setMessageBody:body isHTML:NO];
	//TODO(you): change this to your support email address
	[mailCtrl setToRecipients:[NSArray arrayWithObject:@"support@yourcompany.com"]];
	
	[self presentModalViewController:mailCtrl animated:YES];
	[mailCtrl release];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	[self.skipButton setHidden:!self.showSkip];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(sendButtonWasPressed)] autorelease];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}
@end
