//
//  AutocompleteCell.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/18/09.
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

@interface AutocompleteCell : UITableViewCell {
	TTStyledTextLabel *nameLabel;
	TTStyledTextLabel *historyLabel;
	UILabel* addressLabel;
}

-(void)setupText;
-(void)setName:(NSString*)name withAddresses:(NSString*)addresses;

@property (nonatomic,retain) TTStyledTextLabel *nameLabel;
@property (nonatomic,retain) TTStyledTextLabel *historyLabel;
@property (nonatomic,retain) UILabel* addressLabel;
@end