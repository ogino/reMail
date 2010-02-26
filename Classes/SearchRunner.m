//
//  SearchRunner.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 3/29/09.
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

#import "SearchRunner.h"
#import "SearchEmailDBAccessor.h"
#import "LoadEmailDBAccessor.h"
#import "ContactDBAccessor.h"
#import "GlobalDBFunctions.h"
#import "DateUtil.h"
#import "SyncManager.h"
#import "EmailProcessor.h"
#import "AppSettings.h"


#define MIN_TO_FIND 10 // minimum number of emails to find before we can stop a search

static SearchRunner *searchSingleton = nil;

static sqlite3_stmt *autocompleteStmt = nil;
static sqlite3_stmt *contactNameFindStmt = nil;

@implementation SearchRunner
@synthesize operationQueue;
@synthesize cancelled;
@synthesize autocompleteLock;

+ (void)clearPreparedStmts {
	if(contactNameFindStmt != nil) {
		sqlite3_finalize(contactNameFindStmt);
		contactNameFindStmt = nil;
	}
	if(autocompleteStmt != nil) {
		sqlite3_finalize(autocompleteStmt);
		autocompleteStmt = nil;
	}
}

- (void) dealloc {
	[operationQueue release];
	[super dealloc];
}
	
+(id)getSingleton {
	@synchronized(self) {
		if (searchSingleton == nil) {
			searchSingleton = [[SearchRunner alloc] init]; 
		}
	}
	return searchSingleton;
}

-(id)init {
	if(self = [super init]) {
		NSOperationQueue *ops = [[[NSOperationQueue alloc] init] autorelease];
		[ops setMaxConcurrentOperationCount:2]; // 1 for the search process, and one for delivering the results
		self.operationQueue = ops;
		self.autocompleteLock = [[[NSObject alloc] init] autorelease];
	}
	
	return self;
}


-(void)switchToDB:(NSString*)fileName {
	[[SearchEmailDBAccessor sharedManager] close];
	[[SearchEmailDBAccessor sharedManager] setDatabaseFilepath:[StringUtil filePathInDocumentsDirectoryForFileName:fileName]];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Full-text search
#pragma mark Full-text search

- (int)performFTSearch:(NSString*)query withDelegate:(id)delegate withSnippetDelims:(NSArray *)snippetDelims withDbNum:(int)dbNum {
	
	
	sqlite3_stmt *ftSearchStmt = nil;
	NSString *queryString = @"SELECT email.pk, email.sender_name, email.sender_address, search_email.subject, email.datetime, "
	"LENGTH(email.attachments), SUBSTR(search_email.body,0,150), "
	"snippet(search_email, ?, ?, '...'), email.folder_num   FROM "
	"email, search_email "
	"WHERE email.pk = search_email.docid AND (search_email MATCH ?)"
	"ORDER BY email.datetime DESC;";
	int dbrc = sqlite3_prepare_v2([[SearchEmailDBAccessor sharedManager] database], [queryString UTF8String], -1, &ftSearchStmt, nil);	
	if (dbrc != SQLITE_OK) {
		NSLog(@"Failed preparing ftSearchStmt with error %s", sqlite3_errmsg([[SearchEmailDBAccessor sharedManager] database]));
		return 0;
	}
	
	sqlite3_bind_text(ftSearchStmt, 1, [[snippetDelims objectAtIndex:0] UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_text(ftSearchStmt, 2, [[snippetDelims objectAtIndex:1] UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_text(ftSearchStmt, 3, [query UTF8String], -1, SQLITE_TRANSIENT);	
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	int count = 0;
	NSMutableArray* resArray = [[NSMutableArray alloc] initWithCapacity:100]; // released in the receiver
	while(sqlite3_step(ftSearchStmt) == SQLITE_ROW) {
		count++;
		
		NSMutableDictionary *res= [[NSMutableDictionary alloc] init];
		
		int pk = sqlite3_column_int(ftSearchStmt, 0);
		NSNumber *primaryKeyValue = [NSNumber numberWithInt:pk];					
		[res setObject:primaryKeyValue forKey: @"pk"];
		
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 1);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderName"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 2);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderAddress"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 3);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"subject"];			
		
		NSDate *date = [NSDate date];
		sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 4);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [DateUtil datetimeInLocal:[dateFormatter dateFromString:dateString]];
		}
		[res setObject:date forKey:@"datetime"];
		
		int hasAttachmentInt = sqlite3_column_int(ftSearchStmt, 5) - 2; // will be non-0 if there are attachments, the -2 are to counter the string "[]"
		NSNumber *hasAttachment = [NSNumber numberWithInt:hasAttachmentInt];
		[res setObject:hasAttachment forKey: @"hasAttachment"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 6);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"body"];			
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(ftSearchStmt, 7);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"snippet"];
		
		int folderNum = sqlite3_column_int(ftSearchStmt, 8);
		NSNumber *folderNumValue = [NSNumber numberWithInt:folderNum];
		[res setObject:folderNumValue forKey: @"folderNum"];
		
		[res setObject:[NSNumber numberWithInt:dbNum] forKey:@"dbNum"];
		
		[resArray addObject:res];
		
		if(self.cancelled) { [res release]; break; }
		
		if(count <= 4 || (count % 25 == 0)) {
			if([delegate respondsToSelector:@selector(deliverSearchResults:)]) {
				[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
			}
			resArray = [[NSMutableArray alloc] initWithCapacity:100];
		}
		
		[res release];
	}
	
	[dateFormatter release];

	if(!self.cancelled) { 
		if([resArray count] > 0 && [delegate respondsToSelector:@selector(deliverSearchResults:)]) {
			[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
		} else {
			[resArray release];
		}
	}
	
	sqlite3_finalize(ftSearchStmt);	
	return count;
}	

