//
//  MailViewController.m
//  ReMailIPhone
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

#import "MailViewController.h"
#import "Email.h"
#import "DateUtil.h"
#import "SyncManager.h"
#import "SearchRunner.h"
#import "NSString+SBJSON.h"
#import "AppSettings.h"
#import "AttachmentViewController.h"
#import "AttachmentDownloader.h"
#import "BuchheitTimer.h"
#import "EmailProcessor.h"

@interface MailViewController (Private)

-(UIImageView*)createLine: (CGFloat) y;

@end


@implementation MailViewController (Private)

-(UIImageView*)createLine: (CGFloat) y {
	CGFloat contentWidth = self.scrollView.size.width;
	UIImageView* line = [[[UIImageView alloc] init] autorelease];
	line.backgroundColor = [UIColor darkGrayColor];
	line.frame = CGRectMake(0,y,contentWidth,1);
	line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	return line;
}

@end


@interface PersonActionSheetHandler : NSObject<UIActionSheetDelegate> {
	NSString* name;
	NSString* address;
	
	MailViewController* mailVC;
}

@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) NSString* address;
@property (nonatomic, retain) MailViewController* mailVC;
@end

@implementation PersonActionSheetHandler
@synthesize name;
@synthesize address;
@synthesize mailVC;

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 0) { //Compose Email To
		[self.mailVC composeViewWithSubject:@"" body:@"" to:[NSArray arrayWithObject:self.address] cc:nil includeAttachments:NO];
	} else if (buttonIndex == 1) { // Copy Address
		UIPasteboard* pasteBoard = [UIPasteboard generalPasteboard];
		pasteBoard.string = self.address;
	} else if (buttonIndex == 2) { // Copy Name
		UIPasteboard* pasteBoard = [UIPasteboard generalPasteboard];
		pasteBoard.string = self.name;
	}
}
@end

@implementation MailViewController
@synthesize emailPk;
@synthesize dbNum;
@synthesize attachmentMetadata;
@synthesize email;

@synthesize copyMode;
@synthesize isSenderSearch;
@synthesize query;
@synthesize unreadIndicator;
@synthesize scrollView;
@synthesize fromLabel;
@synthesize toLabel;
@synthesize ccLabel;
@synthesize replyButton;
@synthesize subjectLabel;
@synthesize dateLabel;
@synthesize deleteDelegate;
@synthesize copyModeButton;
@synthesize copyModeLabel;

@synthesize subjectTTLabel;
@synthesize bodyTTLabel;
@synthesize subjectUIView;
@synthesize bodyUIView;


- (void)dealloc {
	[email release];
	
	[fromLabel release];
	[toLabel release];
	[ccLabel release];
	[scrollView release];
	[replyButton release];
	
	[copyModeButton release];
	[copyModeLabel release];
	
	[subjectLabel release];
	[dateLabel release];
	[unreadIndicator release];
	
	[attachmentMetadata release];
	
	[subjectTTLabel release];
	[bodyTTLabel release];
	[subjectUIView release];
	[bodyUIView release];
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.email = nil;
	
	self.fromLabel = nil;
	self.toLabel = nil;
	self.ccLabel = nil;
	self.scrollView = nil;
	self.replyButton = nil;
	
	self.copyModeButton = nil;
	self.copyModeLabel = nil;
	
	self.subjectLabel = nil;
	self.dateLabel = nil;
	self.unreadIndicator = nil;
	
	self.subjectTTLabel = nil;
	self.bodyTTLabel = nil;
	self.subjectUIView = nil;
	self.bodyUIView = nil;
	
	self.attachmentMetadata = nil;
}

-(void)personButtonClicked:(TTButton*)target {
	NSString *name = [target titleForState:UIControlStateNormal];
	NSString *address = [target titleForState:UIControlStateDisabled];
	
	NSString* title = address;
	if (![name isEqualToString:address]) {
		title = [NSString stringWithFormat:@"%@ <%@>", name, address];
	}
	
	PersonActionSheetHandler* pash = [[PersonActionSheetHandler alloc] init]; // this doesn't get released but the actionsheet does not retain it either!
	pash.name = name;
	pash.address = address;
	pash.mailVC = self;
	
	UIActionSheet* aS = [[[UIActionSheet alloc] initWithTitle:title delegate:pash cancelButtonTitle:NSLocalizedString(@"Cancel",nil) destructiveButtonTitle:nil otherButtonTitles:
							NSLocalizedString(@"Compose Email To",nil), NSLocalizedString(@"Copy Address",nil), NSLocalizedString(@"Copy Name",nil), nil] autorelease];
	[aS showInView:self.view];
}

