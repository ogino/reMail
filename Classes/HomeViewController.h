//
//  HomeViewController.h
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

#import <UIKit/UIKit.h>
#import "Three20/Three20.h"
#import "MailboxViewController.h"
#import "SearchEntryViewController.h"

@interface HomeViewController : UIViewController{
	IBOutlet UIButton* clientMessageButton;
	
	NSString* clientMessage;
	NSString* errorDetail;
}

-(void)loadIt;
-(IBAction)accountListClick:(id)sender;
-(IBAction)searchClick:(id)sender;
-(IBAction)foldersClick:(id)sender;
-(IBAction)toolbarStatusClicked:(id)sender;
-(IBAction)toolbarRefreshClicked:(id)sender;
-(IBAction)clientMessageClick;
-(IBAction)usageClick:(id)sender;
-(void)didChangeClientMessageTo:(id)object;

@property (nonatomic, retain) UIButton* clientMessageButton;
@property (nonatomic, retain) NSString* clientMessage;
@property (nonatomic, retain) NSString* errorDetail;
@end

