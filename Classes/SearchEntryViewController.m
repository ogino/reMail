//
//  SearchEntryViewController.m
//  InboxSearch
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

#import "SearchEntryViewController.h"
#import "SearchResultsViewController.h"
#import "PastQuery.h"
#import "BuchheitTimer.h"
#import "SyncManager.h"
#import "DateUtil.h"
#import "AppSettings.h"
#import "AutocompleteCell.h"

@implementation SearchEntryViewController
@synthesize autocompleting;
@synthesize autocompletions;
@synthesize queryHistory;
@synthesize dates;
@synthesize types;
@synthesize lastSearchString;

BOOL autoCompleteMode;

- (void)dealloc {
	[autocompletions release];
	[queryHistory release];
	[dates release];

	[lastSearchString release];
	
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.autocompletions = nil;
	self.queryHistory = nil;
	self.dates = nil;
	self.lastSearchString = nil;
}

-(void)reloadQueries {	
	//TODO(einar): Is this autoreleased?
	NSDictionary* pastQueries = [PastQuery recentQueries];
	self.queryHistory = [pastQueries objectForKey:@"queries"];
	self.dates = [pastQueries objectForKey:@"datetimes"];
	self.types = [pastQueries objectForKey:@"searchTypes"];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	/* // Not showing dates / times anymore
	DateUtil* du = [DateUtil getSingleton];
	for(int i = 0; i < [self.dates count]; i++) {
		NSString* d = [du humanDate:[self.dates objectAtIndex:i]];
		[self.dates replaceObjectAtIndex:i withObject:d];
	}*/
	
	[dateFormatter release];
}

-(SearchResultsViewController*)createSearchResultsVC {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"SearchResults" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator]; 
	SearchResultsViewController *res = nil;
	NSObject* nibItem = NULL;
    while ( (nibItem = [nibEnumerator nextObject]) != NULL) { 
        if ( [nibItem isKindOfClass: [SearchResultsViewController class]]) { 
			res = (SearchResultsViewController*) nibItem;
			break;
		}
	}
	
	res.toolbarItems = self.toolbarItems;

	return res;
}

-(void)goFTSearch:(NSString*)queryText {
	[AppSettings incrementSearchCount];
	
	SearchResultsViewController* res = [self createSearchResultsVC];
	
	res.query = queryText;
	res.toolbarItems = self.toolbarItems;
	res.isSenderSearch = NO;
	
	[PastQuery recordQuery:queryText withType:0];
	
	// start the search
	[res doLoad];
	[self.navigationController pushViewController:res animated:YES];
}

-(void)goSenderSearch:(NSString*)senderName withParams:(NSDictionary*)params {
	[AppSettings incrementSearchCount];
	
	SearchResultsViewController* res = [self createSearchResultsVC];
	
	res.query = senderName;
	res.senderSearchParams = params;
	res.isSenderSearch = YES;
	
	[PastQuery recordQuery:senderName withType:1]; //TODO(gabor): need to record that this is a sender search
	
	// start the search
	[res doLoad];
	[self.navigationController pushViewController:res animated:YES];
}

-(void)goSenderSearch:(NSString*)senderName {
	NSDictionary* res = [[SearchRunner getSingleton] findContact:senderName];
	if (res == nil) {
		return; // some error?
	} else {
		[self goSenderSearch:senderName withParams:res];
	}
}

- (void)searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
	NSLog(@"searchDisplayControllerWillBeginSearch: %@", controller.searchBar.text);
	autoCompleteMode = YES;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
	NSLog(@"searchDisplayControllerDidEndSearch");
	autoCompleteMode = NO;
	[self.tableView reloadData];
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	SearchRunner *sem = [SearchRunner getSingleton];
	[sem cancel];
	
	[self reloadQueries];
	
	[self.tableView reloadData];
	
	[AppSettings setLastpos:@"search"];
}

-(void)viewDidLoad {
	self.searchDisplayController.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	self.searchDisplayController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
	
	self.title = NSLocalizedString(@"reMail Search", @"title");
}

-(void)doLoad {
	self.queryHistory = [NSArray array];
	self.dates = [NSArray array];
	self.types = [NSArray array];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(autoCompleteMode) {
		// Apple bug: when returning from SearchResults, the tableView is set wrong. 
		// That's why we use the autoCompleteMode flag, set in searchDisplayControllerWillBeginSearch
		return NSLocalizedString(@"Autocompletions", nil);
	} else if(tableView == self.tableView) {
		return NSLocalizedString(@"Search History", nil);
	} else {
		return NSLocalizedString(@"Autocompletions", nil);
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (self.tableView == tableView) {
		return [self.queryHistory count];
	} else {
		if([self.autocompletions count] > 0) {
			return [self.autocompletions count];
		} else {
			return 1;
		}
	}
}

/*
-(UITableViewCell*)createNewAutocompleteCell { 
	UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"AutocompleteCell"];
	cell.imageView.image = [UIImage imageNamed:@"convoPerson2.png"];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
	return cell; 
}*/

-(AutocompleteCell*)createNewAutocompleteCell {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"AutocompleteCell" owner:self options:nil];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
	AutocompleteCell* cell = nil;
	NSObject* nibItem = nil;
	while ((nibItem = [nibEnumerator nextObject]) != nil) {
		if([nibItem isKindOfClass: [AutocompleteCell class]]) {
			cell = (AutocompleteCell*)nibItem;
			[cell setupText];
			break;
		}
	}
	return cell;
}


-(UITableViewCell*) createNewSearchHistoryCell { 
	UITableViewCell* cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SearchPersonHistoryCell"] autorelease];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
	
	return cell; 
} 