- (IBAction)replyButtonWasPressed {
	UIActionSheet* aS = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel",nil) destructiveButtonTitle:NSLocalizedString(@"Delete", nil) otherButtonTitles:NSLocalizedString(@"Reply", nil), 
						 NSLocalizedString(@"Reply All", nil), 
						 NSLocalizedString(@"Forward", nil), 
						 nil];
	[aS showInView:self.view];
	[aS release];
}

-(NSMutableArray*)emailAddressesForJson:(NSString*)json {
	if(json == nil || [json length] <= 4) {
		return [NSMutableArray array];
	}
	
	NSArray* peopleList = [json JSONValue];
	NSMutableArray* res = [NSMutableArray arrayWithCapacity:[peopleList count]];
	for (NSDictionary* person in peopleList) {
		NSString* address = [person objectForKey:@"e"];
		if (address != nil && [address length] > 0) {
			[res addObject: address];
		}
	}
	return res;
}

-(NSString*)replyString {
	if(self.email.body == nil || [self.email.body length] == 0) {
		return @"";
	}
	
	NSDate* date = [DateUtil datetimeInLocal:self.email.datetime];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];

	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	NSString* dateString = [dateFormatter stringFromDate:date];

	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	NSString* timeString = [dateFormatter stringFromDate:date];
	
	NSString *headerString;
	if(self.email.senderName != nil && [self.email.senderName length] > 0) {
		headerString = [NSString stringWithFormat:@"On %@ at %@, %@ <%@> wrote:", dateString, timeString, self.email.senderName, self.email.senderAddress];
	} else {
		headerString = [NSString stringWithFormat:@"On %@ at %@, %@ wrote:", dateString, timeString, self.email.senderAddress];
	}
	
	NSString* quotedBody = self.email.body;
	
	[dateFormatter release];
	
	if([AppSettings promo]) {
		NSString* promoLine = NSLocalizedString(@"I found your email with reMail: http://www.remail.com/s", nil);
		return [NSString stringWithFormat:@"\n\n%@\n\n%@\n%@", promoLine, headerString, quotedBody];
	} else {
		return [NSString stringWithFormat:@"\n\n%@\n%@", headerString, quotedBody];
	}
	
}

-(NSArray*)replyAllRecipients {
	NSMutableArray* recipients = [self emailAddressesForJson:self.email.tos];
	[recipients addObjectsFromArray:[self emailAddressesForJson:self.email.ccs]];
	[recipients addObjectsFromArray:[self emailAddressesForJson:self.email.bccs]];
	
	return recipients;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == 0) { // Delete
		UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete Message?",nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Yes", @"No", nil] autorelease];
		[alertView show];	
		return;
	}
	
	BOOL keepSubject = NO;
	if(self.email.subject != nil && [self.email.subject length] >= 3) {
		NSString* subjectStart = [[self.email.subject substringToIndex:3] lowercaseString];

		if([subjectStart isEqualToString:@"r:"] || 
		   [subjectStart isEqualToString:@"re:"] || 
		   [subjectStart isEqualToString:@"aw:"]) {
			// If the subject line already starts with "Re:", don't edit it 
			// (that's equivalent to Gmail's behavior
			keepSubject = YES;
		}
	}
	
	if(buttonIndex == 1) { //Reply
		NSString* newSubject = self.email.subject;
		if(!keepSubject) {
			newSubject = [NSString stringWithFormat:@"Re: %@", self.email.subject];
		}
		
		
		[self composeViewWithSubject:newSubject
								body:[self replyString]
								  to:[NSArray arrayWithObject:self.email.senderAddress]
								  cc:nil
				  includeAttachments:NO];
	} else if (buttonIndex == 2) { // Reply All
		NSString* newSubject = self.email.subject;
		if(!keepSubject) {
			newSubject = [NSString stringWithFormat:@"RE: %@", self.email.subject];
		}
		
		[self composeViewWithSubject:newSubject
								body:[self replyString]
								  to:[NSArray arrayWithObject:self.email.senderAddress]
								  cc:[self replyAllRecipients]
				  includeAttachments:NO]; //TODO(gabor): Look into In-Reply-To header
	} else if (buttonIndex == 3) { // Forward
		[self composeViewWithSubject:[NSString stringWithFormat:@"Fwd: %@", self.email.subject] 
								body:[self replyString]
								  to:nil 
								  cc:nil
				  includeAttachments:YES];
	} else if (buttonIndex == 0) { // Delete
		UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete Message?",nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Yes", @"No", nil] autorelease];
		[alertView show];	
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
	return;
}

