//
//  StoreViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 11/11/09.
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

//  TODO(gabor): NEED TO LOCALIZE STRINGS IN HERE!!!

#import "StoreViewController.h"
#import "StoreItemViewController.h"
#import "StoreObserver.h"
#import "BuchheitTimer.h"
#import "AppSettings.h"
#import "ReMailAppDelegate.h"
#import "StoreItemCell.h"
#import "LoadingCell.h"

@implementation StoreViewController
@synthesize products;

- (void)dealloc {
    [super dealloc];
	[products release];
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


-(void)requestProductData {
	NSSet* pidsToSell = [NSSet setWithObjects:@"RM_NOADS", @"RM_IMAP", @"RM_RACKSPACE", nil];
	SKProductsRequest *request= [[SKProductsRequest alloc] initWithProductIdentifiers:pidsToSell];
	request.delegate = self;
	[request start];
}

-(void)reloadProducts {
	[self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	StoreObserver* so = [StoreObserver getSingleton];
	so.delegate = self;
	
	[self requestProductData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	StoreObserver* so = [StoreObserver getSingleton];
	so.delegate = self;
	
	[self reloadProducts];
}



- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	
	if (![SKPaymentQueue canMakePayments]) {
		UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"In-App Purchases Disabled", nil) 
															 message:NSLocalizedString(@"You need to enable in-app purchases in Home > Settings > General > Restrictions to buy features", nil)
															delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alertView show];
		[self.navigationController popViewControllerAnimated:YES];
	}
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark Table view methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section == 0) {
		if(self.products == nil) {
			return 1;
		} else {
			return [self.products count];
		}
	} else { // section == 1
		return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch(section) {
		case 0:
			return NSLocalizedString(@"Features to Buy", nil);
		case 1:
			return NSLocalizedString(@"Restore Purchases", nil);
		default:
			return @"";
	}
}

-(LoadingCell*)createLoadingCellFromNib {
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


-(StoreItemCell*)createStoreItemCellFromNib {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"StoreItemCell" owner:self options:nil];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
	StoreItemCell* cell = nil;
	NSObject* nibItem = nil;
	while ((nibItem = [nibEnumerator nextObject]) != nil) {
		if([nibItem isKindOfClass: [StoreItemCell class]]) {
			cell = (StoreItemCell*)nibItem;
			break;
		}
	}
	return cell;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.section == 0) {
		if(self.products == nil) {
			static NSString *CellIdentifier = @"LoadingCell";
			LoadingCell *cell = (LoadingCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil) {
				cell = [self createLoadingCellFromNib];
			}			
			
			[cell.activityIndicator startAnimating];
			cell.label.text = NSLocalizedString(@"Loading Products ...", nil);
			
			return cell;
		} else {
			static NSString *CellIdentifier = @"StoreItemCell";
			StoreItemCell *cell = (StoreItemCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
			if (cell == nil) {
				cell = [self createStoreItemCellFromNib];
			}			
			
			SKProduct* product = [self.products objectAtIndex:indexPath.row];
			UIImage* image = [UIImage imageNamed:[NSString stringWithFormat:@"featureIcon%@.png", product.productIdentifier]];
			cell.productIcon.image = image;
			cell.titleLabel.text = product.localizedTitle;
			
			if([AppSettings featurePurchased:product.productIdentifier]) {
				[cell.priceLabel setHidden:YES];
				[cell.purchasedIcon setHidden:NO];
			} else {
				[cell.priceLabel setHidden:NO];
				[cell.purchasedIcon setHidden:YES];
				
				cell.detailTextLabel.backgroundColor = [UIColor yellowColor];
				NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
				[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
				[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
				[numberFormatter setLocale:product.priceLocale];
				NSString *formattedString = [numberFormatter stringFromNumber:product.price];
				cell.priceLabel.text = formattedString;
			}
			
			return cell;
		}
	} else {
		static NSString *CellIdentifier = @"RestoreCell";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		}
		
		cell.textLabel.text = NSLocalizedString(@"Restore Purchases", nil); 
		cell.detailTextLabel.text = NSLocalizedString(@"Recover your purchases from prior installs.", nil); 
		
		return cell;
	}
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(indexPath.section == 1) {
		// Use iTunes Connect restoreTransaction
		NSLog(@"Restore transactions ...");
		UIApplication* app = [UIApplication sharedApplication];
		ReMailAppDelegate* appDelegate = app.delegate;
		[appDelegate pingHome];
		
		[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	} else {
		if(self.products == nil) {
			// Product list not loaded yet!
			return;
		}
		
		SKProduct* product = [self.products objectAtIndex:indexPath.row];
		
		if([AppSettings featurePurchased:product.productIdentifier]) {
			UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Already Purchased", nil) 
																 message:NSLocalizedString(@"This feature has already been purchased.", nil)
																delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
			[alertView show];
			
			return;
		}
		
		StoreItemViewController *vc = [[StoreItemViewController alloc] initWithNibName:@"StoreItem" bundle:nil];
		vc.title = product.localizedTitle;
		vc.product = product;
		[self.navigationController pushViewController:vc animated:YES];
		[vc release];
	}
}

#pragma mark StoreObserver delegate stuff
-(void)showError:(NSError*)error {
	UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:error.localizedDescription
														 message:error.localizedFailureReason
														delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	if(response.products == nil || [response.products count] == 0) {
		UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Product List Error", nil) 
															 message:NSLocalizedString(@"Error loading product list from the iTunes server.", nil)
															delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alertView show];
	}
	
	NSMutableArray* a = [NSMutableArray arrayWithArray:response.products];
	
	NSSortDescriptor* desc = [[[NSSortDescriptor alloc] initWithKey:@"price" ascending:NO] autorelease];
	NSSortDescriptor* desc2 = [[[NSSortDescriptor alloc] initWithKey:@"productIdentifier" ascending:YES] autorelease];
	
	[a sortUsingDescriptors:[NSArray arrayWithObjects:desc, desc2, nil]];
	
	NSLog(@"Products count: %i", [response.products count]); 
	self.products = a;
	[self reloadProducts];
    [request autorelease];
}

-(void)restoreComplete {
	UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Restore Complete", nil) 
														 message:NSLocalizedString(@"Your purchases have been restored!", nil)
														delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];
	
	[self reloadProducts];
}
@end

