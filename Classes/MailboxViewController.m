//
//  MailboxViewController.m
//  NextMailIPhone
//
//  Created by Gabor Cselle on 1/13/09.
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

#import "MailboxViewController.h"
#import "MailCell.h"
#import "MailViewController.h"
#import "Email.h"
#import "AddEmailDBAccessor.h"
#import "SyncManager.h"
#import "AppSettings.h"
#import "BuchheitTimer.h"
#import "ProgressView.h"
#import "StringUtil.h"
#import "LoadingCell.h"
#import "DateUtil.h"
#import "GlobalDBFunctions.h"
#import "EmailProcessor.h"

@interface TextStyleSheetAllMail : TTDefaultStyleSheet
@end

@implementation TextStyleSheetAllMail

- (TTStyle*)plain {
	return [TTContentStyle styleWithNext:nil];
}
@end

@implementation MailboxViewController
@synthesize emailData;
@synthesize nResults;
@synthesize folderNum;

// the following two are expressed in terms of Emails, not Conversations!
int currentDBNumAllMail = 0; // current offset we're searching at

BOOL receivedAdditionalAllMail = NO; // whether we received an additionalResults call
BOOL moreResultsAllMail = NO; // are there more results after this?


UIImage* imgAttachmentAllMail = nil;

- (void)dealloc {
	[emailData release];
	[imgAttachmentAllMail release];
	imgAttachmentAllMail = nil;
	
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.emailData = nil;
}


-(void)runLoadDataWithDBNum:(int)dbNum {
	// run a search with given offset
	SearchRunner* searchManager = [SearchRunner getSingleton];
	
	receivedAdditionalAllMail = NO;
	moreResultsAllMail = NO;
	int nextDBNum = dbNum+1;
	
	if(self.folderNum == -1) {
		[searchManager allMailWithDelegate:self startWithDB:dbNum];
	} else {
		[searchManager folderSearch:self.folderNum withDelegate:self startWithDB:dbNum];
	}
	
	currentDBNumAllMail = nextDBNum;
}

