//
//  UpsellViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 10/11/09.
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

#import "UpsellViewController.h"
#import "UsageViewController.h"

@implementation UpsellViewController
@synthesize featureFreeLabel;
@synthesize descriptionLabel;
@synthesize howToActivateLabel;
@synthesize recommendationsToMake;
@synthesize recommendButton;

- (void)dealloc {
	[super dealloc];
}

-(void)viewDidUnload {
	[super viewDidUnload];
	
	self.featureFreeLabel = nil;
	self.descriptionLabel = nil;
	self.howToActivateLabel = nil;
	self.featureFreeLabel = nil;
	self.recommendButton = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.recommendButton setTitle:NSLocalizedString(@"Recommend reMail", nil) forState:UIControlStateNormal];
	[self.recommendButton setTitle:NSLocalizedString(@"Recommend reMail", nil) forState:UIControlStateSelected];
	[self.recommendButton setTitle:NSLocalizedString(@"Recommend reMail", nil) forState:UIControlStateHighlighted];
	
	self.descriptionLabel.text = NSLocalizedString(@"This feature lets you connect multiple Gmail accounts to reMail", nil);
	self.howToActivateLabel.text = NSLocalizedString(@"How to Activate", nil);
	self.featureFreeLabel.text = [NSString stringWithFormat:NSLocalizedString(@"You can activate this functionality by recommending reMail to %i of your friends.", nil),
								  self.recommendationsToMake];
}

-(IBAction)recommendRemail {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"Usage" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator]; 
	UsageViewController *uivc = nil;
	NSObject* nibItem = NULL;
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

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}



@end
