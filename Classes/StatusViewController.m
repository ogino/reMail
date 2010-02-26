//
//  StatusViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 6/26/09.
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

#import "StatusViewController.h"
#import "GlobalDBFunctions.h"
#import "ContactName.h"
#import "SyncManager.h"
#import "AppSettings.h"
#import "FolderSelectViewController.h"
#import "ImapSync.h"
#import "WebViewController.h"

#define LOVE_REMAIL_CUTOFF 100

@implementation StatusViewController

@synthesize attachmentsFileSizeLabel;
@synthesize fileSizeLabel;
@synthesize estimatedFileSizeLabel;
@synthesize estimatedTimeLabel;
@synthesize totalEmailLabel;
@synthesize onDeviceEmailLabel;
@synthesize freeSpaceLabel;
@synthesize startTime;
@synthesize versionLabel;

int syncedAtStart;

- (void)dealloc {
	[attachmentsFileSizeLabel release];
	[startTime release];
	[fileSizeLabel release];
	[estimatedFileSizeLabel release];
	[estimatedTimeLabel release];
	[totalEmailLabel release];
	[onDeviceEmailLabel release];
	[freeSpaceLabel release];
	[versionLabel release];
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.attachmentsFileSizeLabel = nil;
	self.startTime = nil;
	self.fileSizeLabel = nil;
	self.estimatedFileSizeLabel  = nil;
	self.estimatedTimeLabel  = nil;
	self.totalEmailLabel  = nil;
	self.onDeviceEmailLabel  = nil;
	self.freeSpaceLabel  = nil;
	self.versionLabel  = nil;
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
}

- (void)viewDidAppear:(BOOL)animated {
	// animating to or from - reload unread, server state
    [super viewDidAppear:animated];
}

-(void)calculateTotalFileSizeThread {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	float totalFileSize = MAX(0.001f,[GlobalDBFunctions totalFileSize] / 1024.0f / 1024.0f);
	NSString* totalFileSizeString = [NSString stringWithFormat:@"%.1f MB", totalFileSize];
	[self.fileSizeLabel performSelectorOnMainThread:@selector(setText:) withObject:totalFileSizeString waitUntilDone:NO];
	
	SyncManager* sm = [SyncManager getSingleton];
	int emailsOnDevice = [sm emailsOnDevice];
	int emailsInAccounts = [sm emailsInAccounts];
	
	float attachmentsFileSize = [GlobalDBFunctions totalAttachmentsFileSize] / 1024.0f / 1024.0f; // MAX: I want to show that there's at least SOME data
	if(attachmentsFileSize > 0.0f) {
		attachmentsFileSize = MAX(0.1f, attachmentsFileSize);
	}
	NSString* totalAttachmentsFileSizeString = [NSString stringWithFormat:@"%.1f MB", attachmentsFileSize];
	[self.attachmentsFileSizeLabel performSelectorOnMainThread:@selector(setText:) withObject:totalAttachmentsFileSizeString waitUntilDone:NO];
	
	// estimated space needed
	if(emailsOnDevice > 2) {
		float spacePerEmail = totalFileSize / (float)emailsOnDevice;
		float spaceNeeded = MAX(spacePerEmail * (float)emailsInAccounts, totalFileSize) + attachmentsFileSize;
		NSString* y = [NSString stringWithFormat:@"%i MB", (int)spaceNeeded];
		[self.estimatedFileSizeLabel performSelectorOnMainThread:@selector(setText:) withObject:y waitUntilDone:NO];
	} else {
		[self.estimatedFileSizeLabel performSelectorOnMainThread:@selector(setText:) withObject:@"-" waitUntilDone:NO];
	}
	
	float freeSpace = [GlobalDBFunctions freeSpaceOnDisk] / 1024.0f / 1024.0f;
	NSString* freeSpaceString = [NSString stringWithFormat:@"%i MB", (int)freeSpace];
	[self.freeSpaceLabel performSelectorOnMainThread:@selector(setText:) withObject:freeSpaceString waitUntilDone:NO];
	
	[pool release];
}

