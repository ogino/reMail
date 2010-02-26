//
//  ActivityIndicator.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 2/13/09.
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

#import "ActivityIndicator.h"
#import <UIKit/UIApplication.h>
@implementation ActivityIndicator

static int count = 0;

+(void)on {
	// turns network activity indicator in the status bar on
	count++;
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

+(void)off {
	// turns it off if everyone who called on called off
	count--;
	if (count <= 0) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		count = 0;
	}
}
@end
