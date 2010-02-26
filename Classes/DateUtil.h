//
//  DateUtil.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 3/17/09.
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


@interface DateUtil : NSObject {
	NSDate *today;
	NSDate *yesterday;
	NSDate *lastWeek;
	
	NSDateFormatter* dateFormatter;
	NSDateComponents* todayComponents;
	NSDateComponents* yesterdayComponents;
}

@property (nonatomic, retain) NSDate *today;
@property (nonatomic, retain) NSDate *yesterday;
@property (nonatomic, retain) NSDate *lastWeek;
@property (nonatomic, retain) NSDateFormatter* dateFormatter;
@property (nonatomic, retain) NSDateComponents* todayComponents;
@property (nonatomic, retain) NSDateComponents* yesterdayComponents;


+(id)getSingleton;
-(NSString*)humanDate:(NSDate*)date;
+(NSDate *)datetimeInLocal:(NSDate *)utcDate;
@end
