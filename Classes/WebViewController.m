//
//  WebViewController.m
//  NextMailIPhone
//
//  Created by Gabor Cselle on 1/16/09.
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

#import "WebViewController.h"
#import "AppSettings.h"
#import "StringUtil.h"
#import "Reachability.h"
@implementation WebViewController
@synthesize webView;
@synthesize loadingLabel;
@synthesize serverUrl;
@synthesize loadingIndicator;

- (void)dealloc {
	[loadingLabel release];
	[loadingIndicator release];
	[webView release];
	[serverUrl release];
    [super dealloc];
}


- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.loadingLabel = nil;
	self.loadingIndicator = nil;
	self.webView = nil;
	self.serverUrl  = nil;
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	if(![StringUtil stringContains:[NSString stringWithFormat:@"%@", error] subString:@"999"]) {
		self.loadingLabel.text = NSLocalizedString(@"Error loading webpage.", nil);
	}
	
	[self.loadingIndicator stopAnimating];
	[self.loadingIndicator setHidden:YES];
}

-(void)webViewDidFinishLoad:(UIWebView *)webViewLocal {
	[loadingLabel setHidden:YES];
	
	[loadingIndicator setHidden:YES];
	[loadingIndicator stopAnimating];
	NSLog(@"WebViewDidFinishLoad %@", webViewLocal.request);
}

-(void)webViewDidStartLoad:(UIWebView *)webViewLocal {
	NSLog(@"WebViewDidStartLoad");
}

-(void)viewWillAppear:(BOOL)animated {
	[self doLoad];
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)doLoad {
	self.loadingLabel.text = NSLocalizedString(@"Loading ...", nil);
	
	
	[loadingLabel setHidden:NO];
	[loadingIndicator setHidden:NO];
	[loadingIndicator startAnimating];

	self.webView.delegate = self;
	
	NSLog(@"Start Loading WebView: %@", self.serverUrl);
	NSURL *url = [[NSURL alloc] initWithString:self.serverUrl];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
	[self.webView loadRequest:request];
	[url release];
	[request release];
	NSLog(@"End loading WebView");
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
	NSLog(@"WebViewController received memory warning");
}
@end