- (void)performFTSearchAsync:(NSDictionary *)queryDict {
	// calls to this function are enqueued by search above on an operationsQueue
	NSString *query = [queryDict objectForKey:@"query"];
	id delegate = [queryDict objectForKey:@"delegate"];
	NSArray *snippetDelims = [queryDict objectForKey:@"snippetDelims"];
	
	int dbIndex = [[queryDict objectForKey:@"dbIndex"] intValue];
	
	NSArray* dbNumbers = [GlobalDBFunctions emailDBNumbers];
	int totalFound = 0;
	
	while(dbIndex < [dbNumbers count] && totalFound < MIN_TO_FIND) {
		
		// update: searching through DB with dbNum
		if([delegate respondsToSelector:@selector(deliverProgressUpdate:)]) {
			[delegate performSelector:@selector(deliverProgressUpdate:) withObject:[NSNumber numberWithInt:dbIndex]];
		}
		
		int dbNum = [[dbNumbers objectAtIndex:dbIndex] intValue];
		
		[self switchToDB:[GlobalDBFunctions dbFileNameForNum:dbNum]];

		int count = [self performFTSearch:query withDelegate:delegate withSnippetDelims:snippetDelims withDbNum:dbNum];
		totalFound += count;	
		dbIndex++;
		
		if(self.cancelled) { break; }
	}
	
	[[SearchEmailDBAccessor sharedManager] close];
	
	NSNumber* additionalResults = [NSNumber numberWithBool:(dbIndex < [dbNumbers count])];
	if([delegate respondsToSelector:@selector(deliverAdditionalResults:)]) {
		[delegate performSelector:@selector(deliverAdditionalResults:) withObject:additionalResults];
	}
}

- (void)ftSearch:(NSString*)query withDelegate:(id)delegate withSnippetDelims:(NSArray *)snippetDelims startWithDB:(int)dbIndex {
	
	NSLog(@"ftSearch started with query = %@ dbNum = %i", query, dbIndex);
	
	self.cancelled = NO;
	
	//Create the queryOp object
	NSMutableDictionary *queryOp = [[[NSMutableDictionary alloc] init] autorelease];
	[queryOp setObject:query forKey:@"query"];
	[queryOp setObject:delegate forKey:@"delegate"];
	[queryOp setObject:[NSNumber numberWithInt:dbIndex] forKey:@"dbIndex"];
	[queryOp setObject:snippetDelims forKey:@"snippetDelims"];
		
	//Invoke search
	NSInvocationOperation* searchOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performFTSearchAsync:) object:queryOp];
	assert(searchOp != nil);
	[self.operationQueue addOperation:searchOp]; 
	[searchOp release];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// All Mail "Search"
#pragma mark All Mail "Search"