-(IBAction)calculateTotalFileSize {
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(calculateTotalFileSizeThread) object:nil];
	[driverThread start];
	[driverThread release];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	self.navigationItem.title = @"reMail Status";
	
	self.versionLabel.text = [NSString stringWithFormat:@"V%@ S%i", [AppSettings version], [AppSettings searchCount]];
	
	SyncManager* sm = [SyncManager getSingleton];
	
	// total emails in all accounts
	int emailsInAccounts = [sm emailsInAccounts];
	if(emailsInAccounts > 0) {
		NSString* emailsInAccountsString = [NSString stringWithFormat:@"%i", emailsInAccounts];
		self.totalEmailLabel.text = emailsInAccountsString; 
	} else {
		self.totalEmailLabel.text = @"-";
	}
	
	// number of emails on device
	int emailsOnDevice = [sm emailsOnDevice];
	NSString* emailsOnDeviceString = [NSString stringWithFormat:@"%i", emailsOnDevice];
	self.onDeviceEmailLabel.text = emailsOnDeviceString;
	
	syncedAtStart = emailsOnDevice;
	self.startTime = [NSDate date];
	
	// file size
	self.fileSizeLabel.text = @"..."; 

	// attachments
	self.attachmentsFileSizeLabel.text = @"...";

	// free space
	self.freeSpaceLabel.text = @"..."; 
	
	// fill out file size, attachments file size on separate thread
	[self calculateTotalFileSize];
	
	// estimated time
	self.estimatedTimeLabel.text = @"-";
	
	self.estimatedFileSizeLabel.text = @"...";
	
	[sm registerForProgressNumbersWithDelegate:self];
	
	[AppSettings setLastpos:@"status"];
}

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	SyncManager* sm = [SyncManager getSingleton];
	[sm registerForProgressNumbersWithDelegate:nil];
}

-(void)didChangeProgressNumbersTo:(NSDictionary*)dict {
	int synced = [[dict objectForKey:@"synced"] intValue];
	int folderNum = [[dict objectForKey:@"folderNum"] intValue];
	int accountNum = [[dict objectForKey:@"accountNum"] intValue];
	
	SyncManager* sm = [SyncManager getSingleton];
	int onDevice = [sm emailsOnDeviceExceptFor:folderNum accountNum:accountNum] + synced;
	
	int total = [sm emailsInAccounts];
	
	NSString* totalString = [NSString stringWithFormat:@"%i", total];
	self.totalEmailLabel.text = totalString;

	NSString* emailsOnDeviceString = [NSString stringWithFormat:@"%i", onDevice];
	self.onDeviceEmailLabel.text = emailsOnDeviceString;
	
	if((synced % 10) == 0 && (synced > 0)) {
		// only update every once in a while
		
		// attachments
		float attachmentsFileSize = [GlobalDBFunctions totalAttachmentsFileSize] / 1024.0f / 1024.0f; // MAX: I want to show that there's at least SOME data
		
		// file size estimate
		float totalFileSize = MAX(0.001f,[GlobalDBFunctions totalFileSize] / 1024.0f / 1024.0f);
		NSString* totalFileSizeString = [NSString stringWithFormat:@"%.1f MB", totalFileSize];
		self.fileSizeLabel.text = totalFileSizeString;
		
		float spacePerEmail = totalFileSize / (float)onDevice;
		float spaceNeeded = spacePerEmail * (float)total + attachmentsFileSize;
		
		self.estimatedFileSizeLabel.text = [NSString stringWithFormat:@"%i MB", (int)spaceNeeded];
		
		float freeSpace = [GlobalDBFunctions freeSpaceOnDisk] / 1024.0f / 1024.0f; // MAX: I want to show that there's at least SOME data
		NSString* freeSpaceString = [NSString stringWithFormat:@"%i MB", (int)freeSpace];
		self.freeSpaceLabel.text = freeSpaceString;
		
		//download time estimate
		int syncedSinceStart = onDevice - syncedAtStart;
		
		if(syncedSinceStart < 5) {
			return;
		}
		
		NSDate* now = [NSDate date];
		
		double interval = [now timeIntervalSinceDate:startTime];
		
		double timePerEmail = interval/(double)syncedSinceStart;
		
		int emailsLeft = total - synced;
		if(emailsLeft < 5) {
			self.estimatedTimeLabel.text = @"-";
		}
		
		double totalTime = timePerEmail * emailsLeft;
		int hours = (int)totalTime / 3600;
		int minutes = ((int)totalTime % 3600) / 60;
		
		NSString* timeLeftString = [NSString stringWithFormat:@"%Uh:%02U", hours, minutes];
		self.estimatedTimeLabel.text = timeLeftString;
	}
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}
@end
