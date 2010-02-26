//
//  UsageViewController.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 10/8/09.
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
#import <MessageUI/MessageUI.h>

@interface UsageViewController : UITableViewController<UIActionSheetDelegate, MFMailComposeViewControllerDelegate> {
	IBOutlet UILabel* rankHeader;
	IBOutlet UIButton* rank0;
	IBOutlet UIButton* rank1;
	IBOutlet UIButton* rank2;
	IBOutlet UIButton* rank3;
	IBOutlet UIButton* rank4;	
	
	IBOutlet UILabel* recommendTitle;
	IBOutlet UILabel* recommendSubtitle;
	
	IBOutlet UITableView* tableViewCopy;
	
	NSMutableArray* contactData;
	int lastRowClicked;
}

@property (nonatomic,retain) UILabel* rankHeader;
@property (nonatomic,retain) UIButton* rank0;
@property (nonatomic,retain) UIButton* rank1;
@property (nonatomic,retain) UIButton* rank2;
@property (nonatomic,retain) UIButton* rank3;
@property (nonatomic,retain) UIButton* rank4;	
@property (nonatomic,retain) UILabel* recommendTitle;
@property (nonatomic,retain) UILabel* recommendSubtitle;
@property (nonatomic,retain) NSMutableArray* contactData;
@property (nonatomic,retain) UITableView* tableViewCopy;
@property (assign) int lastRowClicked;

-(IBAction)rankClicked:(UIView*)sender;
@end
