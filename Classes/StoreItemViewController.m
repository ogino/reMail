//
//  StoreItemViewController.m
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

#import "StoreItemViewController.h"
#import "StoreObserver.h"
#import "AppSettings.h"
#import "UsageViewController.h"

@implementation StoreItemViewController

@synthesize product;
@synthesize productTitleLabel;
@synthesize productDescriptionLabel;
@synthesize productImageView;
@synthesize buyButton;
@synthesize recommendLabel;
@synthesize recommendButton;
@synthesize activityIndicator;


- (void)viewDidUnload {
	self.product = nil;
	self.productTitleLabel = nil;
	self.productDescriptionLabel = nil;
	self.productImageView = nil;
	self.buyButton = nil;
	self.activityIndicator = nil;
}

-(IBAction)purchase {
	SKPayment *payment = [SKPayment paymentWithProductIdentifier:self.product.productIdentifier];
	[[SKPaymentQueue defaultQueue] addPayment:payment];
	
	[self.buyButton setHidden:YES];
	[self.activityIndicator setHidden:NO];
	[self.activityIndicator startAnimating];
}

-(IBAction)recommend {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"Usage" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator]; 
	UsageViewController *uivc = nil;
	NSObject* nibItem = nil;
    while ( (nibItem = [nibEnumerator nextObject]) != NULL) { 
        if ( [nibItem isKindOfClass: [UsageViewController class]]) { 
			uivc = (UsageViewController*) nibItem;
			break;
		}
	}
	
	if(uivc == nil) {
		return;
	}
	
	uivc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	
	[self.navigationController pushViewController:uivc animated:YES];
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.activityIndicator setHidden:YES];
	
	StoreObserver* so = [StoreObserver getSingleton];
	so.delegate = self;
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	[numberFormatter setLocale:self.product.priceLocale];
	NSString *formattedString = [numberFormatter stringFromNumber:self.product.price];
	
	[self.buyButton setTitle:formattedString forState:UIControlStateNormal];
	[self.buyButton setTitle:formattedString forState:UIControlStateHighlighted];

	[self.recommendButton setTitle:NSLocalizedString(@"Recommend", nil) forState:UIControlStateNormal];
	[self.recommendButton setTitle:NSLocalizedString(@"Recommend", nil) forState:UIControlStateHighlighted];

	self.productTitleLabel.text = self.product.localizedTitle;
	self.productDescriptionLabel.text = self.product.localizedDescription;
	self.productImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"feature%@.png", self.product.productIdentifier]];
}

-(void)viewWillDisappear:(BOOL)animated {
	StoreObserver* so = [StoreObserver getSingleton];
	if(so.delegate == self) {
		so.delegate = nil;
	}
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [super dealloc];
}

#pragma mark StoreObserver delegate stuff
-(void)showError:(NSError*)error {
	[self.buyButton setTitle:[self.buyButton titleForState:UIControlStateHighlighted] forState:UIControlStateNormal];
	[self.buyButton setHidden:NO];
	
	[self.activityIndicator setHidden:YES];
	[self.activityIndicator stopAnimating];
	
	UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:error.localizedDescription
														 message:error.localizedFailureReason
														delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];
}

-(void)cancelled {
	// user canceled purchase -> reset buy button title
	[self.buyButton setTitle:[self.buyButton titleForState:UIControlStateHighlighted] forState:UIControlStateNormal];	
}


-(void)purchased:(NSString*)pid {
	if([pid isEqualToString:self.product.productIdentifier]) {
		[self.navigationController popViewControllerAnimated:YES];
	}
}
@end
