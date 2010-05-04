//
//  FolderListViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 9/24/09.
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

#import "EmailProcessor.h"
#import "SyncManager.h"
#import "AppSettings.h"
#import "FolderListViewController.h"
#import "MailboxViewController.h"
#import "StringUtil.h"

@implementation FolderListViewController
@synthesize accountIndices;
@synthesize accountFolders;
@synthesize accountFolderNums;

- (void)dealloc {
	// not sure why but these are failing
	[accountIndices release];
	[accountFolders release];
	[accountFolderNums release];
    [super dealloc];
}


- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.accountIndices = nil;
	self.accountFolders = nil;	
	self.accountFolderNums = nil;
}

-(void)doLoad {
	NSMutableArray* accountIndicesLocal = [NSMutableArray arrayWithCapacity:[AppSettings numAccounts]];
	NSMutableDictionary* accountFoldersLocal = [NSMutableDictionary dictionaryWithCapacity:[AppSettings numAccounts]];
	NSMutableDictionary* accountFolderNumsLocal = [NSMutableDictionary dictionaryWithCapacity:[AppSettings numAccounts]];
	
	for(int i = 0; i < [AppSettings numAccounts]; i++) {
		if([AppSettings accountDeleted:i]) {
			continue;
		}
		
		[accountIndicesLocal addObject:[NSNumber numberWithInt:i]];
		
		SyncManager* sm = [SyncManager getSingleton];
		
		int folderCount = [sm folderCount:i];
		
		NSMutableArray* folderNames = [NSMutableArray arrayWithCapacity:folderCount];
		NSMutableArray* folderNumbers = [NSMutableArray arrayWithCapacity:folderCount];
		for(int j = 0; j < folderCount; j++) {
			if([sm isFolderDeleted:j accountNum:i]) {
				continue;
			}
			
			NSMutableDictionary* folderState = [sm retrieveState:j accountNum:i];
			NSString* folderDisplayName = [folderState objectForKey:@"folderDisplayName"];
			NSString* folderPath = [folderState objectForKey:@"folderPath"];
                        NSLog( @"folderPath: %@, folderDisplayName: %@", folderPath, folderDisplayName );
			if([folderPath isEqualToString:@"$$$$All_Mail$$$$"]) {
				folderDisplayName = NSLocalizedString(@"All Mail", nil);
			}
			if([StringUtil isOnlyWhiteSpace:folderDisplayName]) {
				folderDisplayName = @"<No Name>";
			}
			[folderNames addObject:folderDisplayName];
			[folderNumbers addObject:[NSNumber numberWithInt:j]];
		}
		
		NSNumber* indexObj = [NSNumber numberWithInt:i];
		[accountFoldersLocal setObject:folderNames forKey:indexObj];
		[accountFolderNumsLocal setObject:folderNumbers forKey:indexObj];
	}
	
	self.accountIndices = accountIndicesLocal;
	self.accountFolders = accountFoldersLocal;
	self.accountFolderNums = accountFolderNumsLocal;
}

-(void)viewWillAppear:(BOOL)animated {
	self.title = NSLocalizedString(@"Folders", nil);
	
	[self doLoad];
}

-(void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(composeClick)] autorelease];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[AppSettings setLastpos:@"folders"];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	NSLog(@"FolderList received memory warning!");
}

#pragma mark Table view methods
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(section == 0) {
		return NSLocalizedString(@"All Mail", nil);
	} else {
		int index = [[self.accountIndices objectAtIndex:section-1] intValue];
		return [AppSettings username:index];
	}
		
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1 + [self.accountIndices count];
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section == 0) {
		return 1;
	}
	
	NSNumber* index = [self.accountIndices objectAtIndex:section-1];
	
	return [[self.accountFolders objectForKey:index] count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    if(indexPath.section == 0) {
		cell.textLabel.text = @"All Mail";
		cell.imageView.image = [UIImage imageNamed:@"foldersAll.png"];
	} else {
		NSNumber* index = [self.accountIndices objectAtIndex:indexPath.section-1];
		
		NSArray* f = [self.accountFolders objectForKey:index];
		
		cell.textLabel.text = [f objectAtIndex:indexPath.row];
		cell.imageView.image = [UIImage imageNamed:@"folderIcon.png"];
	}
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"MailboxView" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator]; 
	MailboxViewController *uivc = nil;
	NSObject* nibItem = NULL;
    while ( (nibItem = [nibEnumerator nextObject]) != NULL) { 
        if ( [nibItem isKindOfClass: [MailboxViewController class]]) { 
			uivc = (MailboxViewController*) nibItem;
			break;
		}
	}
	
	if(uivc == nil) {
		return;
	}
	
	if(indexPath.section == 0) {
		uivc.folderNum = -1;
		uivc.title = NSLocalizedString(@"All Mail", nil);
	} else {
		int accountNum = [[self.accountIndices objectAtIndex:indexPath.section-1] intValue];
		NSNumber* index = [self.accountIndices objectAtIndex:indexPath.section-1];
		int folderNum = [[[self.accountFolderNums objectForKey:index] objectAtIndex:indexPath.row] intValue];

		NSArray* f = [self.accountFolders objectForKey:index];
		NSString* folderDisplayName = [f objectAtIndex:indexPath.row];
		
		uivc.folderNum = [EmailProcessor combinedFolderNumFor:folderNum withAccount:accountNum];
		uivc.title = folderDisplayName;
	}
	
	uivc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	
    // Navigation logic may go here. Create and push another view controller.
	[self.navigationController pushViewController:uivc animated:YES];
	[uivc doLoad];
	
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

-(IBAction)composeClick {
	if ([MFMailComposeViewController canSendMail] != YES) {
		//TODO(gabor): Show warning - this device is not configured to send email.
		return;
	}
	
	MFMailComposeViewController *mailCtrl = [[MFMailComposeViewController alloc] init];
	mailCtrl.mailComposeDelegate = self;
	
	if([AppSettings promo]) {
		NSString* promoLine = NSLocalizedString(@"I sent this email with reMail: http://www.remail.com/s", nil);
		NSString* body = [NSString stringWithFormat:@"\n\n%@", promoLine];
		[mailCtrl setMessageBody:body isHTML:NO];
	}
	
	[self presentModalViewController:mailCtrl animated:YES];
	[mailCtrl release];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
	return;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end

