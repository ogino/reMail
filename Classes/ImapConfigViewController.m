//
//  ImapConfigViewController.m
//
//  Displays login screen to the user ...
//
//  Created by Gabor Cselle on 1/22/09.
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

#import "MailCoreTypes.h"
#import "ImapConfigViewController.h"
#import "AppSettings.h"
#import "HomeViewController.h"
#import "SyncManager.h"
#import "StringUtil.h"
#import "ImapSync.h"
#import "FolderSelectViewController.h"
#import "Reachability.h"

#import "libetpan/mailstorage_types.h"
#import "libetpan/imapdriver_types.h"

@implementation ImapConfigViewController

@synthesize serverMessage, activityIndicator, usernameField, passwordField;
@synthesize serverField, encryptionSelector, portField;
@synthesize scrollView;
@synthesize accountNum;
@synthesize newAccount;
@synthesize firstSetup;
@synthesize selectFolders;

- (void)dealloc {
	[serverMessage release];
	[activityIndicator release];
	[usernameField release];
	[passwordField release];
	[scrollView release];
	
	[serverField release];
	[portField release];
	[encryptionSelector release];
	
	[selectFolders release];
	
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.serverMessage = nil;
	self.activityIndicator = nil;
	self.usernameField = nil;
	self.passwordField = nil;
	self.scrollView = nil;
	
	self.serverField = nil;
	self.portField = nil;
	self.encryptionSelector = nil;
	
	self.selectFolders = nil;
}

-(void)encryptionValueChanged:(id)sender {
	int encryption = self.encryptionSelector.selectedSegmentIndex;
	if(encryption == 0) {
		self.portField.text = @"143";
	} else {
		self.portField.text = @"993";
	}
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.navigationController setToolbarHidden:YES animated:animated];
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.selectFolders setEnabled:YES];
}

-(void)viewDidLoad {	
	self.usernameField.delegate = self;
	self.passwordField.delegate = self;
	
	// no serverMessage, activityIndicator
	self.serverMessage.text = @"";
	[self.activityIndicator setHidden:YES];	
	
	// preset username, password if they exist
	if(!self.newAccount) {
		if([AppSettings username:self.accountNum] != nil) {
			self.usernameField.text = [AppSettings username:self.accountNum];
		}
		if([AppSettings password:self.accountNum] != nil) {
			self.passwordField.text = [AppSettings password:self.accountNum];
		}
		if([AppSettings server:self.accountNum] != nil) {
			self.serverField.text = [AppSettings server:self.accountNum];
		}
		
		if([AppSettings serverPort:accountNum] != 0) {
			self.portField.text = [NSString stringWithFormat:@"%i", [AppSettings serverPort:accountNum]];
		}
		
		if([AppSettings serverEncryption:accountNum] == CONNECTION_TYPE_PLAIN) {
			self.encryptionSelector.selectedSegmentIndex = 0;
		} else {
			self.encryptionSelector.selectedSegmentIndex = 1;
		}
	} else {
		// if new account, don't show select folders button
		[self.selectFolders setHidden:YES];
	}
	
	[self.scrollView setContentSize:CGSizeMake(320, 625)];
	[self.encryptionSelector addTarget:self	action:@selector(encryptionValueChanged:) forControlEvents:UIControlEventValueChanged];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
	// pass focus off to next field
	if(textField == self.usernameField) {		
		[self.passwordField becomeFirstResponder];
	} else if (textField == self.passwordField) {
		[self.serverField becomeFirstResponder];
	} else if (textField == self.serverField) {
		[self.portField becomeFirstResponder];
	}
	return YES;
}

-(void)failedLoginWithMessage:(NSString*)message {
	self.serverMessage.text = message;
	[self.activityIndicator stopAnimating];
	[self.activityIndicator setHidden:YES];	
	[self.selectFolders setEnabled:YES];
}

-(void)saveSettings:(NSDictionary*)config {
	// The user was editing the account and clicked "Check and Save", and it validated OK
	self.serverMessage.text = @"";
	[self.activityIndicator setHidden:YES];	
	[self.activityIndicator stopAnimating];

	[AppSettings setUsername:[config objectForKey:@"username"] accountNum:self.accountNum];
	[AppSettings setPassword:[config objectForKey:@"password"] accountNum:self.accountNum];
	[AppSettings setServerAuthentication:[[config objectForKey:@"authentication"] intValue] accountNum:self.accountNum];
	[AppSettings setServer:[config objectForKey:@"server"] accountNum:self.accountNum];
	[AppSettings setServerPort:[[config objectForKey:@"port"] intValue] accountNum:self.accountNum];
	[AppSettings setServerEncryption:[[config objectForKey:@"encryption"] intValue] accountNum:self.accountNum];
	
	[self.navigationController popToRootViewControllerAnimated:YES];
}

