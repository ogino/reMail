//
//  AttachmentViewController.h
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

#import <UIKit/UIKit.h>


@interface AttachmentViewController : UIViewController <UIWebViewDelegate> {
	IBOutlet UIWebView* webWiew;
	IBOutlet UILabel *loadingLabel;
	IBOutlet UIActivityIndicatorView* loadingIndicator;
	
	NSString* contentType;
	NSString* uid;
	int attachmentNum;
	int folderNum;
	int accountNum;
}

-(void)doLoad;
-(void)deliverAttachment;
-(void)deliverError:(NSString*)error;

@property (nonatomic, retain) UIWebView* webWiew;
@property (nonatomic, retain) UILabel *loadingLabel;
@property (nonatomic, retain) UIActivityIndicatorView* loadingIndicator;
@property (nonatomic, retain) NSString* uid;
@property (nonatomic, retain) NSString* contentType;
@property (assign) int attachmentNum;
@property (assign) int folderNum;
@property (assign) int accountNum;
@end