-(void)addAttachments:(MFMailComposeViewController*)mailCtrl {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for (int i = 0; i < [self.attachmentMetadata count]; i++) {
		NSDictionary* attachment = [self.attachmentMetadata objectAtIndex:i];
		NSString* filename = [attachment objectForKey:@"n"];
		NSString* contentType = [attachment objectForKey:@"t"];
		
		if(filename == nil || [filename length] == 0) {
			continue;
		}
		
		int accountNumDC = [EmailProcessor accountNumForCombinedFolderNum:self.email.folderNum];
		int folderNumDC = [EmailProcessor folderNumForCombinedFolderNum:self.email.folderNum];
		
		NSString* filenameOnDisk = [AttachmentDownloader fileNameForAccountNum:accountNumDC folderNum:folderNumDC uid:self.email.uid attachmentNum:i];
		NSString* attachmentDir = [AttachmentDownloader attachmentDirPath];
		NSString* attachmentPath = [attachmentDir stringByAppendingPathComponent:filenameOnDisk];		
		BOOL fileExists = [fileManager fileExistsAtPath:attachmentPath];
		
		if(!fileExists) {
			continue;
		}
		
		NSData* data = [[NSData alloc] initWithContentsOfFile:attachmentPath];
		
		[mailCtrl addAttachmentData:data mimeType:contentType fileName:filename];
		
		[data release];
		
		i++;
	}
}

-(void)composeViewWithSubject:(NSString*)subject body:(NSString*)body to:(NSArray*)to cc:(NSArray*)cc includeAttachments:(BOOL)includeAttachments {
	if ([MFMailComposeViewController canSendMail] != YES) {
		//TODO(gabor): Show warning - this device is not configured to send email.
		return;
	}
	
	MFMailComposeViewController *mailCtrl = [[MFMailComposeViewController alloc] init];
	
	if(to != nil && [to count] > 0) {
		[mailCtrl setToRecipients:to];
	}
	
	if(cc != nil && [cc count] > 0) {
		[mailCtrl setCcRecipients:cc];
	}
	
	[mailCtrl setSubject:subject];
	
	[mailCtrl setMessageBody:body isHTML:NO];
	
	mailCtrl.mailComposeDelegate = self;
	
	if(includeAttachments) {
		[self addAttachments:mailCtrl];
	}
	
	[self presentModalViewController:mailCtrl animated:YES];
	[mailCtrl release];
}

-(void)attachmentButtonClicked:(TTButton*)target {
	NSArray* attachmentList = [email.attachments JSONValue];
	NSString* contentType = [[attachmentList objectAtIndex:target.tag] objectForKey:@"t"];
	NSString* filename = [[attachmentList objectAtIndex:target.tag] objectForKey:@"n"];
	
	SyncManager* sm = [SyncManager getSingleton];
	
	AttachmentViewController* avc = [[AttachmentViewController alloc] initWithNibName:@"Attachment" bundle:nil];
	avc.folderNum = [EmailProcessor folderNumForCombinedFolderNum:self.email.folderNum];
	avc.accountNum = [EmailProcessor accountNumForCombinedFolderNum:self.email.folderNum];
	avc.attachmentNum = target.tag;
	avc.uid = self.email.uid;
	avc.contentType = [sm correctContentType:contentType filename:filename];
	[avc doLoad];
	[self.navigationController pushViewController:avc animated:YES];
	[avc release];
	
}

#pragma mark Handle deletions
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 0) {
		NSLog(@"Deleting message!");
		
		[Email deleteWithPk:self.emailPk];
		
		if(self.deleteDelegate != nil && [deleteDelegate respondsToSelector:@selector(emailDeleted:)]) {
			[deleteDelegate performSelectorOnMainThread:@selector(emailDeleted:) withObject:[NSNumber numberWithInt:self.emailPk] waitUntilDone:NO];
		}
		
		[self.navigationController popViewControllerAnimated:YES];
	}
}

