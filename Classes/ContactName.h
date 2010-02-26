//
//  Contact.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 1/18/09.
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

#import <Foundation/Foundation.h>

@interface ContactName : NSObject {
	NSString* name;
	NSString* addresses;
	NSNumber* occurrences;
}

+(int)contactCount;
+(void)tableCheck;
+(void)recordContact:(NSString*)name withAddress:(NSString*)address;
+(void)autocomplete:(NSString*)query; 

@property(nonatomic,readwrite,retain) NSNumber* occurrences;
@property(nonatomic,readwrite,retain) NSString* name;
@property(nonatomic,readwrite,retain) NSString* addresses;
@end



