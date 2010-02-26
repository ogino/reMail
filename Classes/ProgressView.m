//
//  ProgressView.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 3/16/09.
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

#import "ProgressView.h"


@implementation ProgressView

@synthesize progressLabel;
@synthesize updatedLabel;
@synthesize progressView;
@synthesize activity;

@synthesize updatedLabelTop;
@synthesize clientMessageLabelBottom;


- (void)dealloc {
	[progressLabel release];
	[updatedLabel release];
	[progressView release];
	[activity release];
	
	[updatedLabelTop release];
	[clientMessageLabelBottom release];
	
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // Initialization code
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    // Drawing code
}
@end
