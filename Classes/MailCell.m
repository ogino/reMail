//
//  ConvoCell.m
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

#import "MailCell.h"
#import "StringUtil.h"

@implementation MailCell

@synthesize subjectLabel;
@synthesize peopleLabel;
@synthesize dateLabel;
@synthesize attachmentIndicator;
@synthesize bodyLabel;

- (void)dealloc {
	[subjectLabel release];
	[peopleLabel release];
	[dateLabel release];
	[attachmentIndicator release];	
	[bodyLabel release];
	
    [super dealloc];
}

-(void)setupText {
	self.peopleLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(26, 2, 205, 19)];
	self.peopleLabel.font = [UIFont boldSystemFontOfSize:16];

	self.subjectLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(26, 24, 282, 17)];
	self.subjectLabel.font = [UIFont systemFontOfSize:14];
	
	self.bodyLabel = [[TTStyledTextLabel alloc] initWithFrame:CGRectMake(26, 43, 282, 48)];
	self.bodyLabel.font = [UIFont systemFontOfSize:13];
 
	[self.contentView addSubview:self.peopleLabel];
	[self.contentView addSubview:self.subjectLabel];
	[self.contentView addSubview:self.bodyLabel];
}

-(void)setTextWithPeople:(NSString*)people withSubject:(NSString*)subject withBody:(NSString*)body {
	CGFloat contentWidth = self.contentView.size.width;

	self.peopleLabel.text = [TTStyledText textFromXHTML:people lineBreaks:NO URLs:NO];
	self.peopleLabel.frame = CGRectMake(26, 2, contentWidth-180, 19);
	
	self.subjectLabel.text = [TTStyledText textFromXHTML:subject lineBreaks:NO URLs:NO];
	self.subjectLabel.frame = CGRectMake(26, 24, contentWidth-40, 17);
	self.subjectLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	self.bodyLabel.text = [TTStyledText textFromXHTML:body lineBreaks:NO URLs:NO];
	self.bodyLabel.frame = CGRectMake(26, 43, contentWidth-40, 48);
	self.bodyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


@end
