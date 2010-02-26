//
//  StoreItemCell.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 11/12/09.
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


@interface StoreItemCell : UITableViewCell {
	IBOutlet UILabel *titleLabel;
	IBOutlet UILabel *priceLabel;
	IBOutlet UIImageView *productIcon;
	IBOutlet UIImageView *purchasedIcon;
}

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *priceLabel;
@property (nonatomic, retain) UIImageView *productIcon;
@property (nonatomic, retain) UIImageView *purchasedIcon;
@end
