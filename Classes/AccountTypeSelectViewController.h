//
//  AccountTypeSelectViewController.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/15/09.
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


@interface AccountTypeSelectViewController : UIViewController {
	BOOL firstSetup;
	BOOL showIntro;
	BOOL newAccount;
	int accountNum;	
	
	IBOutlet UILabel* rackspaceLabel;
	IBOutlet UIButton* rackspaceButton;

	IBOutlet UILabel* imapLabel;
	IBOutlet UIButton* imapButton;
	
	IBOutlet UIButton* buyButton;
}

@property (assign) BOOL firstSetup;
@property (assign) BOOL newAccount;
@property (assign) int accountNum;

@property (nonatomic,retain) UILabel* rackspaceLabel;
@property (nonatomic,retain) UIButton* rackspaceButton;
@property (nonatomic,retain) UILabel* imapLabel;
@property (nonatomic,retain) UIButton* imapButton;
@property (nonatomic,retain) UIButton* buyButton;

-(IBAction)gmailClicked;
-(IBAction)rackspaceClicked;
-(IBAction)imapClicked;
-(IBAction)buyClick;
@end