- (int)performAllMailWithDelegate:(id)delegate withDbNum:(int)dbNum {
	
	sqlite3_stmt *allMailStmt = nil;
	NSString *queryString = @"SELECT email.pk, email.sender_name, email.sender_address, search_email.subject, email.datetime, "
	"LENGTH(email.attachments), SUBSTR(search_email.body,0,150), email.folder_num FROM "
	"email, search_email "
	"WHERE email.pk = search_email.docid "
	"ORDER BY email.datetime DESC;";
	int dbrc = sqlite3_prepare_v2([[SearchEmailDBAccessor sharedManager] database], [queryString UTF8String], -1, &allMailStmt, nil);	
	if (dbrc != SQLITE_OK) {
		NSLog(@"Failed preparing allMailStmt with error %s", sqlite3_errmsg([[SearchEmailDBAccessor sharedManager] database]));
		return 0;
	}
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	int count = 0;
	NSMutableArray* resArray = [[NSMutableArray alloc] initWithCapacity:100]; // released in the receiver
	
	while(sqlite3_step(allMailStmt) == SQLITE_ROW) {
		count++;
		
		NSMutableDictionary *res= [[NSMutableDictionary alloc] init];
		
		int pk = sqlite3_column_int(allMailStmt, 0);
		NSNumber *primaryKeyValue = [NSNumber numberWithInt:pk];					
		[res setObject:primaryKeyValue forKey: @"pk"];
		
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(allMailStmt, 1);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderName"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(allMailStmt, 2);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderAddress"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(allMailStmt, 3);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"subject"];			
		
		NSDate *date = [NSDate date];
		sqlVal = (const char *)sqlite3_column_text(allMailStmt, 4);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [DateUtil datetimeInLocal:[dateFormatter dateFromString:dateString]];
		}
		[res setObject:date forKey:@"datetime"];
		
		int hasAttachmentInt = sqlite3_column_int(allMailStmt, 5) - 2; // will be non-0 if there are attachments, the -2 are to counter the string "[]"
		NSNumber *hasAttachment = [NSNumber numberWithInt:hasAttachmentInt];
		[res setObject:hasAttachment forKey: @"hasAttachment"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(allMailStmt, 6);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"body"];
		
		int folderNum = sqlite3_column_int(allMailStmt, 7);
		NSNumber *folderNumValue = [NSNumber numberWithInt:folderNum];
		[res setObject:folderNumValue forKey: @"folderNum"];
		
		[res setObject:[NSNumber numberWithInt:dbNum] forKey:@"dbNum"];
		
		[resArray addObject:res];
		
		if(self.cancelled) { [res release]; break; }
		
		if(count <= 4 || (count % 25 == 0)) {
			if([delegate respondsToSelector:@selector(deliverSearchResults:)]) {
				[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
			}
			resArray = [[NSMutableArray alloc] initWithCapacity:100];
		}
		
		[res release];
	}
	
	[dateFormatter release];
	
	if(!self.cancelled) { 
		if([resArray count] > 0 && [delegate respondsToSelector:@selector(deliverSearchResults:)]) {
			[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
		} else {
			[resArray release];
		}
	}
	
	sqlite3_finalize(allMailStmt);	
	return count;
}	

- (void)performAllMailAsync:(NSDictionary *)queryDict {
	// calls to this function are enqueued by search above on an operationsQueue
	id delegate = [queryDict objectForKey:@"delegate"];
	int dbIndex = [[queryDict objectForKey:@"dbIndex"] intValue];
	
	NSArray* dbNumbers = [GlobalDBFunctions emailDBNumbers];
	int totalFound = 0;
	
	while(dbIndex < [dbNumbers count] && totalFound < MIN_TO_FIND) {
		
		// update: searching through DB with dbNum
		if([delegate respondsToSelector:@selector(deliverProgressUpdate:)]) {
			[delegate performSelector:@selector(deliverProgressUpdate:) withObject:[NSNumber numberWithInt:dbIndex]];
		}
		
		int dbNum = [[dbNumbers objectAtIndex:dbIndex] intValue];
		
		[self switchToDB:[GlobalDBFunctions dbFileNameForNum:dbNum]];
		
		int count = [self performAllMailWithDelegate:delegate withDbNum:dbNum];
		totalFound += count;	
		dbIndex++;
		
		if(self.cancelled) { break; }
	}
	
	[[SearchEmailDBAccessor sharedManager] close];
	
	NSNumber* additionalResults = [NSNumber numberWithBool:(dbIndex < [dbNumbers count])];
	if([delegate respondsToSelector:@selector(deliverAdditionalResults:)]) {
		[delegate performSelector:@selector(deliverAdditionalResults:) withObject:additionalResults];
	}
}

