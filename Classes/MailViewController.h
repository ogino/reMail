//
//  MailViewController.h
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

#import <Three20/Three20.h>
#import <MessageUI/MessageUI.h>
#import <UIKit/UIKit.h>
#import "Email.h"

@interface MailViewController : UIViewController<UIActionSheetDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate> {
	Email* email;
	int emailPk; 
	int dbNum; 
	BOOL loaded;
	
	id deleteDelegate; // call emailDeleted:pk on this delegate if an email was deleted
	
	BOOL isSenderSearch; // sender will be highlighted if this is YES
	BOOL copyMode;
	NSString* query; // if !isSenderSearch, terms in here will be highlighted in sender/attachment/body

	UIBarButtonItem* replyButton;
	IBOutlet UILabel* fromLabel;
	IBOutlet UILabel* toLabel;
	IBOutlet UILabel* ccLabel;
	IBOutlet UILabel* subjectLabel;
	IBOutlet UILabel* dateLabel;
	IBOutlet UIImageView* unreadIndicator;
	IBOutlet UIScrollView* scrollView;
	
	UIButton* copyModeButton;
	UILabel* copyModeLabel;
	
	NSArray* attachmentMetadata;
	
	TTStyledTextLabel* subjectTTLabel;
	TTStyledTextLabel* bodyTTLabel;
	UITextView* subjectUIView;
	UITextView* bodyUIView;
}

-(IBAction)replyButtonWasPressed;

-(void)composeViewWithSubject:(NSString*)subject body:(NSString*)body to:(NSArray*)to cc:(NSArray*)cc includeAttachments:(BOOL)includeAttachments;

-(NSString*)markupText:(NSString*)text query:(NSString*)query beginDelim:(NSString*)beginDelim endDelim:(NSString*)endDelim;
-(BOOL)matchText:(NSString*)text withQuery:(NSString*)queryLocal;
-(NSString*)massageDisplayString:(NSString*)y;


@property (nonatomic, retain) NSString *query;
@property (assign) BOOL isSenderSearch; // YES if we're doing senderQuery

@property (assign) BOOL copyMode;

@property (nonatomic, retain) id deleteDelegate;
@property (nonatomic, retain) Email *email;
@property (assign) int emailPk;
@property (assign) int dbNum;
@property (nonatomic, retain) NSArray* attachmentMetadata;
@property (nonatomic, retain) UIBarButtonItem* replyButton;
@property (nonatomic, retain) UILabel* fromLabel;
@property (nonatomic, retain) UILabel* toLabel;
@property (nonatomic, retain) UILabel* ccLabel;
@property (nonatomic, retain) UILabel* subjectLabel;
@property (nonatomic, retain) UILabel* dateLabel;
@property (nonatomic, retain) UIImageView* unreadIndicator;
@property (nonatomic, retain) UIScrollView* scrollView;

@property (nonatomic, retain) UIButton* copyModeButton;
@property (nonatomic, retain) UILabel* copyModeLabel;

@property (nonatomic, retain) TTStyledTextLabel* subjectTTLabel;
@property (nonatomic, retain) TTStyledTextLabel* bodyTTLabel;
@property (nonatomic, retain) UITextView* subjectUIView;
@property (nonatomic, retain) UITextView* bodyUIView;
@end
