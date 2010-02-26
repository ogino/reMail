//
//  PastQuery.h
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
//  Represents a query that the user has run in the past.

#import <Foundation/Foundation.h>

@interface PastQuery : NSObject {
	NSDate *datetime;
	NSString *text;
}

+(void)clearAll;
+(void)tableCheck;
+(NSDictionary*)recentQueries;
+(void)recordQuery:(NSString*)queryText withType:(int)type;

@property (nonatomic,readwrite,retain) NSDate *datetime;
@property (nonatomic,readwrite,retain) NSString *text;
@end