- (void)allMailWithDelegate:(id)delegate startWithDB:(int)dbIndex {
	
	NSLog(@"allMail started with dbNum = %i", dbIndex);
	
	self.cancelled = NO;
	
	//Create the queryOp object
	NSMutableDictionary *queryOp = [[[NSMutableDictionary alloc] init] autorelease];
	[queryOp setObject:[NSNumber numberWithInt:dbIndex] forKey:@"dbIndex"];
	[queryOp setObject:delegate forKey:@"delegate"];
	
	//Invoke search
	NSInvocationOperation* searchOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performAllMailAsync:) object:queryOp];
	assert(searchOp != nil);
	[self.operationQueue addOperation:searchOp]; 
	[searchOp release];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Folder "Search"
#pragma mark Folder "Search"

- (int)performFolderSearch:(int)folderNum withDelegate:(id)delegate withDbNum:(int)dbNum {
	
	sqlite3_stmt *folderSearchStmt = nil;
	NSString *queryString = @"SELECT email.pk, email.sender_name, email.sender_address, search_email.subject, email.datetime, "
	"LENGTH(email.attachments), SUBSTR(search_email.body,0,150), email.folder_num FROM "
	"email, search_email "
	"WHERE (email.folder_num = ? OR email.folder_num_1 = ? OR email.folder_num_2 = ? OR email.folder_num_3 = ?) AND email.pk = search_email.docid "
	"ORDER BY email.datetime DESC;";
	
	BOOL newSchema = YES;
	int dbrc = sqlite3_prepare_v2([[SearchEmailDBAccessor sharedManager] database], [queryString UTF8String], -1, &folderSearchStmt, nil);	
	if (dbrc != SQLITE_OK) {
		// uses the old schema
		newSchema = NO;
		
		queryString = @"SELECT email.pk, email.sender_name, email.sender_address, search_email.subject, email.datetime, "
		"LENGTH(email.attachments), SUBSTR(search_email.body,0,150), email.folder_num FROM "
		"email, search_email "
		"WHERE email.pk = search_email.docid AND email.folder_num = ?"
		"ORDER BY email.datetime DESC;";
		
		dbrc = sqlite3_prepare_v2([[SearchEmailDBAccessor sharedManager] database], [queryString UTF8String], -1, &folderSearchStmt, nil);	
	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed preparing allMailStmt with error %s", sqlite3_errmsg([[SearchEmailDBAccessor sharedManager] database]));
			return 0;
		}	
	}
	
	sqlite3_bind_int(folderSearchStmt, 1, folderNum);
	if(newSchema) {
		// bind the same value to all folders
		sqlite3_bind_int(folderSearchStmt, 2, folderNum);
		sqlite3_bind_int(folderSearchStmt, 3, folderNum);
		sqlite3_bind_int(folderSearchStmt, 4, folderNum);		
	}
	
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init]; 
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	int count = 0;
	NSMutableArray* resArray = [[NSMutableArray alloc] initWithCapacity:100]; // released in the receiver
	
	while(sqlite3_step(folderSearchStmt) == SQLITE_ROW) {
		count++;
		
		NSMutableDictionary *res= [[NSMutableDictionary alloc] init];
		
		int pk = sqlite3_column_int(folderSearchStmt, 0);
		NSNumber *primaryKeyValue = [NSNumber numberWithInt:pk];					
		[res setObject:primaryKeyValue forKey: @"pk"];
		
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(folderSearchStmt, 1);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderName"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(folderSearchStmt, 2);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderAddress"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(folderSearchStmt, 3);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"subject"];			
		
		NSDate *date = [NSDate date];
		sqlVal = (const char *)sqlite3_column_text(folderSearchStmt, 4);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [DateUtil datetimeInLocal:[dateFormatter dateFromString:dateString]];
		}
		[res setObject:date forKey:@"datetime"];
		
		int hasAttachmentInt = sqlite3_column_int(folderSearchStmt, 5) - 2; // will be non-0 if there are attachments, the -2 are to counter the string "[]"
		NSNumber *hasAttachment = [NSNumber numberWithInt:hasAttachmentInt];
		[res setObject:hasAttachment forKey: @"hasAttachment"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(folderSearchStmt, 6);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"body"];
		
		int folderNum = sqlite3_column_int(folderSearchStmt, 7);
		NSNumber *folderNumValue = [NSNumber numberWithInt:folderNum];
		[res setObject:folderNumValue forKey: @"folderNum"];
		
		[res setObject:[NSNumber numberWithInt:dbNum] forKey:@"dbNum"];
		
		[resArray addObject:res];
		
		if(self.cancelled) { [res release]; break; }
		
		if(count <= 4 || (count % 25 == 0)) {
			if([delegate respondsToSelector:@selector(deliverSearchResults:)]) {
				[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
			}
			resArray = [[NSMutableArray alloc] initWithCapacity:100];
		}
		
		[res release];
	}
	
	[dateFormatter release];
	
	if(!self.cancelled) { 
		if([resArray count] > 0 && [delegate respondsToSelector:@selector(deliverSearchResults:)]) {
			[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
		} else {
			[resArray release];
		}
	}
	
	sqlite3_finalize(folderSearchStmt);	
	return count;
}	

