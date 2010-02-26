//
//  PastQuery.m
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

#import "PastQuery.h"
#import "ContactDBAccessor.h"
#import "DateUtil.h"

@implementation PastQuery

@synthesize datetime,text;

- (void)dealloc {
	[datetime release];
	[text release];
	[super dealloc];
}

+(NSArray *)indices {
	// used for quickly displaying the past query list in the UI
	NSArray *timeIndex = [NSArray arrayWithObject:@"datetime desc"];
	return [NSArray arrayWithObjects:timeIndex, nil];
}

+(void)recordQuery:(NSString*)queryText withType:(int)searchType {
	// record a query for queryText - update the DB accordingly 

	sqlite3_stmt *insertStmt = nil;
	
	NSString *updateStmt = @"INSERT OR REPLACE INTO past_query(datetime, text, search_type) VALUES (?, ?, ?);";
	int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [updateStmt UTF8String], -1, &insertStmt, nil);	
	if (dbrc != SQLITE_OK) 	{
		NSLog(@"Failed step in recordQuery with error %s", sqlite3_errmsg([[ContactDBAccessor sharedManager] database]));
		return;
	}

	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	NSString *formattedDateString = [dateFormatter stringFromDate:[NSDate date]];
	[dateFormatter release];
	
	sqlite3_bind_text(insertStmt, 1, [formattedDateString UTF8String], -1, NULL);
	sqlite3_bind_text(insertStmt, 2, [queryText UTF8String], -1, NULL);
	sqlite3_bind_int(insertStmt, 3, searchType);

	if (sqlite3_step(insertStmt) != SQLITE_DONE) {
		NSLog(@"==========> Error inserting or updating PastQuery");
	}
	sqlite3_reset(insertStmt);
	

	if (insertStmt) {
		sqlite3_finalize(insertStmt);
		insertStmt = nil;
	}
	
	return;
}

+(void)clearAll {
	char* errorMsg;	
	int res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"DELETE FROM past_query"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create past_query table '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
}

+(NSDictionary*)recentQueries {
	static sqlite3_stmt *stmt = nil;
	if(stmt == nil) {
		NSString *statement = @"SELECT datetime, text, search_type FROM past_query ORDER BY datetime DESC LIMIT 50;";
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [statement UTF8String], -1, &stmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed step in bindStmt with error %s", sqlite3_errmsg([[ContactDBAccessor sharedManager] database]));
			return [NSDictionary dictionary];
		}
		
	}
	
	NSMutableArray* queries = [NSMutableArray arrayWithCapacity:50];
	NSMutableArray* datetimes = [NSMutableArray arrayWithCapacity:50];
	NSMutableArray* searchTypes = [NSMutableArray arrayWithCapacity:50]; 
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	while((sqlite3_step (stmt)) == SQLITE_ROW) {
		
		NSDate *date = [NSDate date]; // default == now!
		const char * sqlVal = (const char *)sqlite3_column_text(stmt, 0);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [dateFormatter dateFromString:dateString];
		}
		
		sqlVal = (const char *)sqlite3_column_text(stmt, 1);
		NSString* text = [NSString stringWithUTF8String:sqlVal];

		int searchType= sqlite3_column_int(stmt, 2);
		
		[datetimes addObject:date];
		[queries addObject:text];
		[searchTypes addObject:[NSNumber numberWithInt:searchType]];
	}
	
	sqlite3_reset(stmt);
	stmt = nil;
	
	[dateFormatter release];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:datetimes, @"datetimes", queries, @"queries", searchTypes, @"searchTypes", nil];
}


+(void)tableCheck {
	// create tables as appropriate
	char* errorMsg;	
	int res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE TABLE IF NOT EXISTS past_query "
																			   "(pk INTEGER PRIMARY KEY, datetime REAL, text VARCHAR(50) UNIQUE, search_type INTEGER)"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create past_query table '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
		return;
	}
}
@end