-(NSString*)massageDisplayString:(NSString*)y {
	y = [StringUtil deleteQuoteNewLines:y];
	y = [StringUtil deleteNewLines:y];
	y = [StringUtil compressWhiteSpace:y];
	y = [y stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	y = [y stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	y = [y stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	return y;
}

-(void)insertRows:(NSDictionary*)info {
	@try {
		NSArray* y = [info objectForKey:@"data"];
		
		BOOL insertNew = (([y count] == 1) && [[[y objectAtIndex:0] objectForKey:@"syncingNew"] boolValue]);
		
		if(insertNew) {
			[self.emailData insertObject:[y objectAtIndex:0] atIndex:0];
		} else {
			[self.emailData addObjectsFromArray:y];
		}
		[self.tableView insertRowsAtIndexPaths:[info objectForKey:@"rows"] withRowAnimation:UITableViewRowAnimationNone];
	} @catch (NSException *exp) {
		NSLog(@"Exception in insertRows: %@", exp);
		NSLog(@"%@|%i|%i|%i|r%i", [info objectForKey:@"rows"], [self.emailData count], [info retainCount], [[info objectForKey:@"data"] retainCount], [[info objectForKey:@"rows"] retainCount]);
	}
	[info release];
}

-(void)loadResults:(NSArray*)searchResults {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray* elementsToAdd = [NSMutableArray arrayWithCapacity:100];
	NSMutableArray* rowsToAdd = [NSMutableArray arrayWithCapacity:100];
	@synchronized(self) {
		for(NSMutableDictionary* searchResult in searchResults) {
			// set people string to sender name or address
			NSString* senderName = [searchResult objectForKey:@"senderName"];
			senderName = [self massageDisplayString:senderName];
			NSString* senderAddress = [searchResult objectForKey:@"senderAddress"];
			
			if([senderName length] == 0 && [senderAddress length] == 0){
				[searchResult setObject:@"[unknown]" forKey:@"people"];
			} else if ([senderName length] == 0) {
				[searchResult setObject:senderAddress forKey:@"people"];
			} else {
				[searchResult setObject:senderName forKey:@"people"];
			}
			
			// massage display strings	
			NSString *body = [searchResult objectForKey:@"body"];
			[searchResult setObject:[self massageDisplayString:body] forKey:@"body"];	
			NSString *subject = [searchResult objectForKey:@"subject"];
			[searchResult setObject:[self massageDisplayString:subject] forKey:@"subject"];	
			
			NSNumber* newObj = [searchResult objectForKey:@"syncingNew"];
			
			if(newObj != nil && [newObj boolValue]) {
				// adding an entry from syncing new items 
				[elementsToAdd addObject:searchResult];
				[rowsToAdd addObject:[NSIndexPath indexPathForRow:0 inSection:0]];
			} else {
				[elementsToAdd addObject:searchResult];
				[rowsToAdd addObject:[NSIndexPath indexPathForRow:self.nResults inSection:0]];
			}
								 
			self.nResults++;
		}	
		
		[searchResults release]; // it was retained in SearchRunner!
		
		if([elementsToAdd count] > 0) {
			NSDictionary* info = [[NSDictionary alloc] initWithObjectsAndKeys:elementsToAdd, @"data", rowsToAdd, @"rows", nil]; // released in insertRows()
			[self performSelectorOnMainThread:@selector(insertRows:) withObject:info waitUntilDone:NO];
		}
	}
	
	[pool release];	
}

- (void)deliverSearchResults:(NSArray *)searchResults {
	NSOperationQueue* q = ((SearchRunner*)[SearchRunner getSingleton]).operationQueue;
	NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(loadResults:) object:searchResults];
	[q addOperation:op]; 
	[op release];
}


-(void)deliverAdditionalResults:(NSNumber*)d {
	receivedAdditionalAllMail = YES;
	moreResultsAllMail = [d boolValue];
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void)deliverProgressUpdate:(NSNumber *)progressNum {
	currentDBNumAllMail = [progressNum intValue];
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void)processorUpdate:(NSMutableDictionary*)data {
	// take whatever comes from from the EmailProcessor, and show it here
	
	int itemFolderNum = [[data objectForKey:@"folderNum"] intValue];
	
	if(self.folderNum != itemFolderNum) {
		return;
	}
	
	BOOL new = [[data objectForKey:@"syncingNew"] boolValue];
	
	if(!new && receivedAdditionalAllMail && moreResultsAllMail) {
		// we're syncing old stuff and we're not showing the last page yet
		return;
	}
	
	NSMutableDictionary* dataCopy = [data mutableCopy];
	
	[data release];
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	NSString* dateString = [data objectForKey:@"datetime"];
	NSDate* dateTime = [dateFormatter dateFromString:dateString];
	[dataCopy setObject:dateTime forKey:@"datetime"];
	[dateFormatter release];
	
	NSArray* y = [[NSArray alloc] initWithObjects:dataCopy, nil];
	[self deliverSearchResults:y];
}

-(void)emailDeleted:(NSNumber*)pk {
	for(int i = 0; i < [emailData count]; i++) {
		NSDictionary* email = [emailData objectAtIndex:i];
		
		NSNumber* emailPk = [email objectForKey:@"pk"];
		
		if([emailPk isEqualToNumber:pk]) {
			[emailData removeObjectAtIndex:i];
			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:i inSection:0];
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
			break;
		}
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary* email = [emailData objectAtIndex:indexPath.row];
	
	NSNumber* emailPk = [email objectForKey:@"pk"];
	NSLog(@"Deleting email with pk: %@ row: %i", emailPk, indexPath.row);
	
	SearchRunner* sm = [SearchRunner getSingleton];
	[sm deleteEmail:[emailPk intValue] dbNum:[[email objectForKey:@"dbNum"] intValue]];
	
	
	[emailData removeObjectAtIndex:indexPath.row];
	[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];	
}

-(LoadingCell*)createConvoLoadingCellFromNib {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"LoadingCell" owner:self options:nil];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
	LoadingCell* cell = nil;
	NSObject* nibItem = nil;
	while ((nibItem = [nibEnumerator nextObject]) != nil) {
		if([nibItem isKindOfClass: [LoadingCell class]]) {
			cell = (LoadingCell*)nibItem;
			break;
		}
	}
	return cell;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.tableView.rowHeight = 96.0f;
}

-(void)doLoad {
	self.nResults = 0;
	currentDBNumAllMail = 0;
	receivedAdditionalAllMail = NO;
	moreResultsAllMail = NO;
	
	self.emailData = [[NSMutableArray alloc] initWithCapacity:1];
	
	imgAttachmentAllMail = [UIImage imageNamed:@"attachment.png"];
	[imgAttachmentAllMail retain]; // released in "dealloc"

	//[sm registerForNewEmail:self]; (hehe - not for now)
	
	[self runLoadDataWithDBNum:currentDBNumAllMail];
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

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	SearchRunner *sem = [SearchRunner getSingleton];
	[sem cancel];
	
	EmailProcessor* ep = [EmailProcessor getSingleton];
	ep.updateSubscriber = nil;
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	self.tableView.rowHeight = 96;
	
	EmailProcessor* ep = [EmailProcessor getSingleton];
	ep.updateSubscriber = self;
}

- (void)viewDidAppear:(BOOL)animated {
	// animating to or from - reload unread, server state
    [super viewDidAppear:animated];
	if(animated) {
		[self.tableView reloadData];
	}
	
	[self.navigationController setToolbarHidden:NO animated:animated];	
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"SearchResultsViewController reveived memory warning - dumping cache");
}

