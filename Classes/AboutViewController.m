//
//  AboutViewController.m
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

#import "AboutViewController.h"
#import "AppSettings.h"

@implementation AboutViewController

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}

-(IBAction)moreClick {
	UIApplication *app = [UIApplication sharedApplication];
	NSString* urlString = [NSString stringWithFormat:NSLocalizedString(@"http://www.remail.com/a", nil), 
						   (int)[AppSettings reMailEdition]];
	NSURL* url = [NSURL URLWithString:urlString];
	if([app canOpenURL:url]) {			
		[app openURL:url];
	}	
}


@end
