//
//  CTCoreMessageReMail.m
//  ImapClient3.0
//
//  Created by Stefano Barbato on 25/06/09.
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

#import "CTCoreMessage+ReMail.h"

@implementation CTCoreMessage ( CTCoreMessageReMail ) 

- (struct mailimf_date_time*)libetpanDateTime
{    
    if(!myFields || !myFields->fld_orig_date || !myFields->fld_orig_date->dt_date_time)
        return NULL;
    
    return myFields->fld_orig_date->dt_date_time;
}

- (NSTimeZone*)senderTimeZone
{
    struct mailimf_date_time *d;
    
    if((d = [self libetpanDateTime]) == NULL)
        return nil;
    
    NSInteger timezoneOffsetInSeconds = 3600*d->dt_zone/100;
    
    return [NSTimeZone timeZoneForSecondsFromGMT:timezoneOffsetInSeconds];
}

- (NSDate *)senderDate 
{
    
  	if ( myFields->fld_orig_date == NULL) {
    	return [NSDate distantPast];
	}
  	else {
        struct mailimf_date_time *d;
        
        if((d = [self libetpanDateTime]) == NULL)
            return nil;
        
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *comps = [[NSDateComponents alloc] init];
        
        [comps setYear:d->dt_year];
        [comps setMonth:d->dt_month];
        [comps setDay:d->dt_day];
        [comps setHour:d->dt_hour];
        [comps setMinute:d->dt_min];
        [comps setSecond:d->dt_sec];
        
        NSDate *messageDateNoTimezone = [calendar dateFromComponents:comps];
        
        [comps release];
        [calendar release];
        
        // no timezone applied
        return messageDateNoTimezone;
  	}
}

- (NSDate *)sentDateGMT
{
    struct mailimf_date_time *d;
    
    if((d = [self libetpanDateTime]) == NULL)
        return nil;
    
    NSInteger timezoneOffsetInSeconds = 3600*d->dt_zone/100;
    
    NSDate *date = [self senderDate];
    
    return [date dateByAddingTimeInterval:timezoneOffsetInSeconds * -1];
}

- (NSDate*)sentDateLocalTimeZone
{
    return [[self sentDateGMT] dateByAddingTimeInterval:[[NSTimeZone localTimeZone] secondsFromGMT]];
}

- (NSString*)messageId
{
    struct mailmessage *messageStruct = [self messageStruct];
    
    if(!messageStruct)
        return nil;
    
    mailmessage_resolve_single_fields(messageStruct);
    
    if(!messageStruct || !messageStruct->msg_single_fields.fld_message_id || !messageStruct->msg_single_fields.fld_message_id->mid_value)
        return nil;
    
    return [NSString stringWithCString:messageStruct->msg_single_fields.fld_message_id->mid_value encoding:[NSString defaultCStringEncoding]];
    
}


@end 
