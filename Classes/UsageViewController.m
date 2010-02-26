//
//  UsageViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 10/8/09.
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

#import "UsageViewController.h"
#import "AppSettings.h"
#import "ContactDBAccessor.h"
#import "SearchRunner.h"
#import "StringUtil.h"

@implementation UsageViewController
@synthesize rankHeader;
@synthesize rank0;
@synthesize rank1;
@synthesize rank2;
@synthesize rank3;
@synthesize rank4;	
@synthesize recommendTitle;
@synthesize recommendSubtitle;
@synthesize contactData;
@synthesize lastRowClicked;
@synthesize tableViewCopy;

- (void)dealloc {
	[contactData release];
	
    [super dealloc];
}

-(void)viewDidUnload {
	[super viewDidUnload];
	
	self.contactData = nil;
	self.rankHeader = nil;
	self.rank0 = nil;
	self.rank1 = nil;
	self.rank2 = nil;
	self.rank3 = nil;
	self.rank4 = nil;
	self.recommendTitle = nil;
	self.recommendSubtitle = nil;
	self.contactData = nil;
	self.tableViewCopy = nil;
}

- (id)initWithStyle:(UITableViewStyle)style {
    // Override initWithStyle: if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
    if (self = [super initWithStyle:style]) {
		self.contactData = [NSMutableArray array];
    }
    return self;
}

-(IBAction)rankClicked:(UIView*)sender {
	NSString* rankName = @"";
	int searched = sender.tag;
	
	switch (searched) {
		case 0:
			rankName = @"reMail Newbie";
			break;
		case 25:
			rankName = @"reMail Explorer";
			break;
		case 50:
			rankName = @"reMail Commander";
			break;
		case 75:
			rankName = @"reMail Captain";
			break;
		case 100:
			rankName = @"reMail Superstar";
			break;
	}
	
	NSString* blah = [NSString stringWithFormat:NSLocalizedString(@"You need to search %i times to be a %@", nil), searched, rankName];
	
	UIAlertView* as = [[UIAlertView alloc] initWithTitle:rankName message:blah delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[as show];
	[as release];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	self.title = @"Usage";
	
	NSString* rankName;
	
	self.rank0.tag = 0;
	self.rank1.tag = 25;
	self.rank2.tag = 50;
	self.rank3.tag = 75;
	self.rank4.tag = 100;
	
	//TODO(gabor): All this repetition repetition ...
	if([AppSettings searchCount] < 25) {
		rankName = @"reMail Newbie";
	} else if ([AppSettings searchCount] < 50) {
		rankName = @"reMail Explorer";
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
	} else if ([AppSettings searchCount] < 75) {
		rankName = @"reMail Commander";
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
	} else if ([AppSettings searchCount] < 100) {
		rankName = @"reMail Captain";
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank3 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank3 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
	} else {
		rankName = @"reMail Superstar";
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank1 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank2 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank3 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank3 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
		[self.rank4 setBackgroundImage:[UIImage imageNamed:@"ranksTrophy.png"] forState:UIControlStateNormal];
		[self.rank4 setBackgroundImage:[UIImage imageNamed:@"ranksNoTHighlight.png"] forState:UIControlStateHighlighted];
	}
	
	NSString* rankHeaderText = [NSString stringWithFormat:NSLocalizedString(@"You've searched %i times. You're a %@.", nil), [AppSettings searchCount], rankName];
	self.rankHeader.text = rankHeaderText;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	@synchronized(self) {
		return [self.contactData count] + 1;
	}
	return 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"UsageList";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
	
	if(indexPath.row >= [self.contactData count]) {
		cell.textLabel.text = NSLocalizedString(@"Enter email address ...", nil);
		cell.detailTextLabel.text = NSLocalizedString(@"Send recommendation to friend's email address", nil);
		cell.imageView.image = nil;
		
		return cell;
	}
	
	NSDictionary* contact = [self.contactData objectAtIndex:indexPath.row];
	NSString* addresses = [[contact objectForKey:@"emailAddresses"] stringByReplacingOccurrencesOfString:@"'" withString:@""];
	cell.textLabel.text = [contact objectForKey:@"name"];
	cell.detailTextLabel.text = addresses;
	cell.imageView.image = [UIImage imageNamed:@"convoPerson3.png"];
	
    return cell;
}

-(void)doLoad {
	sqlite3_stmt *loadStmt = nil;
	
	NSString *queryString = @"SELECT c.pk, c.name, c.email_addresses FROM contact_name c WHERE c.sent_invite IS NULL ORDER BY c.occurrences DESC LIMIT 100";
	int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [queryString UTF8String], -1, &loadStmt, nil);	
	if (dbrc != SQLITE_OK) {
		NSLog(@"Failed preparing loadStmt with error %s", sqlite3_errmsg([[ContactDBAccessor sharedManager] database]));
		return;
	}
	
	NSMutableArray* y = [NSMutableArray arrayWithCapacity:100];
	int count = 0;
	while(sqlite3_step(loadStmt) == SQLITE_ROW) {
		int pk = sqlite3_column_int(loadStmt, 0);
		NSNumber* pkNum = [NSNumber numberWithInt:pk];
		
		NSString *name = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(loadStmt, 1);
		if(sqlVal != nil)
			name = [NSString stringWithUTF8String:sqlVal];
		
		NSString *emailAddresses = @"";
		sqlVal = (const char *)sqlite3_column_text(loadStmt, 2);
		if(sqlVal != nil)
			emailAddresses = [NSString stringWithUTF8String:sqlVal];
		
		NSDictionary* res = [NSDictionary dictionaryWithObjectsAndKeys:pkNum, @"pk", name, @"name", emailAddresses, @"emailAddresses", nil];
		
		[y addObject:res];
		count++;
	}
	
	sqlite3_reset(loadStmt);
	sqlite3_finalize(loadStmt);
	
	@synchronized(self) {
		self.contactData = y;
	}
	
	[self.tableViewCopy performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void)markContactSent:(int)pk {
	// record a query for queryText - update the DB accordingly 
	
	sqlite3_stmt *updateStmt = nil;
	
	NSString *stmtString = @"UPDATE contact_name SET sent_invite = 1 WHERE PK = ?";
	int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [stmtString UTF8String], -1, &updateStmt, nil);	
	if (dbrc != SQLITE_OK) 	{
		NSLog(@"Failed step in markContactSent with error %s", sqlite3_errmsg([[ContactDBAccessor sharedManager] database]));
		return;
	}
		
	sqlite3_bind_int(updateStmt, 1, pk);
	if (sqlite3_step(updateStmt) != SQLITE_DONE) {
		NSLog(@"==========> Error updating markContactSent");
	}
	sqlite3_reset(updateStmt);
	sqlite3_finalize(updateStmt);
	
	return;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
	
	if(result == MFMailComposeResultSent) {
		// mark as sent
		if([self.contactData count] > self.lastRowClicked) {
			NSDictionary* contact = [self.contactData objectAtIndex:self.lastRowClicked];
			int pk = [[contact objectForKey:@"pk"] intValue];
			[self markContactSent:pk];
		
			[self.contactData removeObjectAtIndex:self.lastRowClicked];
		
			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:self.lastRowClicked inSection:0];
			[self.tableViewCopy deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
			
			[self.tableViewCopy reloadData];
		}
		
		
		[AppSettings incrementRecommendationCount];		
	}
	
	return;
}

