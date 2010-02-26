//
//  Email.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 1/16/09.
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

#import "Email.h"
#import "LoadEmailDBAccessor.h"
#import "DateUtil.h"
#import "AppSettings.h"

static sqlite3_stmt *inboxStmt = nil;

@implementation Email

@synthesize pk, senderName, senderAddress, tos, ccs, bccs, datetime, msgId, attachments, folder, folderNum, uid, subject, body, metaString;

- (void)dealloc {
	[senderName release];
	[senderAddress release];
	[tos release];
	[ccs release];
	[bccs release];
	[datetime release];
	[msgId release];
	[attachments release];
	[folder release];
	[subject release];
	[body release];
	[metaString release];
	[uid release];
	
	if(inboxStmt != nil) {
		sqlite3_finalize(inboxStmt);
		inboxStmt = nil;
	}
	
	[super dealloc];
}

-(BOOL)hasAttachment {
	return (self.attachments != nil) && ([self.attachments length] > 2);
}

+(void)createEmailSearchTable {
	sqlite3_stmt *testStmt = nil;
	// this "prepare statement" part is really just a method for checking if the tables exist yet
	NSString *updateStmt = @"SELECT docid FROM search_email WHERE subject = ?;";
	int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [updateStmt UTF8String], -1, &testStmt, nil);	
	if (dbrc != SQLITE_OK) {
		// create index
		char* errorMsg;	
		NSString *statement = @"CREATE VIRTUAL TABLE search_email USING fts3(meta_string, subject, body);";
		if([AppSettings dataInitVersion] != nil) { // new search_email format
			statement = @"CREATE VIRTUAL TABLE search_email USING fts3(meta, subject, body, sender, tos, ccs, folder);";
		}
		
		int res = sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:statement] UTF8String] , NULL, NULL, &errorMsg);
		if (res != SQLITE_OK) {
			//NSString *errorMessage = [NSString stringWithFormat:@"Failed to create search_email with message '%s'.", errorMsg];
			//NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
		}
	} else {
		sqlite3_finalize(testStmt);
	}
}

+(void)tableCheck {
	// create tables as appropriate
	char* errorMsg;	
	int res = sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE TABLE IF NOT EXISTS email "
																			  "(pk INTEGER PRIMARY KEY, datetime REAL, sender_name VARCHAR(50), sender_address VARCHAR(50), "
																			  "tos TEXT, ccs TEXT, bccs TEXT, attachments TEXT, msg_id VARCHAR(50), uid VARCHAR(20), folder VARCHAR(20), folder_num INTEGER, folder_num_1 INTEGER, folder_num_2 INTEGER, folder_num_3 INTEGER, extra INTEGER);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create email table '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
	
	res = sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_datetime on email (datetime desc);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create email_datetime table '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
	
	res = sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_sender_address on email (sender_address);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create email_sender_address index '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}

	res = sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_folder_num_0 on email (folder_num);"] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to create folder_num_0 index '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}

	sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_folder_num_1 on email (folder_num_1);"] UTF8String] , NULL, NULL, &errorMsg);
	sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_folder_num_2 on email (folder_num_2);"] UTF8String] , NULL, NULL, &errorMsg);
	sqlite3_exec([[AddEmailDBAccessor sharedManager] database],[[NSString stringWithString:@"CREATE INDEX IF NOT EXISTS email_folder_num_3 on email (folder_num_3);"] UTF8String] , NULL, NULL, &errorMsg);
	
	[Email createEmailSearchTable];
}


+(void)deleteWithPk:(int)pk {
	char* errorMsg;	
	int res = sqlite3_exec([[LoadEmailDBAccessor sharedManager] database],[[NSString stringWithFormat:@"DELETE FROM email WHERE pk=%i; DELETE FROM search_email WHERE docid=%i;", pk, pk] UTF8String] , NULL, NULL, &errorMsg);
	if (res != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to delete email with message '%s'.", errorMsg];
		NSLog(@"errorMessage = '%@, original ERROR CODE = %i'",errorMessage,res);
	}
}

-(void)loadData:(int)pkToLoad{
	static sqlite3_stmt *emailLoadStmt = nil;
	
	NSString *statement = [NSString stringWithFormat:@"SELECT email.pk, email.datetime, email.sender_name, email.sender_address, email.tos, email.ccs, email.bccs, email.attachments, email.msg_id, email.folder, email.folder_num, email.uid, "
						   "search_email.meta, search_email.subject, search_email.body FROM email, search_email WHERE email.pk = search_email.docid AND email.pk = %i LIMIT 1;", pkToLoad];
	if([AppSettings dataInitVersion] == nil) { // meta used to be called meta_string
		statement = [NSString stringWithFormat:@"SELECT email.pk, email.datetime, email.sender_name, email.sender_address, email.tos, email.ccs, email.bccs, email.attachments, email.msg_id, email.folder, email.folder_num, email.uid, "
					 "search_email.meta_string, search_email.subject, search_email.body FROM email, search_email WHERE email.pk = search_email.docid AND email.pk = %i LIMIT 1;", pkToLoad];
	}
	
	int dbrc;
	dbrc = sqlite3_prepare_v2([[LoadEmailDBAccessor sharedManager] database], [statement UTF8String], -1, &emailLoadStmt, nil);
	if (dbrc != SQLITE_OK) {
			NSLog(@"Failed step in loadData with error %s", sqlite3_errmsg([[LoadEmailDBAccessor sharedManager] database]));
	}		
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	//Exec query - 
	if(sqlite3_step (emailLoadStmt) == SQLITE_ROW) {
		self.pk = sqlite3_column_int(emailLoadStmt, 0);
		
		NSDate *date = [NSDate date]; // default == now!
		const char * sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 1);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [DateUtil datetimeInLocal:[dateFormatter dateFromString:dateString]];
		}
		self.datetime = date;
		
		NSString* temp = @"";
		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 2);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; }
		self.senderName = temp;
		
		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 3);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; }
		self.senderAddress = temp; 
		
		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 4);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; }
		self.tos = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 5);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; }
		self.ccs = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 6);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; }
		self.bccs = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 7);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.attachments = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 8);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.msgId = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 9);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.folder = temp;
		
		self.folderNum = sqlite3_column_int(emailLoadStmt, 10);

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 11);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.uid = temp;
		
		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 12);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.metaString = temp;
		
		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 13);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.subject = temp;

		sqlVal = (const char *)sqlite3_column_text(emailLoadStmt, 14);
		if(sqlVal != nil) {	temp = [NSString stringWithUTF8String:sqlVal]; } 
		self.body = temp;
	} 
	
	sqlite3_finalize(emailLoadStmt);	
	[dateFormatter release];
}
@end

