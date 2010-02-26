//
//  StoreItemViewController.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 11/11/09.
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
//  Note: This code isn't used anymore. We kept it in the project because you might
//        find it useful for implementing your own in-app stores.

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface StoreItemViewController : UIViewController {
	SKProduct* product;
	
	IBOutlet UILabel* productTitleLabel;
	IBOutlet UILabel* productDescriptionLabel;
	IBOutlet UIImageView* productImageView;
	IBOutlet UIButton* buyButton;
	IBOutlet UILabel* recommendLabel;
	IBOutlet UIButton* recommendButton;	
	
	IBOutlet UIActivityIndicatorView* activityIndicator;
}

@property (nonatomic, retain) SKProduct* product;
@property (nonatomic, retain) IBOutlet UILabel* productTitleLabel;
@property (nonatomic, retain) IBOutlet UILabel* productDescriptionLabel;
@property (nonatomic, retain) IBOutlet UIImageView* productImageView;
@property (nonatomic, retain) IBOutlet UIButton* buyButton;
@property (nonatomic, retain) IBOutlet UILabel* recommendLabel;
@property (nonatomic, retain) IBOutlet UIButton* recommendButton;	
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView* activityIndicator;


-(IBAction)purchase;
-(IBAction)recommend;
@end
