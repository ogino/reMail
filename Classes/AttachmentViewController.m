//
//  AttachmentViewController.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/7/09.
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

#import "AttachmentViewController.h"
#import "AttachmentDownloader.h"
#import "AppSettings.h"

@implementation AttachmentViewController

@synthesize webWiew;
@synthesize loadingLabel;
@synthesize loadingIndicator;
@synthesize uid;
@synthesize attachmentNum;
@synthesize accountNum;
@synthesize folderNum;
@synthesize contentType;

- (void)dealloc {
	[webWiew release];
	[loadingLabel release];
	[loadingIndicator release];
	[contentType release];
	[uid release];
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.webWiew = nil;
	self.loadingLabel = nil;
	self.loadingIndicator = nil;
	self.contentType  = nil;
	self.uid  = nil;
}

-(void)doLoad {
	[self.loadingLabel setHidden:NO];
	[self.loadingIndicator setHidden:NO];
	[self.loadingIndicator startAnimating];
	
	[AttachmentDownloader ensureAttachmentDirExists];
	
	NSString* filename = [AttachmentDownloader fileNameForAccountNum:self.accountNum folderNum:self.folderNum uid:self.uid attachmentNum:self.attachmentNum];
	NSString* attachmentDir = [AttachmentDownloader attachmentDirPath];
	NSString* attachmentPath = [attachmentDir stringByAppendingPathComponent:filename];
	
	// try to find attachment on disk
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:attachmentPath]) {
		// load it, display it
		[self performSelectorOnMainThread:@selector(deliverAttachment) withObject:nil waitUntilDone:NO];
		return;		
	}
	
	// else, fetch from Gmail
	AttachmentDownloader* downloader = [[AttachmentDownloader alloc] init];
	downloader.uid = self.uid;
	downloader.attachmentNum = self.attachmentNum;
	downloader.delegate = self;
	downloader.folderNum = self.folderNum;
	downloader.accountNum = self.accountNum;
	
	NSThread *driverThread = [[NSThread alloc] initWithTarget:downloader selector:@selector(run) object:nil];
	[driverThread start];
	[driverThread release];
	
	[downloader release];
}

-(void)deliverProgress:(NSString*)message {
	self.loadingLabel.text = message;
}

-(void)deliverError:(NSString*)error {
	[self.loadingLabel setHidden:YES];
	[self.loadingIndicator setHidden:YES];
	[self.loadingIndicator stopAnimating];
	
	UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:@"Error downloading attachment" message:error delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	[alertView show];	
}

-(void)deliverAttachment {
	NSString* filename = [AttachmentDownloader fileNameForAccountNum:self.accountNum folderNum:self.folderNum uid:self.uid attachmentNum:self.attachmentNum];
	NSString* attachmentDir = [AttachmentDownloader attachmentDirPath];
	NSString* attachmentPath = [attachmentDir stringByAppendingPathComponent:filename];
	
	NSLog(@"Opening filename: %@, content type: %@", filename, contentType);
	
	NSURLRequest * request = [[NSURLRequest alloc] initWithURL:[NSURL fileURLWithPath:attachmentPath isDirectory:NO]];
	[self.webWiew loadRequest:request];
	
	self.loadingLabel.text = @"Displaying ...";
	[request release];
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}


-(void)webViewDidFinishLoad:(UIWebView *)webViewLocal {
	[loadingLabel setHidden:YES];
	[loadingIndicator setHidden:YES];
	[loadingIndicator stopAnimating];
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	NSLog(@"didFailLoadWithError: %@", error);
	loadingLabel.text = [NSString stringWithFormat:@"Error: %@", error];
	[loadingIndicator setHidden:YES];
	[loadingIndicator stopAnimating];
}
	
-(void)viewDidLoad {
	self.webWiew.delegate = self;
	self.webWiew.scalesPageToFit = YES;
	self.title = NSLocalizedString(@"Attachment",nil);
}

-(void)viewWillAppear:(BOOL)animated {
	[self.loadingIndicator startAnimating];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}
@end