- (void)performFolderSearchAsync:(NSDictionary *)queryDict {
	// calls to this function are enqueued by search above on an operationsQueue
	id delegate = [queryDict objectForKey:@"delegate"];
	int dbIndex = [[queryDict objectForKey:@"dbIndex"] intValue];
	int folderNum = [[queryDict objectForKey:@"folderNum"] intValue]; 
	int maxDbFile = [[queryDict objectForKey:@"maxDbFile"] intValue]; 
	
	NSArray* dbNumbers = [GlobalDBFunctions emailDBNumbers];
	int totalFound = 0;
	
	// scroll forward to the max file
	int dbIndexScrolled = 0;
	if(dbIndex != 0) {
		dbIndexScrolled = dbIndex;
	} else {
		if(maxDbFile != -1) {
			while(dbIndexScrolled < [dbNumbers count]) {
				int dbNum = [[dbNumbers objectAtIndex:dbIndexScrolled] intValue];
				if(dbNum == maxDbFile) {
					break;
				}
				dbIndexScrolled++;
			}
		}
	}
	
	while(dbIndexScrolled < [dbNumbers count] && totalFound < MIN_TO_FIND) {
		
		// update: searching through DB with dbNum
		if([delegate respondsToSelector:@selector(deliverProgressUpdate:)]) {
			[delegate performSelector:@selector(deliverProgressUpdate:) withObject:[NSNumber numberWithInt:dbIndexScrolled]];
		}
		
		int dbNum = [[dbNumbers objectAtIndex:dbIndexScrolled] intValue];
		
		[self switchToDB:[GlobalDBFunctions dbFileNameForNum:dbNum]];
		
		int count = [self performFolderSearch:folderNum withDelegate:delegate withDbNum:dbNum];
		totalFound += count;	
		dbIndexScrolled++;
		
		if(self.cancelled) { break; }
	}
	
	[[SearchEmailDBAccessor sharedManager] close];
	
	NSNumber* additionalResults = [NSNumber numberWithBool:(dbIndexScrolled < [dbNumbers count])];
	if([delegate respondsToSelector:@selector(deliverAdditionalResults:)]) {
		[delegate performSelector:@selector(deliverAdditionalResults:) withObject:additionalResults];
	}
}

- (void)folderSearch:(int)folderNum withDelegate:(id)delegate startWithDB:(int)dbIndex {
	
	NSLog(@"folderSearch started with dbNum = %i", dbIndex);
	
	int accountNum = [EmailProcessor accountNumForCombinedFolderNum:folderNum];
	int uFolderNum = [EmailProcessor folderNumForCombinedFolderNum:folderNum];
	
	SyncManager* sm = [SyncManager getSingleton];
	NSDictionary* folderState = [sm retrieveState:uFolderNum accountNum:accountNum];
	NSArray* nums = [folderState objectForKey:@"dbNums"];
	
	int maxDbFile = -1;
	for(int i = 0; i < [nums count]; i++) {
		int fileNum = [[nums objectAtIndex:i] intValue];
		if(fileNum > maxDbFile) {
			maxDbFile = fileNum;
		}
	}
	
	self.cancelled = NO;
	
	//Create the queryOp object
	NSMutableDictionary *queryOp = [[[NSMutableDictionary alloc] init] autorelease];
	[queryOp setObject:[NSNumber numberWithInt:dbIndex] forKey:@"dbIndex"];
	[queryOp setObject:[NSNumber numberWithInt:folderNum] forKey:@"folderNum"];
	[queryOp setObject:delegate forKey:@"delegate"];
	[queryOp setObject:[NSNumber numberWithInt:maxDbFile] forKey:@"maxDbFile"];
	
	//Invoke search
	NSInvocationOperation* searchOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performFolderSearchAsync:) object:queryOp];
	assert(searchOp != nil);
	[self.operationQueue addOperation:searchOp]; 
	[searchOp release];
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sender Search
#pragma mark Sender Search