-(void)showFolderSelect:(NSDictionary*)config {
	// The user was adding a new account and clicked "Check and Save", now let him/her select folders
	self.serverMessage.text = @"";
	[self.activityIndicator setHidden:YES];	
	[self.activityIndicator stopAnimating];
	
	// display home screen
	FolderSelectViewController *vc = [[FolderSelectViewController alloc] initWithNibName:@"FolderSelect" bundle:nil];
	vc.folderPaths = [config objectForKey:@"folderNames"];
	
	vc.username = [config objectForKey:@"username"];
	vc.password = [config objectForKey:@"password"];
	vc.server = [config objectForKey:@"server"];
	
	vc.encryption = [[config objectForKey:@"encryption"] intValue];
	vc.port = [[config objectForKey:@"port"] intValue];
	vc.authentication = [[config objectForKey:@"authentication"] intValue];
	
	vc.newAccount = self.newAccount;
	vc.firstSetup = self.firstSetup;
	vc.accountNum = self.accountNum;
	
	[self.navigationController pushViewController:vc animated:YES];
	[vc release];
}

-(void)doLogin:(NSNumber*)forceSelectFolders {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString* username = self.usernameField.text;
	NSString* password = self.passwordField.text;
	NSString* server = self.serverField.text;
	int encryption = self.encryptionSelector.selectedSegmentIndex;
	if (encryption == 0) {
		encryption = CONNECTION_TYPE_PLAIN;
	} else {
		encryption = CONNECTION_TYPE_TLS;
	}
	int port = [self.portField.text intValue];
	int authentication = IMAP_AUTH_TYPE_PLAIN;
	
	NSLog(@"Logging into %@:%i %i %i with user %@", server, port, encryption, authentication, username);
	
	NSMutableArray* folderNames = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
	NSString* response = [ImapSync validate:username password:password server:server port:port encryption:encryption authentication:authentication folders:folderNames]; 
	
	if([StringUtil stringContains:response subString:@"Parse error"]) {
		[[Reachability sharedReachability] setHostName:server];
		NetworkStatus status =[[Reachability sharedReachability] remoteHostStatus];
		if(status == NotReachable) {
			response = NSLocalizedString(@"Email server unreachable", nil);
		} else if(status == ReachableViaCarrierDataNetwork) {
			response = NSLocalizedString(@"Error connecting to server. Try over Wifi.", nil);
		} else {
			response = NSLocalizedString(@"Error connecting to server.", nil);
		}
	} else if([StringUtil stringContains:response subString:CTLoginErrorDesc]) {
		response = NSLocalizedString(@"Wrong username or password.", nil);
	}
	
	if([response isEqualToString:@"OK"]) { 
		NSDictionary* config = [NSDictionary dictionaryWithObjectsAndKeys:username, @"username",
								password, @"password",
								server, @"server",
								[NSNumber numberWithInt:encryption], @"encryption",
								[NSNumber numberWithInt:port], @"port",
								[NSNumber numberWithInt:authentication], @"authentication",
								folderNames, @"folderNames", nil];
		
		if(self.newAccount || [forceSelectFolders boolValue]) {
			[self performSelectorOnMainThread:@selector(showFolderSelect:) withObject:config waitUntilDone:NO];
		} else {
			[self performSelectorOnMainThread:@selector(saveSettings:) withObject:config waitUntilDone:NO];
		}
	} else {
		[self performSelectorOnMainThread:@selector(failedLoginWithMessage:) withObject:response waitUntilDone:NO];
	}
	[pool release];
}

-(BOOL)accountExists:(NSString*)username server:(NSString*)server {
	for(int i = 0; i < [AppSettings numAccounts]; i++) {
		if([AppSettings accountDeleted:i]) {
			continue;
		}
		
		if([[AppSettings server:i] isEqualToString:server] && [[AppSettings username:i] isEqualToString:username]) {
			return YES;
		}
	}
	
	return NO;
}

-(IBAction)loginClick {
	[self backgroundClick]; // to deactivate all keyboards
	
	// check if account already exists
	if(self.newAccount) {
		NSString* username = self.usernameField.text;
		NSString* server = self.serverField.text;
		
		if([self accountExists:username server:server]) {
			UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Account Exists",nil) message:NSLocalizedString(@"reMail already has an account for this username/server combination", nil) delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alertView show];
			[alertView release];
			return;
		}
	}
	
	
	self.serverMessage.text = NSLocalizedString(@"Validating login ...", nil);
	[self.activityIndicator setHidden:NO];	
	[self.activityIndicator startAnimating];
	
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(doLogin:) object:[NSNumber numberWithBool:NO]];
	[driverThread start];
	[driverThread release];
}

-(IBAction)selectFoldersClicked {
	[self.selectFolders setEnabled:NO];
	[self backgroundClick]; // to deactivate all keyboards
	
	self.serverMessage.text = NSLocalizedString(@"Getting folder list ...", nil);
	[self.activityIndicator setHidden:NO];	
	[self.activityIndicator startAnimating];
	
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(doLogin:) object:[NSNumber numberWithBool:YES]];
	[driverThread start];
	[driverThread release];
}

-(IBAction)backgroundClick {
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	[self.serverField resignFirstResponder];
	[self.portField resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"ImapConfig received memory warning");
}
@end
