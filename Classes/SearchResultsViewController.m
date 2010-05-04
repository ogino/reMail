//
//  SearchResultsViewController.m
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

#import "SearchResultsViewController.h"
#import "MailViewController.h"
#import "MailCell.h"
#import "Email.h"
#import "SyncManager.h"
#import "StringUtil.h"
#import "ActivityIndicator.h"
#import "LoadingCell.h"
#import "DateUtil.h"

@implementation SearchResultsViewController
@synthesize emailData;
@synthesize query;
@synthesize senderSearchParams;
@synthesize isSenderSearch;
@synthesize nResults;

// the following two are expressed in terms of Emails, not Conversations!
int currentDBNum = 0; // current offset we're searching at

BOOL receivedAdditional = NO; // whether we received an additionalResults call
BOOL moreResults = NO; // are there more results after this?

static NSDateFormatter *dateFormatter = nil;

UIImage* imgAttachment = nil;

- (void)dealloc {
	[query release];
	[emailData release];
	
	if (imgAttachment != nil) {
		[imgAttachment release];
	}
	
	if (dateFormatter != nil) {
		[dateFormatter release];
	}

    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.query = nil;
	self.emailData = nil;
}

-(void)updateTitle {
	if(self.isSenderSearch) {
		// no quotes for sender Search;
		self.title = self.query;
	} else {
		self.title = [NSString stringWithFormat: @"\"%@\"", self.query];
	}
}