#pragma mark Assemble UI
-(int)peopleList:(NSString*)title addToView:(UIView*)addToView peopleList:(NSArray*)peopleList top:(int)top highlightAll:(BOOL)highlightAll highlightQuery:(NSString*)highlightQuery {
	// produces a list of people name buttons
	UIView* toView = [[[UIView alloc] init] autorelease];
	toView.frame = CGRectMake(0,top,320,100);
	UILabel* labelTo = [[[UILabel alloc] init] autorelease];
	labelTo.font = [UIFont systemFontOfSize:14];
	labelTo.textColor = [UIColor darkGrayColor];	
	labelTo.text = title;
	CGSize size = [title sizeWithFont:labelTo.font];
	labelTo.frame = CGRectMake(0, 0, size.width+2, 30);
	[toView addSubview:labelTo];

	for (NSDictionary* person in peopleList) {
		NSString* name = [person objectForKey:@"n"];
		NSString* address = [person objectForKey:@"e"];
		NSString* display = nil;
		if(name != nil && [name length] > 0) {
			display = name;
		} else if (address != nil && [address length] > 0) {
			display = address;
		}
		
		BOOL highlightMatch = NO;
		if(highlightQuery != nil) {
			highlightMatch = (name != nil && [self matchText:name withQuery:query]) || (address != nil && [self matchText:address withQuery:query]);
		}
		
		TTButton* button;
		if(highlightAll || highlightMatch) {
			button = [TTButton buttonWithStyle:@"redRoundButton:" title:display];
		} else {
			button = [TTButton buttonWithStyle:@"blueRoundButton:" title:display];
		}
		button.font = [UIFont boldSystemFontOfSize:12];
		[button setTitle:address forState:UIControlStateDisabled]; // using disabled state to store the email address
		[button sizeToFit];
		[toView addSubview:button];
		
		[button addTarget:self action:@selector(personButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
	}

	[self.scrollView addSubview:toView];

	TTFlowLayout* flowLayout = [[[TTFlowLayout alloc] init] autorelease];
	flowLayout.padding = 5;
	flowLayout.spacing = 2;
	CGSize toSize = [flowLayout layoutSubviews:toView.subviews forView:toView];

	toView.frame = CGRectMake(0, top, toSize.width, toSize.height);	
	[addToView addSubview:toView];
	
	UIImageView* line = [self createLine:toView.bottom];
	[addToView addSubview:line];
	
	return line.bottom;
}

-(int)attachmentList:(NSString*)title addToView:(UIView*)addToView attachmentList:(NSArray*)attachmentList top:(int)top highlightQuery:(NSString*)highlightQuery {
	// produces a list of attachment name buttons
	UIView* toView = [[[UIView alloc] init] autorelease];
	toView.frame = CGRectMake(0,top,320,100);
	UILabel* labelTo = [[[UILabel alloc] init] autorelease];
	labelTo.font = [UIFont systemFontOfSize:14];
	labelTo.textColor = [UIColor darkGrayColor];	
	labelTo.text = title;
	CGSize size = [title sizeWithFont:labelTo.font];
	labelTo.frame = CGRectMake(0, 0, size.width+2, 30);
	[toView addSubview:labelTo];
	
	SyncManager* sm = [SyncManager getSingleton];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	int i = 0;
	for (NSDictionary* attachment in attachmentList) {
		NSString* filename = [attachment objectForKey:@"n"];
		NSString* contentType = [attachment objectForKey:@"t"];
		
		BOOL highlightMatch = NO;
		if(highlightQuery != nil) {
			highlightMatch = (filename != nil && [self matchText:filename withQuery:query]);
		}
		
		int accountNumDC = [EmailProcessor accountNumForCombinedFolderNum:self.email.folderNum];
		int folderNumDC = [EmailProcessor folderNumForCombinedFolderNum:self.email.folderNum];
		
		NSString* filenameOnDisk = [AttachmentDownloader fileNameForAccountNum:accountNumDC folderNum:folderNumDC uid:self.email.uid attachmentNum:i];
		NSString* attachmentDir = [AttachmentDownloader attachmentDirPath];
		NSString* attachmentPath = [attachmentDir stringByAppendingPathComponent:filenameOnDisk];		
		BOOL fileExists = [fileManager fileExistsAtPath:attachmentPath];
		
		if(filename != nil && [filename length] > 0) {
			
			if([sm isAttachmentViewSupported:contentType filename:filename]) {
				TTButton* button;
				if(highlightMatch && fileExists) {
					button = [TTButton buttonWithStyle:@"redRoundButton:" title:filename];
				} else if(highlightMatch) {
					button = [TTButton buttonWithStyle:@"lightRedRoundButton:" title:filename];
				} else if (fileExists) {
					button = [TTButton buttonWithStyle:@"greyRoundButton:" title:filename];
				} else {
					button = [TTButton buttonWithStyle:@"whiteRoundButton:" title:filename];
				}
				button.font = [UIFont boldSystemFontOfSize:12];
				button.tag = i;
				[button sizeToFit];
				[toView addSubview:button];
				
				[button addTarget:self action:@selector(attachmentButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
			} else {
				UILabel* label = [[UILabel alloc] init];
				label.text = filename;
				label.font = [UIFont boldSystemFontOfSize:12];
				if(highlightMatch) {
					label.textColor = [UIColor redColor];
				} else {
					label.textColor = [UIColor darkGrayColor];
				}
				
				CGSize size = [filename sizeWithFont:label.font];
				label.frame = CGRectMake(0, 0, size.width+2, 30);
				[toView addSubview:label];
				[label release];
			}
		}
		i++;
	}
	
	[self.scrollView addSubview:toView];
	
	TTFlowLayout* flowLayout = [[[TTFlowLayout alloc] init] autorelease];
	flowLayout.padding = 5;
	flowLayout.spacing = 2;
	CGSize toSize = [flowLayout layoutSubviews:toView.subviews forView:toView];
	
	toView.frame = CGRectMake(0, top, toSize.width, toSize.height);	
	[addToView addSubview:toView];
	
	UIImageView* line = [self createLine:toView.bottom];
	[addToView addSubview:line];
	
	return line.bottom;
}

-(void)toggleCopyMode:(UIButton*)button {
	NSLog(@"toggleCopyMode");
	
	UIImage* copyIcon = nil;
	if(self.copyMode) {
		self.copyMode = NO;
		copyIcon = [UIImage imageNamed:@"copyModeOff.png"];
		
		[self.subjectTTLabel setHidden:NO];
		[self.bodyTTLabel setHidden:NO];
		
		[self.subjectUIView setHidden:YES];
		[self.bodyUIView setHidden:YES];
		[self.copyModeLabel setHidden:YES];
	} else {
		copyIcon = [UIImage imageNamed:@"copyModeOn.png"];
		self.copyMode = YES;

		[self.subjectTTLabel setHidden:YES];
		[self.bodyTTLabel setHidden:YES];
		
		[self.subjectUIView setHidden:NO];
		[self.bodyUIView setHidden:NO];
		[self.copyModeLabel setHidden:NO];
	}

	[button setImage:copyIcon forState:UIControlStateNormal];
	[button setImage:copyIcon forState:UIControlStateHighlighted];
	[button setImage:copyIcon forState:UIControlStateSelected];
	
}


-(int)subjectBlock:(NSString*)subject markedUp:(NSString*)subjectMarkedUp date:(NSDate*)date top:(int)top addToView:(UIView*)addToView showTTView:(BOOL)showTTView {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	top += 1;
	
	if(showTTView) {
		self.subjectTTLabel = [[[TTStyledTextLabel alloc] initWithFrame:CGRectMake(5, top, 320-65-5, 21)] autorelease];
		self.subjectTTLabel.font = [UIFont boldSystemFontOfSize:17];
		self.subjectTTLabel.textColor = [UIColor blackColor];
		self.subjectTTLabel.text = [TTStyledText textFromXHTML:subjectMarkedUp lineBreaks:NO URLs:NO];
		[addToView addSubview:self.subjectTTLabel];
	}
	
	CGRect subjectUIRect = CGRectMake(-3, top, 320-10, 21);
	if(showTTView) {
		subjectUIRect = CGRectMake(-3, top, 320-62-10, 21);
	}
			
	self.subjectUIView = [[[UITextView alloc] initWithFrame:subjectUIRect] autorelease];
	self.subjectUIView.font = [UIFont boldSystemFontOfSize:17];
	self.subjectUIView.textColor = [UIColor blackColor];
	self.subjectUIView.text = subject;
	self.subjectUIView.scrollEnabled = YES;
	self.subjectUIView.editable = NO;
	self.subjectUIView.dataDetectorTypes = UIDataDetectorTypeAll;
	self.subjectUIView.contentInset = UIEdgeInsetsMake(0,0,0,0);
	self.subjectUIView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.subjectUIView setContentOffset:CGPointMake(0,8) animated:NO];
	if(showTTView) { //only hide when we're showing the TT view as well
		[self.subjectUIView setHidden:YES];
	}
	
	[addToView addSubview:self.subjectUIView];

	UILabel* labelDate = [[[UILabel alloc] initWithFrame:CGRectMake(5, top+22, 250, 17)] autorelease];
	labelDate.font = [UIFont systemFontOfSize:12];
	labelDate.textColor = [UIColor darkGrayColor];
	labelDate.text = [dateFormatter stringFromDate:date];
	[addToView addSubview:labelDate];

	UIImageView* line = [self createLine: labelDate.bottom+1] ;
		
	[addToView addSubview:line];

	if(showTTView) {
		self.copyModeLabel = [[[UILabel alloc] initWithFrame:CGRectMake(self.subjectTTLabel.right-1, top+22, 61, 17)] autorelease];
		self.copyModeLabel.font = [UIFont systemFontOfSize:12];
		self.copyModeLabel.textColor = [UIColor blueColor];
		self.copyModeLabel.text = NSLocalizedString(@"Copy Mode", nil);
		self.copyModeLabel.adjustsFontSizeToFitWidth = YES;
		self.copyModeLabel.textAlignment = UITextAlignmentCenter;
		[addToView addSubview:self.copyModeLabel];
		[self.copyModeLabel setHidden:YES];
		
		UIImage* copyIcon = [UIImage imageNamed:@"copyModeOff.png"];
		self.copyModeButton = [[[UIButton alloc] initWithFrame:CGRectMake(self.subjectTTLabel.right-1,top,62,21)] autorelease];
		[self.copyModeButton setImage:copyIcon forState:UIControlStateNormal];
		[self.copyModeButton setImage:copyIcon forState:UIControlStateHighlighted];
		[self.copyModeButton setImage:copyIcon forState:UIControlStateSelected];
		[self.copyModeButton addTarget:self action:@selector(toggleCopyMode:) forControlEvents:UIControlEventTouchUpInside];
		[addToView addSubview:self.copyModeButton];
	}
	
	[dateFormatter release];
	
	return line.bottom;
}


-(int)bodyBlock:(NSString*)body markedUp:(NSString*)bodyMarkedUp top:(int)top addToView:(UIView*)addToView showTTView:(BOOL)showTTView {
	// not showing the TT view is an optimization for when we don't have any markup to show
	if(showTTView) {
		self.bodyTTLabel = [[[TTStyledTextLabel alloc] initWithFrame:CGRectMake(5, top+8, 310, 100)] autorelease];
		self.bodyTTLabel.font = [UIFont systemFontOfSize:14];
		self.bodyTTLabel.textColor = [UIColor blackColor];
	}
	
	CGFloat contentWidth = self.scrollView.size.width;
	
	self.bodyUIView = [[[UITextView alloc] initWithFrame:CGRectMake(-3, top, 382, 100)] autorelease];
	self.bodyUIView.font = [UIFont systemFontOfSize:14];
	self.bodyUIView.textColor = [UIColor blackColor]; 
	self.bodyUIView.scrollEnabled = NO;
	self.bodyUIView.editable = NO;
	self.bodyUIView.dataDetectorTypes = UIDataDetectorTypeAll;
	self.bodyUIView.text = body;
	self.bodyUIView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[addToView addSubview:self.bodyUIView];
	
	if(showTTView) {
		self.bodyTTLabel.text = [TTStyledText textFromXHTML:bodyMarkedUp lineBreaks:YES URLs:YES];
		[self.bodyTTLabel sizeToFit];
	}
	
	int bottom = 0;
	if(showTTView) {
		self.bodyUIView.frame = CGRectMake(-3, top, contentWidth, self.bodyTTLabel.bottom-top);
		[self.bodyUIView setHidden:YES];
		bottom = self.bodyTTLabel.bottom;
		[addToView addSubview:self.bodyTTLabel];
	} else {
		CGSize size = [body sizeWithFont:self.bodyUIView.font constrainedToSize:CGSizeMake(300.0f,100000000.0f) lineBreakMode: UILineBreakModeWordWrap];
		self.bodyUIView.frame = CGRectMake(-3, top, contentWidth, size.height+24);
		bottom = self.bodyUIView.bottom;
	}
	
	return bottom;
}

-(void)loadEmail {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	self.email = [[SearchRunner getSingleton] loadEmail:self.emailPk dbNum:self.dbNum];
	
	[self performSelectorOnMainThread:@selector(loadedEmail) withObject:nil waitUntilDone:NO];
	[pool release];
}
	
-(void)loadedEmail {
	// now that the email was loaded (in a different thread), we can display its contents

	// remove loading indicator
	for(UIView* subview in self.scrollView.subviews) {
		if([subview class] == [UILabel class] || [subview class] == [UIActivityIndicatorView class]) {
			[subview removeFromSuperview];
		}
	}
	
	if(self.email == nil) {
		int bottom = [self bodyBlock:@"Error: Email not found" markedUp:@"Error: Email not found" top:0 addToView:self.scrollView showTTView:NO];
		self.scrollView.contentSize = CGSizeMake(320, bottom+2);
		return;
	}
	
	NSString *highlightQuery = nil;
	if(!self.isSenderSearch) { // only highlight matching senders when we're not in senderSearch
		highlightQuery = self.query;
	}
	BOOL markupBody = YES; // avoid showing the huge TTView for the body if possible
	if(self.isSenderSearch || [highlightQuery length] == 0) {
		markupBody = NO;
	}
	
	NSDictionary* senderDict = [NSDictionary dictionaryWithObjectsAndKeys:email.senderAddress, @"e", email.senderName, @"n", nil];
	int bottom = [self peopleList:NSLocalizedString(@"From:",nil) addToView:self.scrollView peopleList:[NSArray arrayWithObject:senderDict] top:0 highlightAll:self.isSenderSearch highlightQuery:highlightQuery];
	
	if(email.tos != nil && [email.tos length] > 4) {
		NSArray* peopleList = [email.tos JSONValue];
		bottom = [self peopleList:NSLocalizedString(@"To:",nil) addToView:self.scrollView peopleList:peopleList top:bottom highlightAll:NO highlightQuery:highlightQuery];
	}
	
	if(email.ccs != nil && [email.ccs length] > 4) {
		NSArray* peopleList = [email.ccs JSONValue];
		bottom = [self peopleList:NSLocalizedString(@"Cc:",nil) addToView:self.scrollView peopleList:peopleList top:bottom highlightAll:NO highlightQuery:highlightQuery];
	}
	
	if(email.bccs != nil && [email.bccs length] > 4) {
		NSArray* peopleList = [email.bccs JSONValue];
		bottom = [self peopleList:NSLocalizedString(@"Bcc:",nil) addToView:self.scrollView peopleList:peopleList top:bottom highlightAll:NO highlightQuery:highlightQuery];
	}
	
	NSString* subject = [self massageDisplayString:email.subject];
	if(subject == nil || [subject length] == 0) {
		subject = NSLocalizedString(@"[empty]", nil);
		email.subject = subject;
	}
	NSString* subjectMarkup = [self markupText:subject query:highlightQuery beginDelim:@"<span class=\"yellowBox\">" endDelim:@"</span>"];
	bottom = [self subjectBlock:email.subject markedUp:subjectMarkup date:email.datetime top:bottom addToView:self.scrollView showTTView:markupBody];
	
	self.attachmentMetadata = nil;
	if(email.attachments != nil && [email.attachments length] > 4) {
		NSArray* attachmentList = [email.attachments JSONValue];
		self.attachmentMetadata = attachmentList;
		bottom = [self attachmentList:NSLocalizedString(@"Attachments:",nil) addToView:self.scrollView attachmentList:attachmentList top:bottom highlightQuery:highlightQuery];
	}
	
	NSString* body = [self massageDisplayString:email.body];
	
	if(body == nil || [body length] == 0 || [body isEqualToString:@"\r\n"]) {
		body = NSLocalizedString(@"[empty]", nil);
	}
	NSString* bodyMarkup = [self markupText:body query:highlightQuery beginDelim:@"<span class=\"yellowBox\">" endDelim:@"</span>"];
	bottom = [self bodyBlock:email.body markedUp:bodyMarkup top:bottom addToView:self.scrollView showTTView:markupBody];
	
	////////////////////	
	self.scrollView.contentSize = CGSizeMake(320, bottom+2);
}

-(void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:YES];
	if(!loaded) {
		NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(loadEmail) object:nil];
		[driverThread start];
		[driverThread release];	
		loaded = YES;
	}
	
	// hide toolbar so we have more space to display mail
	[self.navigationController setToolbarHidden:YES animated:animated];
}



- (void)loadView {
	self.view = [[[[UIView class] alloc] initWithFrame:CGRectMake(0,0,320,480)] autorelease];
	self.view.backgroundColor = [UIColor blackColor];
		
	// This is our real view, dude
	self.scrollView = [[[[UIScrollView class] alloc] initWithFrame:CGRectMake(0,0,320,480)] autorelease];
	self.scrollView.backgroundColor = [UIColor whiteColor];
	self.scrollView.canCancelContentTouches = NO;
	self.scrollView.showsVerticalScrollIndicator = YES;
	self.scrollView.showsHorizontalScrollIndicator = NO;
	self.scrollView.alwaysBounceVertical = YES;
	[self.view addSubview:self.scrollView];
	
	UIActivityIndicatorView* loadingIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(100, 160, 20, 20)];
	loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
	loadingIndicator.hidesWhenStopped = NO;
	[self.scrollView addSubview:loadingIndicator];
	[loadingIndicator startAnimating];
	[loadingIndicator release];
	
	UILabel* loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(127, 160, 90, 20)];
	loadingLabel.font = [UIFont systemFontOfSize:14];
	loadingLabel.textColor = [UIColor darkGrayColor];	
	loadingLabel.text = NSLocalizedString(@"Loading email", nil);
	[self.scrollView addSubview:loadingLabel];
	[loadingLabel release];
	
	self.scrollView.contentSize = CGSizeMake(320, 180);
	self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	self.title = @"eMail";
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(replyButtonWasPressed)] autorelease];
}

