//
//  MailItemCell.m
//  ConversationsPrototype
//
//  Created by Gabor Cselle on 1/23/09.
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

#import "MailItemCell.h"

@implementation MailItemCell

@synthesize senderLabel;
@synthesize sideNoteLabel;
@synthesize dateLabel;
@synthesize dateDetailLabel;
@synthesize senderBubbleImage;
@synthesize showDetailsButton;
@synthesize showDetailsDelegate;
@synthesize convoIndex; // index of email in the conversation
@synthesize newBodyLabel;

- (void)dealloc {
	[senderLabel release];
	[sideNoteLabel release];
	[dateLabel release];
	[dateDetailLabel release];
	[senderBubbleImage release];
	[showDetailsButton release];
	//[showDetailsDelegate release]; - don't do this - it's an assign property!
	[convoIndex release];
	[newBodyLabel release];
    [super dealloc];
}

-(void)setupText {
	self.newBodyLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(6, 41, 312, 1941)];
	self.newBodyLabel.font = [UIFont systemFontOfSize:14];
	[self.contentView addSubview:self.newBodyLabel];	
}

-(void)setText:(NSString*)text {
	self.newBodyLabel.text = [TTStyledText textFromXHTML:text lineBreaks:YES URLs:YES];
	[self.newBodyLabel sizeToFit];
}

-(IBAction)showDetailsClicked {
	NSLog(@"showDetailsClicked");
	if ([showDetailsDelegate respondsToSelector:@selector(showDetailsClicked:)]) {
		[showDetailsDelegate performSelector:@selector(showDetailsClicked:) withObject:convoIndex];
	}
	
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}
@end