-(void)runSearchCreateDataWithDBNum:(int)dbNum {
	// run a search with given offset
	SearchRunner* searchManager = [SearchRunner getSingleton];

	receivedAdditional = NO;
	moreResults = NO;
	int nextDBNum = dbNum+1;
	
	if(self.isSenderSearch) {
		NSString* senderAddresses = [self.senderSearchParams objectForKey:@"emailAddresses"];

		int dbMin = [[self.senderSearchParams objectForKey:@"dbMin"] intValue];
		int dbMax = [[self.senderSearchParams objectForKey:@"dbMax"] intValue];

		[searchManager senderSearch:senderAddresses withDelegate:self startWithDB:dbNum dbMin:dbMin dbMax:dbMax];
	} else {
		NSArray* snippetDelims = [NSArray arrayWithObjects:@"$$$$mark$$$$",@"$$$$endmark$$$$", nil];
		[searchManager ftSearch:self.query withDelegate:self withSnippetDelims:snippetDelims startWithDB:dbNum];
	}

	currentDBNum = nextDBNum;
	[self updateTitle];
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
		[self.emailData addObjectsFromArray:[info objectForKey:@"data"]];
		[self.tableView insertRowsAtIndexPaths:[info objectForKey:@"rows"] withRowAnimation:UITableViewRowAnimationFade];
	} @catch (NSException *exp) {
		NSLog(@"Exception in SRinsertRows: %@", exp);
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

			if(self.isSenderSearch) {
				if([senderName length] == 0 && [senderAddress length] == 0){
					[searchResult setObject:@"[unknown]" forKey:@"people"];
				} else if ([senderName length] == 0) {
					[searchResult setObject:[NSString stringWithFormat:@"<span class=\"redBox\">%@</span>", senderAddress] forKey:@"people"];
				} else {
					[searchResult setObject:[NSString stringWithFormat:@"<span class=\"redBox\">%@</span>", senderName] forKey:@"people"];
				}
			} else {
				if([senderName length] == 0 && [senderAddress length] == 0){
					[searchResult setObject:@"[unknown]" forKey:@"people"];
				} else if ([senderName length] == 0) {
					[searchResult setObject:senderAddress forKey:@"people"];
				} else {
					[searchResult setObject:senderName forKey:@"people"];
				}
			}
			
			// massage display strings	
			NSString *body = [StringUtil trim:[searchResult objectForKey:@"body"]];
			if([body length] == 0) {
				[searchResult setObject:NSLocalizedString(@"[empty]",nil) forKey:@"body"];	
			} else {
				[searchResult setObject:[self massageDisplayString:body] forKey:@"body"];	
			}
			NSString *subject = [searchResult objectForKey:@"subject"];
			if([subject length] == 0) {
				[searchResult setObject:NSLocalizedString(@"[empty]",nil) forKey:@"subject"];	
			} else {
				[searchResult setObject:[self massageDisplayString:subject] forKey:@"subject"];	
			}
			
			// massage snippet
			if(!self.isSenderSearch) {
				NSString *snippet = [searchResult objectForKey:@"snippet"];
				snippet = [StringUtil deleteQuoteNewLines:snippet];
				snippet = [StringUtil deleteNewLines:snippet];
				snippet = [snippet stringByReplacingOccurrencesOfString:@">" withString:@""];
				snippet = [StringUtil compressWhiteSpace:snippet];
				snippet = [StringUtil trim:snippet];
				
				// put snippet parts into display where they're meant to be displayed
				NSArray* snippetParts = [snippet componentsSeparatedByString:@"{||}"];
				for(int i = 1; i < [snippetParts count]-1; i += 2) {
					NSString* header = (NSString*)[snippetParts objectAtIndex:i];
					NSString* content = (NSString*)[snippetParts objectAtIndex:i+1];		
					content = [content stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
					content = [content stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
					content = [content stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
					content = [content stringByReplacingOccurrencesOfString:@"$$$$endmark$$$$" withString:@"</span>"];
					
					if([header isEqualToString:@"0"]) { //metaString
						content = [content stringByReplacingOccurrencesOfString:@"$$$$mark$$$$" withString:@"<span class=\"redBox\">"];
						content = [StringUtil trim:content];
						[searchResult setObject:content forKey:@"people"];	
					} else if([header isEqualToString:@"1"]) {
						content = [content stringByReplacingOccurrencesOfString:@"$$$$mark$$$$" withString:@"<span class=\"yellowBox\">"];
						content = [StringUtil trim:content];
						[searchResult setObject:content forKey:@"subject"];	
					} else if([header isEqualToString:@"2"]) {
						content = [content stringByReplacingOccurrencesOfString:@"$$$$mark$$$$" withString:@"<span class=\"yellowBox\">"];
						content = [StringUtil trim:content];
						[searchResult setObject:content forKey:@"body"];	
					}
				}
			}
			
			[elementsToAdd addObject:searchResult];
			[rowsToAdd addObject:[NSIndexPath indexPathForRow:self.nResults inSection:0]];
			
			self.nResults++;
		}	
		
		[searchResults release]; 
		
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

-(void)reloadMoreItem {
	if(self.emailData != nil) {
		NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.emailData count] inSection:0];
		
		[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
	}
}

-(void)deliverAdditionalResults:(NSNumber*)d {
	receivedAdditional = YES;
	moreResults = [d boolValue];
		
	[self performSelectorOnMainThread:@selector(reloadMoreItem) withObject:nil waitUntilDone:NO];
}

- (void) deliverProgressUpdate:(NSNumber *)progressNum {
	currentDBNum = [progressNum intValue];
	
	[self performSelectorOnMainThread:@selector(reloadMoreItem) withObject:nil waitUntilDone:NO];
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


-(void)emailDeleted:(NSNumber*)pk {
	for(int i = 0; i < [emailData count]; i++) {
		NSDictionary* email = [emailData objectAtIndex:i];
		
		NSNumber* emailPk = [email objectForKey:@"pk"];
		
		if([emailPk isEqualToNumber:pk]) {
			[emailData removeObjectAtIndex:i];
			NSIndexPath* indexPath = [NSIndexPath indexPathForRow:i inSection:0];
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
		}
	}
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
	currentDBNum = 0;
	receivedAdditional = NO;
	moreResults = NO;
	
	dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	self.emailData = [[NSMutableArray alloc] initWithCapacity:1];
	[self updateTitle];
	
	imgAttachment = [UIImage imageNamed:@"attachment.png"];
	[imgAttachment retain]; // released in "dealloc"
	
	[self runSearchCreateDataWithDBNum:currentDBNum];
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	self.tableView.rowHeight = 96;
}

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	SearchRunner *sem = [SearchRunner getSingleton];
	[sem cancel];
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
		if(!receivedAdditional) {
			static NSString *loadingIdentifier = @"LoadingCell"; 
			LoadingCell* cell = (LoadingCell*)[tableView dequeueReusableCellWithIdentifier:loadingIdentifier]; 
			if (cell == nil) { 
				cell = [self createConvoLoadingCellFromNib];
			} 
				
			if(![cell.activityIndicator isAnimating]) {
				[cell.activityIndicator startAnimating];
			}
			cell.label.text = [NSString stringWithFormat:@"Searching Step %i ...", MAX(1,currentDBNum)]; // simpler than correctly sequencing currentDB across threads
				
			return cell; 
		}

		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"More"]; 
		
		if (cell == nil) { 
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"More"] autorelease]; 
		} 
			
		if(moreResults) {
			cell.textLabel.text = @"More Results"; 
			cell.textLabel.textColor = [UIColor blackColor];
			cell.imageView.image = [UIImage imageNamed:@"moreResults.png"];
		} else {
			if([self.emailData count] == 0) {
				cell.textLabel.text = @"No results"; 
			} else {
				cell.textLabel.text = @"No more results";
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
		cell.attachmentIndicator.image = imgAttachment;
		[cell.attachmentIndicator setHidden:NO];
	} else {
		[cell.attachmentIndicator setHidden:YES];
	}
	
	NSDate* date = [y objectForKey:@"datetime"];
	if (date != nil) {
		DateUtil* du = [DateUtil getSingleton];
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
		if(moreResults) {
			[self runSearchCreateDataWithDBNum:currentDBNum+1];
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
	mailViewController.isSenderSearch = self.isSenderSearch;
	mailViewController.query = self.query;
	mailViewController.deleteDelegate = self;

	[self.navigationController pushViewController:mailViewController animated:YES];
	[mailViewController release];
}

#pragma mark Rotation
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end