-(int)performSenderSearch:(NSString*)addressesString withDelegate:(id)delegate withDbNum:(int)dbNum {
	
	sqlite3_stmt *senderSearchStmt = nil;
	
	NSString *queryString = [NSString stringWithFormat:@"SELECT email.pk, email.sender_name, email.sender_address, search_email.subject, email.datetime, "
		"LENGTH(email.attachments), SUBSTR(search_email.body,0,150), folder_num FROM "
		"email, search_email "
		"WHERE email.pk = search_email.docid AND email.sender_address IN (%@)"
		"ORDER BY email.datetime DESC;", addressesString];
	
	int dbrc = sqlite3_prepare_v2([[SearchEmailDBAccessor sharedManager] database], [queryString UTF8String], -1, &senderSearchStmt, nil);	
	if (dbrc != SQLITE_OK) {
		NSLog(@"Failed preparing ftSearchStmt %@ with error %s", queryString, sqlite3_errmsg([[SearchEmailDBAccessor sharedManager] database]));
		return 0;
	}

	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss.SSSS"];
	
	int count = 0;
	NSMutableArray* resArray = [[NSMutableArray alloc] initWithCapacity:100]; // released in the receiver
	while(sqlite3_step(senderSearchStmt) == SQLITE_ROW) {
		count++;
		
		NSMutableDictionary *res= [[NSMutableDictionary alloc] init];
		
		int pk = sqlite3_column_int(senderSearchStmt, 0);
		NSNumber *primaryKeyValue = [NSNumber numberWithInt:pk];					
		[res setObject:primaryKeyValue forKey: @"pk"];
		
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(senderSearchStmt, 1);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderName"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(senderSearchStmt, 2);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"senderAddress"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(senderSearchStmt, 3);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"subject"];			
		
		NSDate *date = [NSDate date];
		sqlVal = (const char *)sqlite3_column_text(senderSearchStmt, 4);
		if(sqlVal != nil) {
			NSString *dateString = [NSString stringWithUTF8String:sqlVal];
			date = [DateUtil datetimeInLocal:[dateFormatter dateFromString:dateString]];
		}
		[res setObject:date forKey:@"datetime"];
		
		int hasAttachmentInt = sqlite3_column_int(senderSearchStmt, 5) - 2; // will be non-0 if there are attachments, the -2 are to counter the string "[]"
		NSNumber *hasAttachment = [NSNumber numberWithInt:hasAttachmentInt];
		[res setObject:hasAttachment forKey: @"hasAttachment"];
		
		temp = @"";
		sqlVal = (const char *)sqlite3_column_text(senderSearchStmt, 6);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"body"];			
		
		int folderNum = sqlite3_column_int(senderSearchStmt, 7);
		NSNumber *folderNumValue = [NSNumber numberWithInt:folderNum];
		[res setObject:folderNumValue forKey: @"folderNum"];
		
		[res setObject:[NSNumber numberWithInt:dbNum] forKey:@"dbNum"];
		
		[resArray addObject:res];
		
		if(self.cancelled) { [res release]; break; }
		
		if(count <= 4 || (count % 25 == 0)) {
			if([delegate respondsToSelector:@selector(deliverSearchResults:)]) {
				[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
			}
			resArray = [[NSMutableArray alloc] initWithCapacity:100];
		}
		
		[res release];
	}
	
	[dateFormatter release];
	
	if(!self.cancelled) { 	
		if([resArray count] > 0 && [delegate respondsToSelector:@selector(deliverSearchResults:)]) {
			[delegate performSelector:@selector(deliverSearchResults:) withObject:resArray];
		} else {
			[resArray release];
		}
	}
	
	sqlite3_finalize(senderSearchStmt);	
	senderSearchStmt = nil;
	
	return count;
}

