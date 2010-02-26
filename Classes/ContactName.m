//
//  ContactName.m
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

#import "ContactName.h"
#import "ContactDBAccessor.h"

@implementation ContactName

@synthesize	name, addresses, occurrences;


- (void)dealloc {
	//Release all props added here.
	[name release];
	[addresses release];
	[occurrences release];
	[super dealloc];
}


+(void)recordContact:(NSString*)name withAddress:(NSString*)address {
	return;
}

+(void)autocomplete:(NSString*)query {
	
}


+(int)exactBestName:(NSString*)name {
	int fotype = -1;
	sqlite3 *database = [[ContactDBAccessor sharedManager] database];
	
	NSString *query = [NSString stringWithFormat:@"select pk from contact where name LIKE '%@' LIMIT 1",name];
	
	sqlite3_stmt *statement;
	if (sqlite3_prepare_v2( database, [query UTF8String], -1, &statement, NULL) == SQLITE_OK)
	{
		if (sqlite3_step(statement) == SQLITE_ROW)
		{
			fotype = sqlite3_column_int(statement, 0);
		}
		else
		{
			return -1;
		}
	}
	else
	{
		NSLog(@"prepare fail with query = %@",query);
		//assert(FALSE);
	}
	sqlite3_finalize(statement);
	
	return fotype;
}


+(int)contactCount {
	// Called by Status Screen
	sqlite3_stmt* contactCountStmt = nil;
	//total number of contacts for status display
	NSString* querySQL = @"SELECT count(*) FROM contact_name;";
	int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [querySQL UTF8String], -1, &contactCountStmt, nil);	
	if (dbrc != SQLITE_OK) {
		return 0;
	}
	
	int count = 0;
	if(sqlite3_step(contactCountStmt) == SQLITE_ROW) {
		count = sqlite3_column_int(contactCountStmt, 0);
	}
	
	sqlite3_reset(contactCountStmt);
	
	return count;
}


+(void)createContactSearchTable {
	sqlite3_stmt *testStmt = nil;
	// this "prepare statement" part is really just a method for checking if the tables exist yet
	NSString *updateStmt = @"INSERT OR REPLACE INTO search_contact_name(docid, name) VALUES (?, ?);";
	int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [updateStmt UTF8String], -1, &testStmt, nil);	
	if (dbrc != SQLITE_OK) {
		// create index
		char* errorMsg;	
		int res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE VIRTUAL TABLE search_contact_name USING fts3(name);"] UTF8String] , NULL, NULL, &errorMsg);
		if (res != SQLITE_OK) {
			NSString *errorMessage = [NSString stringWithFormat:@"Failed to execute SQL with message '%s'.", errorMsg];
			NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
			return;
		}
	} 
	
	sqlite3_finalize(testStmt);
}

+(void)tableCheck {
	// create tables as appropriate
	char* errorMsg = nil;	
	int res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE TABLE IF NOT EXISTS contact_name "
																			   "(pk INTEGER PRIMARY KEY, name VARCHAR(50) UNIQUE, email_addresses VARCHAR(500), occurrences INTEGER, "
																			   "sent_invite INTEGER, dbnum_first INTEGER, dbnum_last INTEGER)"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create contact_name table '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}

	// create indices
	res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS contact_name_name on contact_name(name);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create contact_name_name index '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
	res = sqlite3_exec([[ContactDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS contact_name_occurences on contact_name(occurrences DESC);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create contact_name_occurences index '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
	sqlite3_free(errorMsg);	
	
	[ContactName createContactSearchTable];
}
@end
