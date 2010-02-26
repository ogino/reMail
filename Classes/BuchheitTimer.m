//
//  BucheitTimer.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 2/16/09.
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
//  Inspired by Paul Buchheit's YCombinator talk ("measure everything")

#import "BuchheitTimer.h"


@implementation BuchheitTimer

@synthesize ongoingTimers,insertOrder;

- init
{
	if (self = [super init]) 
	{
		self.ongoingTimers = [[NSMutableDictionary alloc] init];
		self.insertOrder = [[NSMutableArray alloc] init];
	}
	return self;

}

-(void) dealloc
{
	[ongoingTimers release];
	[insertOrder release];
	[super dealloc];
}

-(void)recordTimeWithTag:(NSString *)tag
{
	NSMutableDictionary *timeRec = [[NSMutableDictionary alloc] init];
	[timeRec setObject:[NSDate date] forKey:@"time"];
	[timeRec setObject:tag forKey:@"tag"];
	[self.insertOrder addObject:timeRec];
	[timeRec release];
	
}

-(void)finishAndReport
{
	for(NSInteger i = 0; i < [insertOrder count]; i++)
	{
		if(i > 0)
		{
			double foo = [[[insertOrder objectAtIndex:(i)] objectForKey:@"time"] timeIntervalSinceDate:[[insertOrder objectAtIndex:(i-1)] objectForKey:@"time"]];
			double houndreds = foo*100;
			NSMutableString *viz = [NSMutableString stringWithCapacity:foo];
			for(NSInteger j = 0; j < houndreds; j++)
			{
				[viz appendString:@"|"];
			}
			NSLog(@"PBTimer: Between '%@' and '%@':\n%@\n took %f s",[[insertOrder objectAtIndex:(i-1)] objectForKey:@"tag"],[[insertOrder objectAtIndex:i] objectForKey:@"tag"],viz,foo);
		}
	}
	
}

@end
