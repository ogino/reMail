//
//  GmailConfigViewController.h
//  GmailConfig
//
//  Created by Gabor Cselle on 3/22/09.
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

@interface GmailConfigViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate> {
	IBOutlet UIScrollView* scrollView;
	
	IBOutlet UILabel* serverMessage;
	IBOutlet UIActivityIndicatorView* activityIndicator;
	IBOutlet UITextField* usernameField;
	IBOutlet UITextField* passwordField;
	IBOutlet UIButton* selectFoldersButton;
	
	IBOutlet UILabel* privacyNotice;
	
	int accountNum;
	BOOL newAccount;
	BOOL firstSetup;
}

-(IBAction)loginClick;
-(IBAction)backgroundClick;
-(IBAction)selectFoldersClicked;

@property (nonatomic, retain) IBOutlet UIScrollView* scrollView;
@property (nonatomic, retain) IBOutlet UILabel* serverMessage;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView* activityIndicator;
@property (nonatomic, retain) IBOutlet UITextField* usernameField;
@property (nonatomic, retain) IBOutlet UITextField* passwordField;
@property (nonatomic, retain) IBOutlet UIButton* selectFoldersButton;
@property (nonatomic, retain) IBOutlet UILabel* privacyNotice;
@property (assign) int accountNum;
@property (assign) BOOL newAccount;
@property (assign) BOOL firstSetup;
@end