-(void)performSenderSearchAsync:(NSDictionary *)queryDict {
	NSString *addresses = [queryDict objectForKey:@"addresses"];
	id delegate = [queryDict objectForKey:@"delegate"];
	int dbIndex = [[queryDict objectForKey:@"dbIndex"] intValue];
	int dbMin = [[queryDict objectForKey:@"dbMin"] intValue];
	int dbMax = [[queryDict objectForKey:@"dbMax"] intValue];
	
	
	NSArray* dbNumbers = [GlobalDBFunctions emailDBNumbers];
	int totalFound = 0;
	
	while(dbIndex < [dbNumbers count] && totalFound < MIN_TO_FIND) {
		
		// update: searching through DB with dbNum
		if([delegate respondsToSelector:@selector(deliverProgressUpdate:)]) {
			[delegate performSelector:@selector(deliverProgressUpdate:) withObject:[NSNumber numberWithInt:dbIndex]];
		}
		
		int dbNum = [[dbNumbers objectAtIndex:dbIndex] intValue];
		
		if(dbMax != 0 && (dbNum > dbMax || dbNum < dbMin)) {
			// prune away searching in this db if we have a dbMin / dbMax
			if(self.cancelled) { break; }
			
			dbIndex++;
			continue;
		}
		
		[self switchToDB:[GlobalDBFunctions dbFileNameForNum:dbNum]];
		
		int count = [self performSenderSearch:addresses withDelegate:delegate withDbNum:dbNum];
		totalFound += count;	
		dbIndex++;
		
		if(self.cancelled) { break; }
	}
	
	[[SearchEmailDBAccessor sharedManager] close];
	
	NSNumber* additionalResults = [NSNumber numberWithBool:(dbIndex < [dbNumbers count])];
	if([delegate respondsToSelector:@selector(deliverAdditionalResults:)]) {
		[delegate performSelector:@selector(deliverAdditionalResults:) withObject:additionalResults];
	}
}

-(void)senderSearch:(NSString*)addressess withDelegate:(id)delegate startWithDB:(int)dbIndex dbMin:(int)dbMin dbMax:(int)dbMax {	
	NSLog(@"senderSearch with limit = %i", dbIndex);
	
	self.cancelled = NO;
	
	//Create the queryOp object
	NSMutableDictionary *queryOp = [[[NSMutableDictionary alloc] init] autorelease];
	[queryOp setObject:addressess forKey:@"addresses"];
	[queryOp setObject:delegate forKey:@"delegate"];
	[queryOp setObject:[NSNumber numberWithInt:dbIndex] forKey:@"dbIndex"];
	[queryOp setObject:[NSNumber numberWithInt:dbMin] forKey:@"dbMin"];
	[queryOp setObject:[NSNumber numberWithInt:dbMax] forKey:@"dbMax"];
	
	//Invoke search
	NSInvocationOperation* searchOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performSenderSearchAsync:) object:queryOp];
	[self.operationQueue addOperation:searchOp]; 
	[searchOp release];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// autocompletion
#pragma mark Autocompletion

- (void)performAutocomplete:(NSString *)query withDelegate:(id)delegate {
	
	if(autocompleteStmt == nil)	{
		NSString *queryString = @"SELECT s.name, c.email_addresses, c.dbnum_first, c.dbnum_last FROM search_contact_name s, contact_name c WHERE s.docid = c.pk AND search_contact_name MATCH ? ORDER BY c.occurrences DESC LIMIT 20";
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [queryString UTF8String], -1, &autocompleteStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed preparing autocompleteStmt with error %s", sqlite3_errmsg([[ContactDBAccessor sharedManager] database]));
			return;
		}
	}

	sqlite3_bind_text(autocompleteStmt, 1, [query UTF8String], -1, SQLITE_TRANSIENT);	

	NSMutableArray* y = [NSMutableArray arrayWithCapacity:20];
	int count = 0;
	while(sqlite3_step(autocompleteStmt) == SQLITE_ROW && count < 20) {
		NSString *name = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(autocompleteStmt, 0);
		if(sqlVal != nil)
			name = [NSString stringWithUTF8String:sqlVal];

		NSString *emailAddresses = @"";
		sqlVal = (const char *)sqlite3_column_text(autocompleteStmt, 1);
		if(sqlVal != nil)
			emailAddresses = [NSString stringWithUTF8String:sqlVal];
		
		int dbMin = (int)sqlite3_column_int(autocompleteStmt, 2);
		int dbMax = (int)sqlite3_column_int(autocompleteStmt, 3);
		
		//int occurrences = sqlite3_column_int(autocompleteStmt, 2);
		
		NSDictionary* res = [NSDictionary dictionaryWithObjectsAndKeys:name, @"name", emailAddresses, @"emailAddresses", [NSNumber numberWithInt:dbMin], @"dbMin", [NSNumber numberWithInt:dbMax], @"dbMax", nil];
		
		[y addObject:res];
		count++;
	}

	if([delegate respondsToSelector:@selector(deliverAutocompleteResult:)])	{
		[delegate performSelector:@selector(deliverAutocompleteResult:) withObject:y];
	}
	
	sqlite3_reset(autocompleteStmt);
}


