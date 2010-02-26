//
//  HomeViewController.m
//  Displays home screen to user, manages toolbar UI and responds to sync status updates
//
//  Created by Gabor Cselle on 1/22/09.
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

#import "HomeViewController.h"
#import "SyncManager.h"
#import "MailboxViewController.h"
#import "SearchEntryViewController.h"
#import "ProgressView.h"
#import "StatusViewController.h"
#import "AppSettings.h"
#import "GlobalDBFunctions.h"
#import "SearchRunner.h"
#import "PastQuery.h"
#import "ErrorViewController.h"
#import "SettingsListViewController.h"
#import "FolderListViewController.h"
#import "UsageViewController.h"

@interface RemailStyleSheet : TTDefaultStyleSheet
@end

@implementation RemailStyleSheet

- (TTStyle*)blueRoundButton:(UIControlState)state {
	return
    [self toolbarButtonForState:state
						  shape:[TTRoundedRectangleShape shapeWithRadius:TT_ROUNDED]
					  tintColor:RGBCOLOR(43, 127, 189)
						   font:nil];
}

- (TTStyle*)lightRedRoundButton:(UIControlState)state {
	return
    [self toolbarButtonForState:state
						  shape:[TTRoundedRectangleShape shapeWithRadius:TT_ROUNDED]
					  tintColor:RGBCOLOR(255, 164, 164)
						   font:nil];
}

- (TTStyle*)redRoundButton:(UIControlState)state {
	return
    [self toolbarButtonForState:state
						  shape:[TTRoundedRectangleShape shapeWithRadius:TT_ROUNDED]
					  tintColor:RGBCOLOR(235, 124, 124)
						   font:nil];
}

- (TTStyle*)whiteRoundButton:(UIControlState)state {
	return
    [self toolbarButtonForState:state
						  shape:[TTRoundedRectangleShape shapeWithRadius:TT_ROUNDED]
					  tintColor:RGBCOLOR(200, 200, 200)
						   font:nil];
}

- (TTStyle*)greyRoundButton:(UIControlState)state {
	return
    [self toolbarButtonForState:state
						  shape:[TTRoundedRectangleShape shapeWithRadius:TT_ROUNDED]
					  tintColor:RGBCOLOR(110, 110, 110)
						   font:nil];
}

- (TTStyle*)plain {
	return [TTContentStyle styleWithNext:nil];
}

- (TTStyle*)redBox {
	return 
    [TTShapeStyle styleWithShape:[TTRectangleShape shape] next:
	 [TTInsetStyle styleWithInset:UIEdgeInsetsMake(-1, -1, -1, -1) next:
	  [TTSolidFillStyle styleWithColor:[UIColor colorWithRed:0.95 green:0.5 blue:0.5 alpha:1.0] next:nil]]];
}

- (TTStyle*)yellowBox {
	return 
    [TTShapeStyle styleWithShape:[TTRectangleShape shape] next:
	 [TTSolidFillStyle styleWithColor:[UIColor colorWithRed:0.933 green:0.949 blue:0.501 alpha:1.0] next:nil]];
}

- (TTStyle*)greenBox {
	return 
    [TTShapeStyle styleWithShape:[TTRectangleShape shape] next:
	 [TTSolidFillStyle styleWithColor:[UIColor colorWithRed:0.533 green:0.949 blue:0.501 alpha:1.0] next:nil]];
}
@end

@implementation HomeViewController

@synthesize clientMessageButton, clientMessage;
@synthesize errorDetail;

BOOL loaded = NO;
SearchEntryViewController* searchEntryVC = nil;
ProgressView* progressView = nil;
int maxSeqInQueue = 0;
NSString* clientMessageLink = nil;
NSDateFormatter* dateFormatter = nil;

// Artwork disclosure:
// Search icon is from:    http://www.icons-land.com/
// Settings icon is from:  http://www.iconspedia.com/icon/settings-1625.html

- (void)dealloc {
	[clientMessage release];
	[clientMessageButton release];
	
	if(progressView != nil) {
		[progressView release];
		progressView = nil;
	}
	if(dateFormatter != nil) {
		[dateFormatter release];
		dateFormatter = nil;
	}
	
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.clientMessage = nil;
	self.clientMessageButton = nil;	
}

-(IBAction)accountListClick:(id)sender {
	SettingsListViewController *alvc = [[SettingsListViewController alloc] initWithNibName:@"SettingsList" bundle:nil];
	alvc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	[self.navigationController pushViewController:alvc animated:YES];
	[alvc release];
}

