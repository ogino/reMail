//
//  UidEntry.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 6/29/09.
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

#import "UidEntry.h"
#import "UidDBAccessor.h"

@implementation UidEntry
+(void)tableCheck {
	// create tables as appropriate
	char* errorMsg;	 
	// note that the table is called uid_entry, not "uid" as in earlier versions that weren't actually adding to this table
	int res = sqlite3_exec([[UidDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE TABLE IF NOT EXISTS uid_entry "
																		  "(pk INTEGER PRIMARY KEY, uid VARCHAR(50), folder_num INTEGER, md5 VARCHAR(32))"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create uid_entry store '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
	
	res = sqlite3_exec([[UidDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS uid_entry_md5 on uid_entry(md5);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create uid_entry_md5 index '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
}
@end
