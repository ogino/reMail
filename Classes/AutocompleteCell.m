//
//  AutocompleteCell.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/18/09.
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

#import "AutocompleteCell.h"
#import "StringUtil.h"

@implementation AutocompleteCell
@synthesize nameLabel;
@synthesize historyLabel;
@synthesize addressLabel;

- (void)dealloc {
	[nameLabel release];
	[historyLabel release];
	[addressLabel release];
	
    [super dealloc];
}

-(id) init {
	return self;
}

-(void)setupText {
	self.nameLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(36, 2, 282, 21)];
	self.nameLabel.font = [UIFont boldSystemFontOfSize:18];
	
	self.addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 22, 282, 18)];
	self.addressLabel.font = [UIFont systemFontOfSize:12];
	self.addressLabel.textColor = [UIColor darkGrayColor];
	
	// self.historyLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(36, 24, 282, 19)];
	// self.historyLabel.font = [UIFont systemFontOfSize:14];
	
	[self.contentView addSubview:self.addressLabel];
	[self.contentView addSubview:self.nameLabel];
}

-(void)setName:(NSString*)name withAddresses:(NSString*)addresses {
	self.nameLabel.text = [TTStyledText textFromXHTML:name lineBreaks:NO URLs:NO];
	self.nameLabel.frame = CGRectMake(36, 2, 282, 21);
	
	self.addressLabel.text = addresses;
	
	// self.historyLabel.text = [TTStyledText textFromXHTML:subject lineBreaks:NO URLs:NO];
	// self.historyLabel.frame = CGRectMake(36, 24, 282, 19);
}
@end
