//
//  DateUtil.m
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

#import "DateUtil.h"
#define DATE_UTIL_SECS_PER_DAY 86400

static DateUtil *singleton = nil;

@implementation DateUtil

@synthesize today;
@synthesize yesterday;
@synthesize lastWeek;
@synthesize todayComponents;
@synthesize yesterdayComponents;
@synthesize dateFormatter;

-(void)dealloc {
	[today release];
	[yesterday release];
	[lastWeek release];
	
	[todayComponents release];
	[yesterdayComponents release];
	[dateFormatter release];
	
	[super dealloc];
}

-(void)refreshData {
	//TODO(gabor): Call this every hour or so to refresh what today, yesterday, etc. mean
	NSCalendar *gregorian = [NSCalendar currentCalendar];
	self.today = [NSDate date];
	self.yesterday = [today dateByAddingTimeInterval:-DATE_UTIL_SECS_PER_DAY];
	self.lastWeek = [today dateByAddingTimeInterval:-6*DATE_UTIL_SECS_PER_DAY];
	self.todayComponents = [gregorian components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:today];
	self.yesterdayComponents = [gregorian components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:yesterday];
	self.dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
}

-(id)init {
	if (self = [super init]) {	
		[self refreshData];
	}
	return self;
}

+(id)getSingleton { //NOTE: don't get an instance of SyncManager until account settings are set!
	@synchronized(self) {
		if (singleton == nil) {
			singleton = [[self alloc] init];
		}
	}
	return singleton;
}

-(NSString*)humanDate:(NSDate*)date {
	
	NSCalendar *gregorian = [NSCalendar currentCalendar];
	
	NSDateComponents *dateComponents = [gregorian components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:date];
	
	if([dateComponents day] == [todayComponents day] && 
	   [dateComponents month] == [todayComponents month] && 
	   [dateComponents year] == [todayComponents year]) {
		[dateFormatter setDateStyle:NSDateFormatterNoStyle];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		
		return [dateFormatter stringFromDate:date];
	}
	if([dateComponents day] == [yesterdayComponents day] && 
	   [dateComponents month] == [yesterdayComponents month] && 
	   [dateComponents year] == [yesterdayComponents year]) {
		return NSLocalizedString(@"yesterday", nil);
	}
	if([date laterDate:lastWeek] == date) {
		[dateFormatter setDateFormat:@"EEEE"];
		return [dateFormatter stringFromDate:date];
	}
	
	[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	return [dateFormatter stringFromDate:date];
}

+(NSDate *)datetimeInLocal:(NSDate *)utcDate
{
	NSTimeZone *utc = [NSTimeZone timeZoneWithName:@"UTC"];
	
	NSTimeZone *local = [NSTimeZone localTimeZone];
	
	NSInteger sourceSeconds = [utc secondsFromGMTForDate:utcDate];
	NSInteger destinationSeconds = [local secondsFromGMTForDate:utcDate];
	
	NSTimeInterval interval =  destinationSeconds - sourceSeconds;
	NSDate *res = [[[NSDate alloc] initWithTimeInterval:interval sinceDate:utcDate] autorelease];
	return res;
	
}

@end