-(IBAction)searchClick:(id)sender {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"SearchEntryView" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator]; 
	SearchEntryViewController *uivc = nil;
	NSObject* nibItem = nil;
    while ( (nibItem = [nibEnumerator nextObject]) != NULL) { 
        if ( [nibItem isKindOfClass: [SearchEntryViewController class]]) { 
			uivc = (SearchEntryViewController*) nibItem;
			break;
		}
	}

	if(uivc == nil) {
		return;
	}
	
	uivc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	
	[uivc doLoad];
	[self.navigationController pushViewController:uivc animated:(sender != nil)];
}

-(IBAction)usageClick:(id)sender {
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
	
	[self.navigationController pushViewController:uivc animated:(sender != nil)];	
}

-(IBAction)foldersClick:(id)sender {
	FolderListViewController *vc = [[FolderListViewController alloc] initWithNibName:@"FolderList" bundle:nil];
	vc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	[self.navigationController pushViewController:vc animated:(sender != nil)];
	[vc release];
}

-(void)openErrorDetails {
	if([self.errorDetail hasPrefix:@"http"]) {
		// Error detail is a link

		UIViewController* vc = [[UIViewController alloc] init];
		vc.title = NSLocalizedString(@"Error Detail",nil);

		UIWebView* wv = [[UIWebView alloc] init];
		
		NSURL *url = [[NSURL alloc] initWithString:self.errorDetail]; 
		NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
		[wv loadRequest:request];
		[request release];
		[url release];	
		
		vc.view = wv;
		[wv	release];

		vc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
		[self.navigationController pushViewController:vc animated:YES];
		[vc release];		
	} else {
		SyncManager* sm = [SyncManager getSingleton];
		BOOL showSkip = (sm.lastErrorFolderNum != -1 && sm.lastErrorStartSeq != -1 && sm.lastErrorAccountNum != -1);

		ErrorViewController *evc = [[ErrorViewController alloc] initWithNibName:@"ErrorView" bundle:nil];
		evc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
		evc.title = NSLocalizedString(@"Error Details", nil);
		
		// try to open log file
		evc.detailText = self.errorDetail;
		
		NSString* mailimapErrorLogPath = [StringUtil filePathInDocumentsDirectoryForFileName:@"mailimap_error.log"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:mailimapErrorLogPath]) {
			NSError* error = nil;
			NSString *content = [[NSString alloc] initWithContentsOfFile:mailimapErrorLogPath encoding:NSASCIIStringEncoding error:&error];
			
			if(content) {
				if([content length] > 1000000) {
					NSString* new = [content substringFromIndex:[content length] - 1000000];
					evc.detailText = [NSString stringWithFormat:@"%@\n\nLOGS:\n%@", self.errorDetail, new];					
				} else {
					evc.detailText = [NSString stringWithFormat:@"%@\n\nLOGS:\n%@", self.errorDetail, content];
				}				
				[content release];
			} else if (error != nil) {
				evc.detailText = [NSString stringWithFormat:@"%@\n\nLOGS:\n%@", self.errorDetail, error];
			}
		} else {
			if(evc.detailText != nil) {
				evc.detailText = self.errorDetail;
			} else {
				evc.detailText = self.clientMessage;
			}
		}
		
		evc.showSkip = showSkip;
		
		[self.navigationController pushViewController:evc animated:YES];
		[evc release];
	}	
}


-(IBAction)clientMessageClick {
	[self openErrorDetails];
	
	return;
}

-(IBAction)toolbarStatusClicked:(id)sender {
	StatusViewController* vc = [[StatusViewController alloc] initWithNibName:@"Status" bundle:nil];
	vc.toolbarItems = [self.toolbarItems subarrayWithRange:NSMakeRange(0, 2)];
	[self.navigationController pushViewController:vc animated:(sender != nil)];
	[vc release];
}


-(void)toolbarRefreshClicked:(id)sender {
	NSLog(@"HomeViewController - toolbar refresh clicked");
	
	if(loaded) {
		SyncManager* sm = [SyncManager getSingleton];
		if(sm.syncInProgress) {
			return;
		}
		
		[[SyncManager getSingleton] requestSyncIfNoneInProgressAndConnected];
	}
	
	// need to indicate to the user that something is happening ...
	if(progressView.progressLabel.hidden) {
		[progressView.updatedLabelTop setHidden:YES];
		[progressView.clientMessageLabelBottom setHidden:YES];
		[progressView.updatedLabel setHidden:NO];
		progressView.updatedLabel.text = @"Updating ... ";
	}
}

