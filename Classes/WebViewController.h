//
//  WebViewController.h
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

#import <UIKit/UIKit.h>


@interface WebViewController : UIViewController <UIWebViewDelegate> {
	IBOutlet UIWebView *webView;
	IBOutlet UILabel *loadingLabel;
	NSString* serverUrl; // url to load from server
	IBOutlet UIActivityIndicatorView* loadingIndicator;
}


-(void)doLoad;
-(void)webViewDidFinishLoad:(UIWebView *)webViewLocal;
@property (nonatomic,retain) UIActivityIndicatorView* loadingIndicator;
@property (nonatomic, retain) UIWebView * webView;
@property (nonatomic, retain) UILabel *loadingLabel;
@property (nonatomic, retain) NSString* serverUrl;
@end