-(MailCell*)createMailCellFromNib {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"MailCell" owner:self options:nil];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
	MailCell* mailCell = nil;
	NSObject* nibItem = nil;
	while ((nibItem = [nibEnumerator nextObject]) != nil) {
		if([nibItem isKindOfClass: [MailCell class]]) {
			mailCell = (MailCell*)nibItem;
			[mailCell setupText];
			break;
		}
	}
	return mailCell;
}

#pragma mark Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	int add = 1;
	return [self.emailData count] + add;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary* y;
		
	if (indexPath.row < [self.emailData count]) {
		y = [self.emailData objectAtIndex:indexPath.row];
	} else {
		y = nil; // "More Results" link
	}
	
	if(y == nil) { // "Loading" or "More Results"
		if(!receivedAdditionalAllMail) {
			static NSString *loadingIdentifier = @"LoadingCell"; 
			LoadingCell* cell = (LoadingCell*)[tableView dequeueReusableCellWithIdentifier:loadingIdentifier]; 
			if (cell == nil) { 
				cell = [self createConvoLoadingCellFromNib];
			} 
			
			if(![cell.activityIndicator isAnimating]) {
				[cell.activityIndicator startAnimating];
			}
			cell.label.text = [NSString stringWithFormat:NSLocalizedString(@"Loading Mail %i ...", nil), MAX(1,currentDBNumAllMail)];
			
			return cell; 
		}
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"More"]; 
		
		if (cell == nil) { 
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"More"] autorelease]; 
		} 
		
		if(moreResultsAllMail) {
			cell.textLabel.text = @"More Mail"; 
			cell.textLabel.textColor = [UIColor blackColor];
			cell.imageView.image = [UIImage imageNamed:@"moreResults.png"];
		} else {
			if([self.emailData count] == 0) {
				cell.textLabel.text = @"No mail"; 
			} else {
				cell.textLabel.text = @"No more mail";
			}
			cell.textLabel.textColor = [UIColor grayColor];
			cell.imageView.image = nil;
		}
		return cell; 
	}
    
    static NSString *cellIdentifier = @"MailCell";
    
    MailCell *cell = (MailCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [self createMailCellFromNib];
	}
	
	if([[y objectForKey:@"hasAttachment"] intValue] > 0) {
		cell.attachmentIndicator.image = imgAttachmentAllMail;
		[cell.attachmentIndicator setHidden:NO];
	} else {
		[cell.attachmentIndicator setHidden:YES];
	}
	
	NSDate* date = [y objectForKey:@"datetime"];
	if (date != nil) {
		DateUtil *du = [DateUtil getSingleton];
		cell.dateLabel.text = [du humanDate:date];
	} else {
		cell.dateLabel.text = @"(unknown)";
	}
	
	[cell setTextWithPeople:[y objectForKey:@"people"] withSubject: [y objectForKey:@"subject"] withBody:[y objectForKey:@"body"]];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	int addPrevious = 0;
	
	if(indexPath.row >= [self.emailData count] + addPrevious) {
		// Clicked "More Results"
		if(moreResultsAllMail) {
			[self runLoadDataWithDBNum:currentDBNumAllMail+1];
			[self.tableView reloadData];
			return;
		} else { 
			// clicked "no more results"
			return;
		}
	}
	
	// speed optimization (leads to incorrectness): cancel SearchRunner when user selects a result
	SearchRunner *sem = [SearchRunner getSingleton];
	[sem cancel];
	
	MailViewController *mailViewController = [[MailViewController alloc] init];
	NSDictionary* y = [self.emailData objectAtIndex:indexPath.row-addPrevious];
	
	int emailPk = [[y objectForKey:@"pk"] intValue];
	int dbNum = [[y objectForKey:@"dbNum"] intValue];
	mailViewController.emailPk = emailPk;
	mailViewController.dbNum = dbNum;
	mailViewController.isSenderSearch = NO;
	mailViewController.query = nil;
	mailViewController.deleteDelegate = self;
	
	[self.navigationController pushViewController:mailViewController animated:YES];
	[mailViewController release];
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}


@end