-(void)didChangeProgressStringTo:(NSString*)progressString {
	// if called with progressString = nil, just say "updated at time x"
	if(progressString == nil) {
		NSDate* date = [NSDate date];
		progressString = [NSString stringWithFormat:@"Updated %@", [dateFormatter stringFromDate:date]];
	}
	
	[progressView.progressLabel setHidden:YES];
	[progressView.activity setHidden:YES];
	[progressView.progressView setHidden:YES];
	
	if(self.clientMessage != nil) {
		// show string + clientMessage
		[progressView.updatedLabelTop setHidden:NO];
		[progressView.clientMessageLabelBottom setHidden:NO];
		[progressView.updatedLabel setHidden:YES];
		progressView.updatedLabelTop.text = progressString;
		progressView.clientMessageLabelBottom.text = self.clientMessage;
	} else {
		// show only the string
		[progressView.updatedLabelTop setHidden:YES];
		[progressView.clientMessageLabelBottom setHidden:YES];
		[progressView.updatedLabel setHidden:NO];
		progressView.updatedLabel.text = progressString;
	}
}

-(void)didChangeProgressTo:(NSDictionary*)dict {
	float progress = [[dict objectForKey:@"progress"] floatValue];

	progressView.progressView.progress = progress;
	progressView.progressLabel.text = [dict objectForKey:@"message"];
	
	[progressView.updatedLabelTop setHidden:YES];
	[progressView.clientMessageLabelBottom setHidden:YES];
	[progressView.updatedLabel setHidden:YES];
	
	[progressView.progressLabel setHidden:NO];
	[progressView.progressView setHidden:NO];
}

- (void)loadIt {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	loaded = YES;
	
	[GlobalDBFunctions tableCheck];
	SyncManager* ssm = [SyncManager getSingleton];
	[ssm registerForProgressWithDelegate:self];
	[ssm registerForClientMessageWithDelegate:self];
	[self didChangeClientMessageTo:nil];

	if([AppSettings firstSync]) {
		[ssm requestSyncIfNoneInProgressAndConnected];
		[AppSettings setFirstSync:NO];
	}
	
	[pool release];
}

-(void)didChangeClientMessageTo:(id)object {
	if (object == nil) {
		[clientMessageButton setHidden:YES];
		clientMessageLink=nil;
		clientMessage = nil;
	} else {
		[clientMessageButton setHidden:NO];
		clientMessageButton.alpha = 1.0f;
		NSDictionary* dict = (NSDictionary*)object;

		self.clientMessage = [dict objectForKey:@"message"];
		
		if(self.clientMessage == nil) {
			[clientMessageButton setHidden:YES];
			[progressView.clientMessageLabelBottom setHidden:YES];
			return;
		}
		
		self.errorDetail = [dict objectForKey:@"errorDetail"];
		
		[clientMessageButton setTitle:self.clientMessage forState:UIControlStateNormal];
		[clientMessageButton setTitle:self.clientMessage forState:UIControlStateHighlighted];
		[clientMessageButton setTitle:self.clientMessage forState:UIControlStateSelected];
		clientMessageLink=[dict objectForKey:@"link"];
		
		NSString* colorS = [dict objectForKey:@"color"];
		UIColor* color;
		if([colorS isEqualToString:@"green"]) {
			color = [UIColor greenColor];
		} else if ([colorS isEqualToString:@"yellow"]) {
			color = [UIColor yellowColor];
		} else if ([colorS isEqualToString:@"red"]) {
			color = [UIColor redColor];
		} else if ([colorS isEqualToString:@"blue"]) {
			color = [UIColor blueColor];
		} else if ([colorS isEqualToString:@"white"]) {
			color = [UIColor whiteColor];
		} else {
			color = [UIColor grayColor];
		}
		
		[clientMessageButton setTitleColor:color forState:UIControlStateNormal];
		[clientMessageButton setTitleColor:color forState:UIControlStateHighlighted];
		[clientMessageButton setTitleColor:color forState:UIControlStateSelected];
		
		
		if(self.errorDetail != nil) {
			[clientMessageButton setImage:[UIImage imageNamed:@"errorDetailLink.png"] forState:UIControlStateNormal]; 
			[clientMessageButton setImage:[UIImage imageNamed:@"errorDetailLink.png"] forState:UIControlStateHighlighted]; 
			[clientMessageButton setImage:[UIImage imageNamed:@"errorDetailLink.png"] forState:UIControlStateSelected]; 
			
			NSString* m = NSLocalizedString(@"View / Resolve Error", nil);
			[clientMessageButton setTitle:m forState:UIControlStateNormal];
			[clientMessageButton setTitle:m forState:UIControlStateHighlighted];
			[clientMessageButton setTitle:m forState:UIControlStateSelected];
		} else {
			[clientMessageButton setImage:nil forState:UIControlStateNormal]; 
			[clientMessageButton setImage:nil forState:UIControlStateHighlighted]; 
			[clientMessageButton setImage:nil forState:UIControlStateSelected]; 
		}
	}
}