- (void)performAutocompleteAsync:(NSDictionary*)query {
	// the purpose of this method is to make performAutocomplete asynchronous
	@synchronized(self.autocompleteLock) {
		[self performAutocomplete:[query objectForKey:@"query"] withDelegate:[query objectForKey:@"delegate"]];
	}
}

- (void)autocomplete:(NSString *)query withDelegate:(id)autocompleteDelegate {
	//Create the queryOp object
	NSMutableDictionary *params = [[[NSMutableDictionary alloc] init] autorelease];
	[params setObject:query forKey:@"query"];
	[params setObject:autocompleteDelegate forKey:@"delegate"];
	
	//Invoke local search
	NSInvocationOperation* autompleteOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(performAutocompleteAsync:) object:params];
	[self.operationQueue addOperation:autompleteOp];
	[autompleteOp release];
}

#pragma mark Utility functions
-(NSDictionary*)findContact:(NSString*)name {
	// find a contact given name
	if(contactNameFindStmt == nil) {
		NSString* querySQL = [NSMutableString stringWithFormat:@"SELECT pk, name, email_addresses, occurrences, dbnum_first, dbnum_last FROM contact_name WHERE name = ?;", name];
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [querySQL UTF8String], -1, &contactNameFindStmt, nil);	
		if (dbrc != SQLITE_OK) {
			return nil;
		}
	}
	
	sqlite3_bind_text(contactNameFindStmt, 1, [name UTF8String], -1, SQLITE_TRANSIENT);	
	
	NSMutableDictionary *res = nil;
	
	//Exec query - 
	if(sqlite3_step(contactNameFindStmt) == SQLITE_ROW) {
		res = [[[NSMutableDictionary alloc] init] autorelease];
		
		int pk = sqlite3_column_int(contactNameFindStmt, 0);
		NSNumber *primaryKeyValue = [NSNumber numberWithInt:pk];					
		[res setObject:primaryKeyValue forKey:@"pk"];
		
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(contactNameFindStmt, 1);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"name"];
		
		sqlVal = (const char *)sqlite3_column_text(contactNameFindStmt, 2);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"emailAddresses"];
		
		int occ = sqlite3_column_int(contactNameFindStmt, 3);
		NSNumber *occurrences = [NSNumber numberWithInt:occ];					
		[res setObject:occurrences forKey: @"occurrences"];

		int dbMin = sqlite3_column_int(contactNameFindStmt, 4);
		NSNumber *dbMinO = [NSNumber numberWithInt:dbMin];					
		[res setObject:dbMinO forKey:@"dbMin"];

		int dbMax = sqlite3_column_int(contactNameFindStmt, 5);
		NSNumber *dbMaxO = [NSNumber numberWithInt:dbMax];					
		[res setObject:dbMaxO forKey:@"dbMax"];
	}
	
	sqlite3_reset(contactNameFindStmt);
	
	return res;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Loading email

-(void)switchLoadEmailToDB:(NSString*)fileName {
	[[LoadEmailDBAccessor sharedManager] close];
	[[LoadEmailDBAccessor sharedManager] setDatabaseFilepath:[StringUtil filePathInDocumentsDirectoryForFileName:fileName]];
}

-(void)deleteEmail:(int)pk dbNum:(int)dbNum {	
	// switch to the right db
	NSString* fileName = [GlobalDBFunctions dbFileNameForNum:dbNum];
	[self switchLoadEmailToDB:fileName];
	
	[Email deleteWithPk:pk];
	
	return;
}

-(Email*)loadEmail:(int)pk dbNum:(int)dbNum {
	Email* email = [[[Email alloc] init] autorelease];
	
	// switch to the right db
	NSString* fileName = [GlobalDBFunctions dbFileNameForNum:dbNum];
	[self switchLoadEmailToDB:fileName];
	
	[email loadData:pk];
	
	return email;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Cancelling searches (can't have multiple searches running in parallel)

-(void)cancel {
	self.cancelled = YES;
}
@end
