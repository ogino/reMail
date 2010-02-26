//
//  UpsellViewController.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 10/11/09.
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


@interface UpsellViewController : UIViewController {
	IBOutlet UILabel *descriptionLabel;
	IBOutlet UILabel *howToActivateLabel;
	IBOutlet UILabel *featureFreeLabel;
	IBOutlet UIButton *recommendButton;
	int recommendationsToMake;
}

@property (nonatomic, retain) UILabel *descriptionLabel;
@property (nonatomic, retain) UILabel *howToActivateLabel;
@property (nonatomic, retain) UILabel *featureFreeLabel;
@property (nonatomic, retain) UIButton *recommendButton;
@property (assign) int recommendationsToMake;

-(IBAction)recommendRemail;
@end