-(void)viewDidAppear:(BOOL)animated {
	if(!loaded) {
		NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(loadIt) object:nil];
		[driverThread start];
		[driverThread release];
		loaded = YES;
	}
	
	[AppSettings setLastpos:@"home"];
	
	return;
}

-(void)viewWillAppear:(BOOL)animated {
	if(loaded && animated) {
		// Cancel SearchRunner for the case where we just came back from "All Mail" and are about to quickly dive back
		// animated will be true in this case because we're diving up
		SearchRunner *sem = [SearchRunner getSingleton];
		[sem cancel];
	}
	
	[self.navigationController setToolbarHidden:NO animated:animated];
}

-(ProgressView*)createNewProgressViewFromNib {
	NSArray* nibContents = [[NSBundle mainBundle] loadNibNamed:@"ProgressView" owner:self options:NULL];
	NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
	ProgressView* view = nil;
	NSObject* nibItem = nil;
	while ((nibItem = [nibEnumerator nextObject]) != nil) {
		if([nibItem isKindOfClass: [ProgressView class]]) {
			view = (ProgressView*)nibItem;
			break;
		}
	}
	return view;
}

- (BOOL)shouldLoadExternalURL:(NSURL*)url {
	return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	[TTStyleSheet setGlobalStyleSheet:[[[RemailStyleSheet alloc] init] autorelease]];
	
	TTNavigator* nav = [TTNavigator navigator];
	nav.window = self.view.window;
	nav.supportsShakeToReload = NO;
	
	// Initialize the toolbar
	self.navigationController.toolbarHidden = NO;

	UIImageView* titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"remailTextTrans.png"]];
	self.navigationItem.titleView = titleView;
	[titleView release];
	
	self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.168 green:0.5 blue:0.741 alpha:1.0];
	self.navigationController.toolbar.tintColor = [UIColor blackColor]; //[UIColor colorWithRed:0.168 green:0.5 blue:0.741 alpha:1.0];
	
	// Create a button
	UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc]
									  initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(toolbarRefreshClicked:)];
	
	progressView = [self createNewProgressViewFromNib];
	[progressView.progressView setHidden:YES];
	[progressView.activity setHidden:YES];
	[progressView.progressLabel setHidden:YES];
	[progressView.updatedLabel setHidden:YES];	
	[progressView.updatedLabelTop setHidden:YES];
	[progressView.clientMessageLabelBottom setHidden:YES];

	UIBarButtonItem *statusButton = [[UIBarButtonItem alloc]
									 initWithImage:[UIImage imageNamed:@"statusButton.png"] style:UIBarButtonItemStylePlain target:self action:@selector(toolbarStatusClicked:)];

	
	UIBarButtonItem *progressItem = [[UIBarButtonItem alloc] initWithCustomView:progressView];
	self.toolbarItems = [NSArray arrayWithObjects:refreshButton,progressItem,statusButton,nil];
	[progressItem release];
	[refreshButton release];
	[statusButton release];
	
	// Set client message invisible
	[clientMessageButton setHidden:YES];
	clientMessage = nil;
	
	dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	// restore previous position in app
	if([[AppSettings lastpos] isEqualToString:@"search"]) {
		[self loadIt];
		[self searchClick:nil];
	} else if ([[AppSettings lastpos] isEqualToString:@"folders"]) {
		[self loadIt];
		[self foldersClick:nil];
	} else if ([[AppSettings lastpos] isEqualToString:@"status"]) {
		[self loadIt];
		[self toolbarStatusClicked:nil];
	}
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"SplashScreenViewController received memory warning");
}
@end