#pragma mark String massinging and match markup
-(NSString*)massageDisplayString:(NSString*)y {
	y = [y stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	y = [y stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	y = [y stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	return y;
}

-(NSString*)markupText:(NSString*)text query:(NSString*)queryLocal beginDelim:(NSString*)beginDelim endDelim:(NSString*)endDelim {
	if(queryLocal == nil) {
		return text;
	}
	if(text == nil) {
		return @"";
	}
	
	NSMutableString* markedUp = [[NSMutableString alloc] initWithString:text];
	
	NSCharacterSet* beginSet = [NSCharacterSet characterSetWithCharactersInString:@" {}[]()|\"'<\n\r\t^-!;"]; // tries to avoid URL-looking separators
	NSCharacterSet* endSet =   [NSCharacterSet characterSetWithCharactersInString:@" {}[]()|\"'<\n\r\t^-!;.,:&+#_=~/\\@"]; // it's fine if we end with one of there separators though

	NSArray* queryParts = [queryLocal componentsSeparatedByCharactersInSet:endSet];
	
	for(NSString* queryPart in queryParts) {
		
		BOOL star = NO;
		if([queryPart hasSuffix:@"*"]) {
			star = YES;
			queryPart = [queryPart substringToIndex:[queryPart length] - 1];
		}
		
		NSRange searchRange = NSMakeRange(0, [markedUp length]);
		while(YES) {
			NSRange range = [markedUp rangeOfString:queryPart options:NSCaseInsensitiveSearch range:searchRange];

			if(range.location == NSNotFound) {
				break;
			}
			
			BOOL beginOk = NO;
			if(range.location == 0) {
				beginOk = YES;
			} else {
				unichar before = [markedUp characterAtIndex:range.location - 1];
				beginOk = [beginSet characterIsMember:before];
			}
			
			BOOL endOk = NO;
			if([markedUp length] == range.location + range.length) {
				endOk = YES;
			} else if (star) {
				NSRange	foundSpace = [markedUp rangeOfCharacterFromSet:endSet options:0 range:NSMakeRange(range.location, [markedUp length]-range.location)];
				if(foundSpace.location == NSNotFound) {
					foundSpace.location = [markedUp length];
				}
				range = NSMakeRange(range.location, foundSpace.location - range.location);
				endOk = YES;
			} else {
				unichar after = [markedUp characterAtIndex:(range.location + range.length)];
				endOk = [endSet characterIsMember:after];
			}
			
			if(beginOk && endOk) {
				NSString *rangeContents = [markedUp substringWithRange:range];
				[markedUp deleteCharactersInRange:range];
				[markedUp insertString:[NSString stringWithFormat:@"$$$$beginDelim$$$$%@$$$$endDelim$$$$", rangeContents] atIndex:range.location];
			}
			
			searchRange = NSMakeRange(range.location + range.length, [markedUp length] - (range.location + range.length));
		}
	}
	
	
	[markedUp replaceOccurrencesOfString:@"$$$$endDelim$$$$" withString:endDelim options:NSLiteralSearch range:NSMakeRange(0,[markedUp length])];
	[markedUp replaceOccurrencesOfString:@"$$$$beginDelim$$$$" withString:beginDelim options:NSLiteralSearch range:NSMakeRange(0,[markedUp length])];
	NSString* res = [NSString stringWithString:markedUp];
	[markedUp release];
	
	return res;	
}

-(BOOL)matchText:(NSString*)text withQuery:(NSString*)queryLocal {
	NSArray* queryParts = [StringUtil split:queryLocal];
	
	NSCharacterSet* divisor = [NSCharacterSet characterSetWithCharactersInString:@" {}[]()|\"'<\n\r\t^-!;.,:&+#_=~/\\@"];
	
	NSScanner *scanner = [[NSScanner alloc] initWithString:text];
	scanner.caseSensitive = NO;
	NSString* dest = nil;
	NSString* prev = nil;
	for(NSString* queryPart in queryParts) {
		BOOL star = NO;
		if([queryPart hasSuffix:@"*"]) {
			star = YES;
			queryPart = [queryPart substringToIndex:[queryPart length] - 1];
		}
		
		scanner.scanLocation = 0;

		BOOL beginOk = NO;
		BOOL endOk = NO;
		
		[scanner scanUpToString:queryPart intoString:&prev];
		if([scanner scanString:queryPart intoString:&dest]) {
			if(prev == nil || [prev length] == 0) {
				beginOk = YES;
			} else {
				unichar c= [prev characterAtIndex:[prev length]-1]; // last character in prev string
				beginOk = [divisor characterIsMember:c];
			}
			
			if (beginOk) {
				if(star) {
					// anything goes if we have a star
					endOk = YES;
				} else {
					// no star -> make sure the word ends
					if([scanner isAtEnd]) {
						endOk = YES;
					} else {
						unichar c = [text characterAtIndex:scanner.scanLocation];
						endOk = [divisor characterIsMember:c];
					}
				}
			}
			
			if(beginOk && endOk) {
				[scanner release];
				return YES;
			}
		}
	}	
	[scanner release];
	
	return NO;
}

-(void)viewDidLoad {
	loaded = NO;
	self.copyMode = NO;	
}

#pragma mark View Management
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"MailViewController received memory warning");
}


#pragma mark Rotation
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