-(NSString*)markup:(NSString*)name query:(NSString*)searchString {
	searchString = [searchString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	searchString = [searchString stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	searchString = [searchString stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	
	NSRange r = [name rangeOfString:searchString options:NSCaseInsensitiveSearch];
	if(r.location == NSNotFound) {
		return name;
	}
	
	name = [name stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	name = [name stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	name = [name stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	
	NSMutableString* s = [NSMutableString stringWithString:name];
	[s insertString:@"</span>" atIndex:r.location+r.length];
	[s insertString:@"<span class=\"redBox\">" atIndex:r.location];
	
	return s;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	if (self.tableView == tableView) {
		// search history mode
		UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"SearchHistoryCell"];
		if (cell == nil) {
			cell = [self createNewSearchHistoryCell];
		}
		
		if([self.queryHistory count] <= indexPath.row || [self.dates count] <= indexPath.row) {
			// overflow
			cell.textLabel.text = @"";
			cell.textLabel.textColor = [UIColor blackColor];
			cell.detailTextLabel.text = @"";
			return cell;
		}
		cell.textLabel.text = (NSString*)[self.queryHistory objectAtIndex:indexPath.row];
		cell.detailTextLabel.text = (NSString*)[self.dates objectAtIndex:indexPath.row];

		if([[self.types objectAtIndex:indexPath.row] intValue] == 0) {
			cell.imageView.image = [UIImage imageNamed:@"textSearch.png"];
		} else {
			cell.imageView.image = [UIImage imageNamed:@"convoPerson2.png"];
		}
		return cell;
	} else {
		if([self.autocompletions count] == 0) {
			// "No autocompletions" cell
			UITableViewCell* cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"SearchHistoryCell"];
			if (cell == nil) {
				cell = [self createNewSearchHistoryCell];
			}
			if(!self.autocompleting || ([self.lastSearchString length] > 0 && [self.autocompletions count] == 0)) {
				cell.textLabel.text = NSLocalizedString(@"No autocompletions", nil);
			} else {
				cell.textLabel.text = NSLocalizedString(@"Autocompleting ...", nil);
			}			
			
			cell.textLabel.textColor = [UIColor darkGrayColor];
			return cell;
		}

		// autocomplete mode
		AutocompleteCell* acell = (AutocompleteCell*)[tableView dequeueReusableCellWithIdentifier:@"AutocompleteCell"];
		if (acell == nil) {
			acell = [self createNewAutocompleteCell];
		}		
		
		NSDictionary* autocompletion = nil;
		@synchronized(self) {
			if(indexPath.row < [self.autocompletions count]) {
				autocompletion = [self.autocompletions objectAtIndex:indexPath.row];
				// this makes sure the autocompletion+contents don't get garbage-collected as we're displaying it.
				[autocompletion retain];
			}
		}
		
		if(autocompletion == nil) {
			// overflow
			acell.imageView.image = nil;
			acell.detailTextLabel.text = @"";
			[acell setName:@"" withAddresses:@""];
			return acell;
		}		
		
		acell.imageView.image = [UIImage imageNamed:@"convoPerson3.png"];
		NSString* name = [autocompletion objectForKey:@"name"];
		name = [self markup:name query:self.lastSearchString];
		
		// need to get rid of the "'"s before displaying text to the user
		NSString* addresses = [[autocompletion objectForKey:@"emailAddresses"] stringByReplacingOccurrencesOfString:@"'" withString:@""];
		[acell setName:name withAddresses:addresses];
		[autocompletion release];
		
		return acell;
	}
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[self.searchDisplayController.searchBar resignFirstResponder];
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(self.tableView == tableView) {
		NSString *queryText = [self.queryHistory objectAtIndex:indexPath.row];
		if([[self.types objectAtIndex:indexPath.row] intValue] == 1) {
			// sender search
			[self goSenderSearch:queryText];
		} else {
			// full-text search
			[self goFTSearch:queryText];
		}
	} else {
		if(indexPath.row >= [self.autocompletions count]) {
			return;
		}
		
		NSDictionary* autocompletion = [self.autocompletions objectAtIndex:indexPath.row];
		NSString* senderName = [autocompletion objectForKey:@"name"];
		[self goSenderSearch:senderName withParams:autocompletion];
	}
}

-(void)runAutocomplete {
	NSString* currentString = self.searchDisplayController.searchBar.text;
	
	if (self.lastSearchString == nil) {
		self.lastSearchString = @"";
	}
	
	if ([currentString isEqualToString:self.lastSearchString]) {
		return;
	}

	if([self.lastSearchString length] > 0 && [StringUtil stringStartsWith:currentString subString:self.lastSearchString] && [self.autocompletions count] == 0) {
		// don't search if there were no autocompletions last time either
		self.autocompleting = NO;
		return;
	}
	
	self.lastSearchString = [currentString copy];
	[self.lastSearchString release];	
	
	NSString* autocompleteSearchString = [NSString stringWithFormat:@"%@*", currentString];
	
	//Invoke query parser and auto complete
	SearchRunner* searchManager = [SearchRunner getSingleton];
	[searchManager autocomplete:autocompleteSearchString withDelegate:self];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	self.autocompleting = YES;
	NSTimer* timer  = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(runAutocomplete) userInfo:nil repeats:NO];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	
}	

- (void)deliverAutocompleteResult:(NSDictionary *)result {
	@synchronized(self) {
		self.autocompletions = (NSArray*)result;
	}
	
	self.autocompleting = NO;
	
	[self.searchDisplayController.searchResultsTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}


-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBarLocal{
	[searchBarLocal resignFirstResponder];
	NSString* queryString = searchBarLocal.text;

	[self goFTSearch:queryString];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"SearchEntryViewController received memory warning");
}

#pragma mark Rotation
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