-(void)composeEmailTo:(NSString*)emailAddress {
	if (![MFMailComposeViewController canSendMail]) {
		//TODO(gabor): Show warning - this device is not configured to send email.
		return;
	}
	
	MFMailComposeViewController *mailCtrl = [[MFMailComposeViewController alloc] init];
	mailCtrl.mailComposeDelegate = self;
	
	NSString* body = NSLocalizedString(@"Hi!\n\nYou should try reMail.\n\nIt's an iPhone app that downloads all your email to your iPhone for fast full-text search.\n\nWebsite: http://www.remail.com/r", nil);
	
	if(emailAddress != nil) {
		[mailCtrl setToRecipients:[NSArray arrayWithObject:emailAddress]];
	}
	[mailCtrl setMessageBody:body isHTML:NO];
	[mailCtrl setSubject:NSLocalizedString(@"You should try reMail", nil)];
	
	[self presentModalViewController:mailCtrl animated:YES];
	[mailCtrl release];
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == actionSheet.cancelButtonIndex) {
		return;
	}
	
	NSString* buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
	
	[self composeEmailTo:buttonTitle];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self.tableViewCopy deselectRowAtIndexPath:indexPath animated:NO];
	
	self.lastRowClicked = indexPath.row;
	
	// show selection actionsheet?
	NSString* emailAddresses;
	NSString* name;
	BOOL freeformAddress = NO;
	if(indexPath.row >= [self.contactData count]) {
		freeformAddress = YES;
		emailAddresses = @"";
		name = @"";
	} else {
		NSDictionary* contact = [self.contactData objectAtIndex:indexPath.row];
		emailAddresses = [contact objectForKey:@"emailAddresses"];
		name = [contact objectForKey:@"name"];
	}
	
	BOOL showActionSheet = [StringUtil stringContains:emailAddresses subString:@"', '"];
	
	if(freeformAddress) {
		[self composeEmailTo:nil];
	} else if(showActionSheet) {
		NSString* stripped = [[emailAddresses substringToIndex:[emailAddresses length]-1] substringFromIndex:1];
		NSArray* addresses = [StringUtil split:stripped atString:@"', '"];
		
		// only the first 4
		NSArray* addressesCut = [addresses subarrayWithRange:NSMakeRange(0, MIN(4,[addresses count]))];
		UIActionSheet* as = [[UIActionSheet alloc] initWithTitle:name delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
		
		for(NSString* address in addressesCut) {
			[as addButtonWithTitle:address];
		}
		[as addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
		as.cancelButtonIndex = [addressesCut count];
		
		[as showInView:[self.view window]];
		[as release];
	} else {
		NSString* emailAddress = [emailAddresses stringByReplacingOccurrencesOfString:@"'" withString:@""];
		[self composeEmailTo:emailAddress];
	}	
}


- (void)viewDidLoad {
    [super viewDidLoad];
	
	SearchRunner* sm = [SearchRunner getSingleton];
	NSInvocationOperation *nextOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(doLoad) object:nil];
	[sm.operationQueue addOperation:nextOp];
	[nextOp release];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/
@end

