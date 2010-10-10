//
//  EmailProcessor.m
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

#import <CommonCrypto/CommonDigest.h>
#import "EmailProcessor.h"
#import "SyncManager.h"
#import "SearchRunner.h"
#import "EmailProcessor.h"
#import "CTCoreAddress.h"
#import "CTBareAttachment.h"
#import "StringUtil.h"
#import "sqlite3.h"
#import "ContactDBAccessor.h"
#import "AddEmailDBAccessor.h"
#import "GlobalDBFunctions.h"
#import "UidDBAccessor.h"
#import "Email.h"
#import "NSObject+SBJSON.h"
#import "AppSettings.h"

#define SECONDS_PER_DAY 86400.0 //24*3600
#define FOLDER_COUNT_LIMIT 1000 // maximum number of folders allowed
#define EMAIL_DB_COUNT_LIMIT 500
#define ADDS_PER_TRANSACTION 20
#define BODY_LENGTH_LIMIT 30000

static sqlite3_stmt *contactNameInsertStmt = nil;
static sqlite3_stmt *contactNameUpdateStmt = nil;
static sqlite3_stmt *searchContactNameInsertStmt = nil;
static sqlite3_stmt *emailStmt = nil;
static sqlite3_stmt *emailCountStmt = nil;
static sqlite3_stmt *searchEmailInsertStmt = nil;
static sqlite3_stmt *uidInsertStmt = nil;
static sqlite3_stmt *uidSearchStmt = nil;
static sqlite3_stmt *uidFindStmt = nil;

static sqlite3_stmt *folderUpdateReadStmt = nil;
static sqlite3_stmt *folderUpdateWriteStmt = nil;

static EmailProcessor *singleton = nil;

@implementation EmailProcessor

static NSDictionary* SENDERS_FALSE_NAMES = nil;

@synthesize dbDateFormatter;
@synthesize operationQueue;
@synthesize shuttingDown;
@synthesize updateSubscriber;

BOOL firstOne = YES; // caused effect: Don't endTransaction when we're just starting
BOOL transactionOpen = NO; // caused effect (with firstOne): After we start up, don't wrap the first ADDS_PER_TRANSACTION calls into a transaction

- (void) dealloc {
	[operationQueue release];
	[dbDateFormatter release];
	[updateSubscriber release];
	
	[super dealloc];
}

+(void)clearPreparedStmts {
	// for rollover
	if(uidInsertStmt) {
		sqlite3_finalize(uidInsertStmt);
		uidInsertStmt = nil;
	}
	if(contactNameInsertStmt) {
		sqlite3_finalize(contactNameInsertStmt);
		contactNameInsertStmt = nil;
	}
	if(contactNameUpdateStmt) {
		sqlite3_finalize(contactNameUpdateStmt);
		contactNameUpdateStmt = nil;
	}
	if(emailStmt) {
		sqlite3_finalize(emailStmt);
		emailStmt = nil;
	}
	if(searchEmailInsertStmt) {
		sqlite3_finalize(searchEmailInsertStmt);
		searchEmailInsertStmt = nil;
	}
	if(searchContactNameInsertStmt) {
		sqlite3_finalize(searchContactNameInsertStmt);
		searchContactNameInsertStmt = nil;
	}
	if(emailCountStmt) {
		sqlite3_finalize(emailCountStmt);
		emailCountStmt = nil;
	}
	
	if(uidFindStmt) {
		sqlite3_finalize(uidFindStmt);
		uidFindStmt = nil;
	}
	
	if(folderUpdateReadStmt) {
		sqlite3_finalize(folderUpdateReadStmt);
		folderUpdateReadStmt = nil;
	}
	
	if(folderUpdateWriteStmt) {
		sqlite3_finalize(folderUpdateWriteStmt);
		folderUpdateWriteStmt = nil;
	}
}

+(void)finalClearPreparedStmts {
	// for rollover
	if(uidInsertStmt) {
		sqlite3_finalize(uidInsertStmt);
		uidInsertStmt = nil;
	}
	if(contactNameInsertStmt) {
		sqlite3_finalize(contactNameInsertStmt);
		contactNameInsertStmt = nil;
	}
	if(contactNameUpdateStmt) {
		sqlite3_finalize(contactNameUpdateStmt);
		contactNameUpdateStmt = nil;
	}
	if(searchContactNameInsertStmt) {
		sqlite3_finalize(searchContactNameInsertStmt);
		searchContactNameInsertStmt = nil;
	}
	if(uidFindStmt) {
		sqlite3_finalize(uidFindStmt);
		uidFindStmt = nil;
	}
}

+ (id)getSingleton { //NOTE: don't get an instance of SyncManager until account settings are set!
	@synchronized(self) {
		if (singleton == nil) {
			singleton = [[self alloc] init];
		}
	}
	return singleton;
}

-(id)init {
	self = [super init];
	
	if(self) {
		self.shuttingDown = NO;
		
		// Dict of email senders who tend to include the wrong sender name
		// with email they send (for example, Paypal might send an email
		// with senderName == "Gabor Cselle", senderAddress == "service@paypal.com".
		// When we get an email with senderAddress == "service@paypal.com", we set set senderName to "Paypal"
		if(SENDERS_FALSE_NAMES == nil) {
			SENDERS_FALSE_NAMES = [[NSDictionary alloc] initWithObjectsAndKeys:
								@"Twitter", @"noreply@twitter.com",
								@"Evite", @"info@evite.com",
								@"WebEx", @"messenger@webex.com",
								@"LinkedIn", @"invitations@linkedin.com",
								@"Paypal", @"service@paypal.com",
								@"Paypal", @"service@paypal.de",
								@"Paypal", @"service@paypal.ch",
								@"Paypal", @"service@paypal.at",
								@"Paypal", @"paypal@email.paypal.ch", 
								@"Evite", @"info@mail.evite.com", 
								@"Blogger Comments", @"noreply-comment@blogger.com",
								@"Yahoo Profiles", @"profiles@yahoo-inc.com",
								@"Eventbrite", @"invite@eventbrite.com", nil];
		}
		
		NSOperationQueue *ops = [[[NSOperationQueue alloc] init] autorelease];
		[ops setMaxConcurrentOperationCount:1]; // note that this makes it a simple, single queue
		self.operationQueue = ops;
		
		NSDateFormatter* df = [[NSDateFormatter alloc] init];
		[df setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
		self.dbDateFormatter = df;
		[df release];
		
		currentDBNum = -1;
		addsSinceTransaction = 0;
		transactionOpen = NO;
	}
	
	return self;
}


-(BOOL)shouldRolloverAddEmailDB {
	if(emailCountStmt == nil) {
		NSString* querySQL = @"SELECT count(datetime) FROM email;";
		int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [querySQL UTF8String], -1, &emailCountStmt, nil);	
		if (dbrc != SQLITE_OK) {
			return NO;
		}
	}
	
	//Exec query 
	int count = 0;
	if(sqlite3_step(emailCountStmt) == SQLITE_ROW) {
		count = sqlite3_column_int(emailCountStmt, 0);
	}
	
	sqlite3_reset(emailCountStmt);
	
	return (count >= EMAIL_DB_COUNT_LIMIT);
}

#pragma mark AddEmailDB Management stuff
-(void)rolloverAddEmailDBTo:(int)dbNum {
	// rolls over AddEmailDB, starts a new email-X file if needed
	[EmailProcessor clearPreparedStmts];
	
	[[AddEmailDBAccessor sharedManager] close];
	
	// create new, empty db file
	NSString* fileName = [GlobalDBFunctions dbFileNameForNum:dbNum];
	NSString *dbPath = [StringUtil filePathInDocumentsDirectoryForFileName:fileName];			
	if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
		[[NSFileManager defaultManager] createFileAtPath:dbPath contents:nil attributes:nil];
	}
	
	[[AddEmailDBAccessor sharedManager] setDatabaseFilepath:[StringUtil filePathInDocumentsDirectoryForFileName:fileName]];	
	[Email tableCheck];
}

-(void)endNewSync:(int)endSeq folderNum:(int)folderNum accountNum:(int)accountNum {
	[self endTransactions];
	
	SyncManager *sm = [SyncManager getSingleton];
	NSMutableDictionary* syncState = [sm retrieveState:folderNum accountNum:accountNum];
	[syncState setObject:[NSNumber numberWithUnsignedInt:endSeq] forKey:@"newSyncStart"];
	[sm persistState:syncState forFolderNum:folderNum accountNum:accountNum];

	[self beginTransactions];
}

-(void)endOldSync:(int)startSeq folderNum:(int)folderNum accountNum:(int)accountNum {
	[self endTransactions];
	
	SyncManager *sm = [SyncManager getSingleton];
	NSMutableDictionary* syncState = [sm retrieveState:folderNum accountNum:accountNum];
	[syncState setObject:[NSNumber numberWithUnsignedInt:startSeq] forKey:@"oldSyncStart"];
	[sm persistState:syncState forFolderNum:folderNum accountNum:accountNum];
	
	[self beginTransactions];
}


#pragma mark Execute DB changes
-(NSDictionary*)recipientList:(NSSet*)set {
	if (set == nil || [set count] == 0) {
		return [NSDictionary dictionaryWithObjectsAndKeys:@"", @"json", @"", @"flat", nil];
	}
	
	NSEnumerator* enumerator = [set objectEnumerator];
	CTCoreAddress* a;
	NSMutableArray* jsonList = [NSMutableArray arrayWithCapacity:10];
	NSMutableString* flat = [NSMutableString string];
	
	while (a = [enumerator nextObject]) {
		if([jsonList count] > 10) { // length limit
			break;
		}
		
		NSString* email = a.email;
		NSString* name = a.decodedName;
		NSDictionary* dict;
		
		if((email != nil && [email length] > 0) || (name != nil && [name length] > 0)) {
			dict = [NSDictionary dictionaryWithObjectsAndKeys:email, @"e", name, @"n", nil];
			[jsonList addObject:dict];
			[flat appendFormat:@" %@ %@", name, email];
		}
	}
	
	NSString* json = [jsonList JSONRepresentation];
	NSString* flatString = [StringUtil trim:flat];
	return [NSDictionary dictionaryWithObjectsAndKeys:json, @"json", flatString, @"flat", nil];
}

-(NSDictionary*)attachmentList:(NSArray*)set {
	if (set == nil || [set count] == 0) {
		return [NSDictionary dictionaryWithObjectsAndKeys:@"", @"json", @"", @"flat", nil];
	}
	
	NSEnumerator* enumerator = [set objectEnumerator];
	CTBareAttachment* a;
	NSMutableArray* jsonList = [NSMutableArray arrayWithCapacity:10];
	NSMutableString* flat = [NSMutableString string];
	
	while (a = [enumerator nextObject]) {
		if([jsonList count] > 10) { // length limit
			break;
		}
		
		NSString* filename = a.decodedFilename;
		NSString* contentType = a.contentType;
		
		if(filename != nil && [filename length] > 0) {
			[jsonList addObject:[NSDictionary dictionaryWithObjectsAndKeys:filename, @"n", contentType, @"t", nil]];
			[flat appendFormat:@" %@", filename];
		}
	}
	
	NSString* json = [jsonList JSONRepresentation];
	NSString* flatString = [StringUtil trim:flat];
	return [NSDictionary dictionaryWithObjectsAndKeys:json, @"json", flatString, @"flat", nil];
}

+(int)folderCountLimit {
	return FOLDER_COUNT_LIMIT;
}

+(int)dbNumForDate:(NSDate*)date {
	double timeSince1970 = [date timeIntervalSince1970];
	
	int dbNum = (int)(floor(timeSince1970/SECONDS_PER_DAY/3.0))*100; // The *100 is to avoid overlap with date files from the past
	
	dbNum = MAX(0, dbNum);
	
	return dbNum;
}

-(void)beginTransactions {
	if(![AddEmailDBAccessor beginTransaction]) {
		if(![AddEmailDBAccessor beginTransaction]) {
			NSLog(@"Warning: Begin T was not successful");
		}
	}
	
	if(![UidDBAccessor beginTransaction]) {
		[UidDBAccessor beginTransaction];
	}
	
	transactionOpen = YES;
}

-(void)endTransactions {
	if(transactionOpen) {
		if(![AddEmailDBAccessor endTransaction]) {
			if(![AddEmailDBAccessor endTransaction]) {
				NSLog(@"Warning: End T was not successful");
			}
		}
		if(![UidDBAccessor endTransaction]) {
			[UidDBAccessor endTransaction];
		}
	}
	
	transactionOpen = NO;	   
}

// the folder num that's in the db combines the account num with the folder num (this was easier than changing the schema)
+(int)combinedFolderNumFor:(int)folderNumInAccount withAccount:(int)accountNum {
	return accountNum * FOLDER_COUNT_LIMIT + folderNumInAccount;
}

+(int)folderNumForCombinedFolderNum:(int)folderNum {
	return folderNum % FOLDER_COUNT_LIMIT;
}

+(int)accountNumForCombinedFolderNum:(int)folderNum {
	return folderNum / FOLDER_COUNT_LIMIT;
}

-(void)switchToDBNum:(int)dbNum {
	if(self.shuttingDown) return;
	
	if(currentDBNum != dbNum) {
		// need to switch between DBs
		if(!firstOne) {
			// don't open a transaction for the first one
			[self endTransactions];
		}
		//NSLog(@"Switching to edb: %i", dbNum);
		[self rolloverAddEmailDBTo:dbNum];
		if(!firstOne) {
			[self beginTransactions];
		}
		
		addsSinceTransaction = 0;
		currentDBNum = dbNum;
		firstOne = NO;
	} else {
		// have we exceeded the number of adds between transactions?
		addsSinceTransaction += 1;
		BOOL nextTransaction = (addsSinceTransaction >= ADDS_PER_TRANSACTION);
		if(nextTransaction) {
			addsSinceTransaction = 0;
		}
		
		// switching between transactions
		if(nextTransaction) {
			[self endTransactions];
			firstOne = NO;
			[self beginTransactions];
		}
	}
}

-(void)addToFolder:(int)newFolderNum emailWithDatetime:(NSString*)datetime uid:(NSString*)uid oldFolderNum:(int)oldFolderNum {
	// read out folder0-4 for this email
	if(folderUpdateReadStmt == nil) {
		NSString *readEmail = @"SELECT pk, folder_num, folder_num_1, folder_num_2, folder_num_3 FROM email WHERE uid = ? AND folder_num = ? LIMIT 1";
		int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [readEmail UTF8String], -1, &folderUpdateReadStmt, nil);	
		if (dbrc != SQLITE_OK) {
			return;
		}
	}
	
	sqlite3_bind_text(folderUpdateReadStmt, 1, [uid UTF8String], -1, SQLITE_TRANSIENT);		
	sqlite3_bind_int(folderUpdateReadStmt, 2, oldFolderNum);	

	int pk = 0;
	int folder_num_0 = 0;
	int folder_num_1 = 0;
	int folder_num_2 = 0;
	int folder_num_3 = 0;
	
	if (sqlite3_step(folderUpdateReadStmt) == SQLITE_ROW) {
		pk = sqlite3_column_int(folderUpdateReadStmt, 0);
		folder_num_0 =sqlite3_column_type(folderUpdateReadStmt, 1) == SQLITE_NULL ? -1 : sqlite3_column_int(folderUpdateReadStmt, 1);
		folder_num_1 =sqlite3_column_type(folderUpdateReadStmt, 2) == SQLITE_NULL ? -1 : sqlite3_column_int(folderUpdateReadStmt, 2);
		folder_num_2 =sqlite3_column_type(folderUpdateReadStmt, 3) == SQLITE_NULL ? -1 : sqlite3_column_int(folderUpdateReadStmt, 3);
		folder_num_3 =sqlite3_column_type(folderUpdateReadStmt, 4) == SQLITE_NULL ? -1 : sqlite3_column_int(folderUpdateReadStmt, 4);
	} else {
		sqlite3_reset(folderUpdateReadStmt);
		return;
	}
	
	sqlite3_reset(folderUpdateReadStmt);
	
	// is this folder already set?
	if((folder_num_0 == newFolderNum) || (folder_num_1 == newFolderNum) || (folder_num_2 == newFolderNum) || (folder_num_3 == newFolderNum)) {
		return;
	}
	
	// find out the setting that folder0-4 need to be
	if(folder_num_0 == -1) {
		folder_num_0 = newFolderNum;
	} else if (folder_num_1 == -1) {
		folder_num_1 = newFolderNum;
	} else if (folder_num_2 == -1) {
		folder_num_2 = newFolderNum;
	} else if (folder_num_3 == -1) {
		folder_num_3 = newFolderNum;
	} else {
		// email appears in > 4 folders -> ignore
		return;
	}
	
	// write out folder0-4
	if(folderUpdateWriteStmt == nil) {
		NSString *updateEmail = @"UPDATE email SET folder_num = ?, folder_num_1 = ?, folder_num_2 = ?, folder_num_3 = ? WHERE pk = ?;";
		int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [updateEmail UTF8String], -1, &folderUpdateWriteStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed step in folderUpdateWriteStmt with error %s", sqlite3_errmsg([[AddEmailDBAccessor sharedManager] database]));
			return;
		}
	}
	
	sqlite3_bind_int(folderUpdateWriteStmt, 1, folder_num_0);
	sqlite3_bind_int(folderUpdateWriteStmt, 2, folder_num_1);
	sqlite3_bind_int(folderUpdateWriteStmt, 3, folder_num_2);
	sqlite3_bind_int(folderUpdateWriteStmt, 4, folder_num_3);
	sqlite3_bind_int(folderUpdateWriteStmt, 5, pk);
	
	sqlite3_step(folderUpdateWriteStmt);
	
	sqlite3_reset(folderUpdateWriteStmt);
}

-(void)addToFolderWrapper:(NSMutableDictionary *)data {
	NSDate* date = [data objectForKey:@"datetime"];	
	[date retain];
	NSString *datetime = [self.dbDateFormatter stringFromDate:date];
	[data setObject:datetime forKey:@"datetime"];
	
	// we're using folder_num = accountNum * FOLDER_COUNT_LIMIT + folderNumInAccount because that's easier than changing the schema
	int folderNumInAccount = [[data objectForKey:@"folderNumInAccount"] intValue];
	int accountNum = [[data objectForKey:@"accountNum"] intValue];
	
	int newFolderNum = [EmailProcessor combinedFolderNumFor:folderNumInAccount withAccount:accountNum];
	
	NSString* md5hash = [data objectForKey:@"md5hash"];
	
	int dbNum = [EmailProcessor dbNumForDate:date];
	[date release];
	
	if(self.shuttingDown) return;
	
	NSDictionary* y = [EmailProcessor readUidEntry:md5hash];
	NSString* uid = [y objectForKey:@"uid"];
	int folderNum = [[y objectForKey:@"folderNum"] intValue];
	
	[y release];
	
	if(self.shuttingDown) return;
	
	[self switchToDBNum:dbNum];
	
	[self addToFolder:newFolderNum emailWithDatetime:datetime uid:uid oldFolderNum:folderNum];
	[data release]; // this was retained in our caller, now releasing	
}

-(void)addEmailWrapper:(NSMutableDictionary *)data {
	// Note that there should be no parallel accesses to addEmailWrapper
	
	if(self.shuttingDown) { [data release]; return; }
	
	// strip htmlBody if that's all we found
	// we do this because we don't want to interrupt imap fetching above
	NSString* body = [data objectForKey:@"body"];
	NSString* htmlBody = [data objectForKey:@"htmlBody"];

  // Avoid attempts to insert nil value.
  if (body == nil) {
    body = @"";
  }

	if([body length] == 0 && [htmlBody length] > 0) {
		body = [StringUtil flattenHtml:htmlBody];
	} else {
		body = [StringUtil trim:body];
	}
	
	// cut body to size
	if([body length] > BODY_LENGTH_LIMIT) {
		body = [body substringToIndex:BODY_LENGTH_LIMIT-1];
	}
	
	[data setObject:body forKey:@"body"];
	
	NSDate* date = [data objectForKey:@"datetime"];	
	[date retain];
	NSString *datetime = [self.dbDateFormatter stringFromDate:date];
	[data setObject:datetime forKey:@"datetime"];

	// we're using folder_num = accountNum * FOLDER_COUNT_LIMIT + folderNumInAccount because that's easier than changing the schema
	int folderNumInAccount = [[data objectForKey:@"folderNumInAccount"] intValue];
	int accountNum = [[data objectForKey:@"accountNum"] intValue];
	
	
	int folderNum = [EmailProcessor combinedFolderNumFor:folderNumInAccount withAccount:accountNum];
	
	[data setObject:[NSNumber numberWithInt:folderNum] forKey:@"folderNum"];
	
	NSString *senderName = [data objectForKey:@"senderName"];
	NSString *senderAddress = [data objectForKey:@"senderAddress"];
	NSString *senderFlat = [NSString stringWithFormat:@"%@ %@", senderName, senderAddress];
	
	NSDictionary *toDict = [self recipientList:[data objectForKey:@"toList"]];
	NSString* toFlat = [toDict objectForKey:@"flat"];
	NSString* toJson = [toDict objectForKey:@"json"];
	
	
	NSDictionary *ccDict = [self recipientList:[data objectForKey:@"ccList"]];
	NSString* ccFlat = [ccDict objectForKey:@"flat"];
	NSString* ccJson = [ccDict objectForKey:@"json"];

	NSDictionary *bccDict = [self recipientList:[data objectForKey:@"bccList"]];
	NSString* bccFlat = [bccDict objectForKey:@"flat"];
	NSString* bccJson = [bccDict objectForKey:@"json"];
	
	NSDictionary *attachmentDict = [NSDictionary dictionaryWithObjectsAndKeys:@"", @"json", @"", @"flat", nil];
	@try {
		attachmentDict = [self attachmentList:[data objectForKey:@"attachments"]];
	} @catch (NSException* exp) {
		NSLog(@"Flattening attachment list: %@", exp);
	}
	NSString *attachmentFlat = [attachmentDict objectForKey:@"flat"];
	NSString *attachmentJson = [attachmentDict objectForKey:@"json"];
	
	// metaString
	NSMutableString *metaString = [NSMutableString string];	
	if(senderName != nil && [senderName length] > 0) {
		[metaString appendString:senderName];
	} 
	if(senderAddress != nil && [senderAddress length] > 0) {
		[metaString appendFormat:@" %@", senderAddress];
	}
	
	// correct senderName if necessary
	if([SENDERS_FALSE_NAMES objectForKey:senderAddress] != nil) {
		senderName = [SENDERS_FALSE_NAMES objectForKey:senderAddress];
		[data setObject:senderName forKey:@"senderName"];
	}	
	
	if(toFlat != nil && [toFlat length] > 0) {
		[metaString appendFormat:@" To: %@", toFlat];
	}
	if(ccFlat != nil && [ccFlat length] > 0) {
		[metaString appendFormat:@" Cc: %@", ccFlat];
	}
	if(bccFlat != nil && [bccFlat length] > 0) {
		[metaString appendFormat:@" Bcc: %@", bccFlat];
	}
	if(attachmentFlat != nil && [attachmentFlat length] > 0) {
		[metaString appendFormat:NSLocalizedString(@" Attached: %@",nil), attachmentFlat];
	}
	
	NSString* folderDisplayName = [data objectForKey:@"folderDisplayName"];
	if(folderDisplayName != nil && [folderDisplayName length] > 0) {
		[metaString appendFormat:NSLocalizedString(@" Folder: %@",nil), folderDisplayName];
	}
	
	if([[metaString substringToIndex:1] isEqualToString:@" "]) {
		// trim off the extra whitespace at the start
		[metaString setString:[metaString substringFromIndex:1]];
	}
	
	[data setObject:metaString forKey:@"metaString"];
	
	// Assign JSON fields
	[data setObject:senderFlat forKey:@"senderFlat"];
	[data setObject:attachmentJson forKey:@"attachments"];
	[data setObject:toJson forKey:@"tos"];
	[data setObject:toFlat forKey:@"toFlat"];
	[data setObject:ccJson forKey:@"ccs"];
	[data setObject:ccFlat forKey:@"ccFlat"];
	[data setObject:bccJson forKey:@"bccs"];	
	
	int dbNum = [EmailProcessor dbNumForDate:date];
	[date release];
	
	[data setObject:[NSNumber numberWithInt:dbNum] forKey:@"dbNum"];

	if(self.shuttingDown) return;
	
	[self switchToDBNum:dbNum];
		
	[self addEmail:data];
	
	if(self.updateSubscriber != nil && [self.updateSubscriber respondsToSelector:@selector(processorUpdate:)]) {
		[data retain];
		[self.updateSubscriber performSelector:@selector(processorUpdate:) withObject:data];
	}
	
	[data release]; // retained in messageData
}

-(void)writeUpdateContactName:(int)pk withAddresses:(NSString*)addresses withOccurrences:(int)occurrences dbMin:(int)dbMin dbMax:(int)dbMax {
	if(self.shuttingDown) return;
	
	if(contactNameUpdateStmt == nil) {
		NSString *updateContact = @"UPDATE contact_name SET email_addresses=?, occurrences=?, dbnum_first=?, dbnum_last=? WHERE pk = ?;";
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [updateContact UTF8String], -1, &contactNameUpdateStmt, nil);
		if (dbrc != SQLITE_OK) {
			return;
		}
	}
	
	sqlite3_bind_text(contactNameUpdateStmt, 1, [addresses UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_int(contactNameUpdateStmt, 2, occurrences);
	sqlite3_bind_int(contactNameUpdateStmt, 3, dbMin);
	sqlite3_bind_int(contactNameUpdateStmt, 4, dbMax);
	sqlite3_bind_int(contactNameUpdateStmt, 5, pk);
	
	if (sqlite3_step(contactNameUpdateStmt) != SQLITE_DONE) {
		NSLog(@"==========> Error updating contactName %i", pk);
	}
	sqlite3_reset(contactNameUpdateStmt);
}

-(int)writeContactName:(NSString*)name withAddresses:(NSString*)addresses withOccurrences:(int)occurrences dbNum:(int)dbNum {
	if(self.shuttingDown) return -1;
	
	if(contactNameInsertStmt == nil) {
		NSString *updateContact = @"INSERT OR REPLACE INTO contact_name(name,email_addresses,occurrences, dbnum_first, dbnum_last) VALUES (?,?,?,?,?);";
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [updateContact UTF8String], -1, &contactNameInsertStmt, nil);	
		if (dbrc != SQLITE_OK) {
			return 0;
		}
	}
	
	sqlite3_bind_text(contactNameInsertStmt, 1, [name UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_text(contactNameInsertStmt, 2, [addresses UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_int(contactNameInsertStmt, 3, occurrences);
	sqlite3_bind_int(contactNameInsertStmt, 4, dbNum);
	sqlite3_bind_int(contactNameInsertStmt, 5, dbNum);
	
	if (sqlite3_step(contactNameInsertStmt) != SQLITE_DONE)	{
		NSLog(@"==========> Error inserting or updating contactName %@", name);
	}
	sqlite3_reset(contactNameInsertStmt);
	
	return (int)sqlite3_last_insert_rowid([[ContactDBAccessor sharedManager] database]);
}

+(NSDictionary*)readUidEntry:(NSString*)md5 {
	// have we already synced message given md5?
	if(uidFindStmt == nil) {
		NSString *searchUidEntry = @"SELECT uid, folder_num FROM uid_entry WHERE md5 = ?;";
		int dbrc = sqlite3_prepare_v2([[UidDBAccessor sharedManager] database], [searchUidEntry UTF8String], -1, &uidFindStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed prep of uidSearchStmt");
			return nil;
		}
	}
	
	sqlite3_bind_text(uidFindStmt, 1, [md5 UTF8String], -1, SQLITE_TRANSIENT);
	
	NSMutableDictionary* res = [[NSMutableDictionary alloc] initWithCapacity:2];
	if (sqlite3_step(uidFindStmt) == SQLITE_ROW) {
		NSString* temp = @"";
		const char *sqlVal = (const char *)sqlite3_column_text(uidFindStmt, 0);
		if(sqlVal != nil)
			temp = [NSString stringWithUTF8String:sqlVal];
		[res setObject:temp forKey:@"uid"];
		
		int folderNum = sqlite3_column_int(uidFindStmt, 1);
		NSNumber *folderNumValue = [NSNumber numberWithInt:folderNum];
		[res setObject:folderNumValue forKey: @"folderNum"];
		
		sqlite3_reset(uidFindStmt);
		return res;
	}
	
	sqlite3_reset(uidFindStmt);
	
	return nil;
}

+(BOOL)searchUidEntry:(NSString*)md5 {
	// have we already synced message given md5?
	if(uidSearchStmt == nil) {
		NSString *searchUidEntry = @"SELECT md5 FROM uid_entry WHERE md5 = ?;";
		int dbrc = sqlite3_prepare_v2([[UidDBAccessor sharedManager] database], [searchUidEntry UTF8String], -1, &uidSearchStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed prep of uidSearchStmt");
			return YES;
		}
	}
	
	BOOL result = NO;
	
	sqlite3_bind_text(uidSearchStmt, 1, [md5 UTF8String], -1, SQLITE_TRANSIENT);
	
	if (sqlite3_step(uidSearchStmt) == SQLITE_ROW) {
		result = YES;
	}
	
	sqlite3_reset(uidSearchStmt);
	
	return result;
}

-(void)writeUidEntry:(NSString*)uid folderNum:(int)folderNum md5:(NSString*)md5 {
	if(self.shuttingDown) return;
	
	if(uidInsertStmt == nil) {
		NSString *updateUId = @"INSERT OR REPLACE INTO uid_entry(uid,folder_num,md5) VALUES (?,?,?);";
		int dbrc = sqlite3_prepare_v2([[UidDBAccessor sharedManager] database], [updateUId UTF8String], -1, &uidInsertStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed prep of uidInsertStmt");
			return;
		}
	}
	
	sqlite3_bind_text(uidInsertStmt, 1, [uid UTF8String], -1, SQLITE_TRANSIENT);	
	sqlite3_bind_int(uidInsertStmt, 2, folderNum);	
	sqlite3_bind_text(uidInsertStmt, 3, [md5 UTF8String], -1, SQLITE_TRANSIENT);	
	
	if (sqlite3_step(uidInsertStmt) != SQLITE_DONE)	{
		NSLog(@"==========> Error inserting or updating uid_entry %@", md5);
	}
	sqlite3_reset(uidInsertStmt);
}

-(void)writeSearchContactName:(NSString*)name withPk:(int)pk {
	if(self.shuttingDown) return;
	
	if(searchContactNameInsertStmt == nil) {
		NSString *updateContact = @"INSERT OR REPLACE INTO search_contact_name(docid,name) VALUES (?,?);";
		int dbrc = sqlite3_prepare_v2([[ContactDBAccessor sharedManager] database], [updateContact UTF8String], -1, &searchContactNameInsertStmt, nil);	
		if (dbrc != SQLITE_OK) {
			return;
		}
	}
	
	sqlite3_bind_int(searchContactNameInsertStmt, 1, pk);
	sqlite3_bind_text(searchContactNameInsertStmt, 2, [name UTF8String], -1, SQLITE_TRANSIENT);
	
	if (sqlite3_step(searchContactNameInsertStmt) != SQLITE_DONE)	{
		NSLog(@"==========> Error inserting or updating searchContactName %@", name);
	}
	sqlite3_reset(searchContactNameInsertStmt);
}

-(void)updateContactName:(NSString*)name withAddress:(NSString*)address withSubject:(NSString*)subject withDbNum:(int)dbNum {
	if(self.shuttingDown) return;
	
	if (name == nil || [name length] == 0 || address == nil || [address length] == 0) {
		return; // if name or address are empty, there's no need to update anything
	}
	
	if ([StringUtil isOnlyWhiteSpace:name]) {
		// ignore whitespace-only sender names
		return;
	}
	
	// read existing data for this contact
	SearchRunner *searchM = [SearchRunner getSingleton];
	NSDictionary* contactData = [searchM findContact:name];
	
	// We store addresses in the format "'mail@gaborcselle.com', 'gaborcselle@gmail.com'", etc. so we can pass that right into a query
	NSString* escapedAddress = [NSString stringWithFormat:@"'%@'", [address stringByReplacingOccurrencesOfString:@"'" withString:@""]];
	
	int addReOccurrence = 0;
	if([subject length] > 3) {
		NSString* subjectStart = [[subject substringToIndex:3] lowercaseString];
		//TODO(gabor): Internationalize to more languages, see
		if([subjectStart isEqualToString:@"r:"] || [subjectStart isEqualToString:@"re:"] || [subjectStart isEqualToString:@"aw:"]) { 
			addReOccurrence = 1;
		}
	}
	
	if (contactData == nil) {
		// add contact
		int pk = [self writeContactName:name withAddresses:escapedAddress withOccurrences:addReOccurrence dbNum:dbNum];
		
		// add search entry
		if(pk != -1) {
			[self writeSearchContactName:name withPk:pk];
		}
	} else {
		// update contact with new occurrence count
		int occurrences = [[contactData objectForKey:@"occurrences"] intValue] + addReOccurrence;
		int dbMin = [[contactData objectForKey:@"dbMin"] intValue];
		int dbMax = [[contactData objectForKey:@"dbMax"] intValue];
		
		if(dbMax == 0 || dbNum > dbMax) {
			dbMax = dbNum;
		}
		
		if(dbMin != 0) {
			if(dbNum < dbMin) {
				dbMin = dbNum;
			}
		}
		
		// does it already have the address we're looking for?
		NSString* addresses = (NSString*)[contactData objectForKey:@"emailAddresses"];
		
		if(![StringUtil stringContains:addresses subString:address]) {
			NSString* addressesNew = [NSString stringWithFormat:@"%@, %@", addresses, escapedAddress];
			if ([addresses length] > 0 || [addressesNew length] < 500) {
				// only add the new email address if the new string won't be too long (500 chars should be enough)
				// note side-effect: we might miss out on some addresses in person search
				addresses = addressesNew;
			}
		}
		
		[self writeUpdateContactName:[[contactData objectForKey:@"pk"] intValue] withAddresses:addresses withOccurrences:occurrences dbMin:dbMin dbMax:dbMax];
	}
}

- (void)insertIntoSearch:(int)pk withMetaString:(NSString *)metaString withSubject:(NSString *)subject withBody:(NSString *)body withFrom:(NSString*)from withTo:(NSString*)to withCc:(NSString*)cc withFolder:(NSString*)folder {
	if(self.shuttingDown) return;
	
	//TODO(gabor): Pull out the virtual table creation into a separate function
	if(searchEmailInsertStmt == nil) {
		NSString* updateStmt = @"INSERT INTO search_email(docid, meta, subject, body, sender, tos, ccs, folder) VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
		
		int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [updateStmt UTF8String], -1, &searchEmailInsertStmt, nil);	
		if (dbrc != SQLITE_OK) {			
			NSString *errorMessage = [NSString stringWithFormat:@"Failed to prepare SQL with message: '%s');", sqlite3_errmsg([[AddEmailDBAccessor sharedManager] database])];
			NSLog(@"errorMessage = '%@'",errorMessage);
			return;
		}
	}
	
	sqlite3_bind_int(searchEmailInsertStmt, 1, pk);	
	sqlite3_bind_text(searchEmailInsertStmt, 2, [metaString UTF8String], -1, SQLITE_TRANSIENT);		
	sqlite3_bind_text(searchEmailInsertStmt, 3, [subject UTF8String], -1, SQLITE_TRANSIENT);		
	sqlite3_bind_text(searchEmailInsertStmt, 4, [body UTF8String], -1, SQLITE_TRANSIENT);
	sqlite3_bind_text(searchEmailInsertStmt, 5, [from UTF8String], -1, SQLITE_TRANSIENT);		
	sqlite3_bind_text(searchEmailInsertStmt, 6, [to UTF8String], -1, SQLITE_TRANSIENT);		
	sqlite3_bind_text(searchEmailInsertStmt, 7, [cc UTF8String], -1, SQLITE_TRANSIENT);
	sqlite3_bind_text(searchEmailInsertStmt, 8, [folder UTF8String], -1, SQLITE_TRANSIENT);
	
	if (sqlite3_step(searchEmailInsertStmt) != SQLITE_DONE) {
		NSLog(@"Failed step in searchEmailInsertStmt: '%s', '%i'", sqlite3_errmsg([[AddEmailDBAccessor sharedManager] database]), pk);
	}
	
	sqlite3_reset(searchEmailInsertStmt);
}

+(NSString*)md5WithDatetime:(NSString*)datetime senderAddress:(NSString*)address subject:(NSString*)subject {
	NSString* md5string = [NSString stringWithFormat:@"%@|%@|%@", datetime, address, subject];
	NSString* md5hash = md5(md5string);
	
	return md5hash;
}

-(void)addEmail:(NSMutableDictionary *)data {
	if(self.shuttingDown) return;
	
	if(emailStmt == nil) {
		NSString *updateEmail = @"INSERT INTO email(sender_name, sender_address, tos, ccs, bccs, datetime, msg_id, attachments, folder, uid, folder_num) VALUES (?,?,?,?,?,?,?,?,?,?,?);";
		int dbrc = sqlite3_prepare_v2([[AddEmailDBAccessor sharedManager] database], [updateEmail UTF8String], -1, &emailStmt, nil);	
		if (dbrc != SQLITE_OK) {
			NSLog(@"Failed step in bindEmail with error %s", sqlite3_errmsg([[AddEmailDBAccessor sharedManager] database]));
			return;
		}
		
	}
	
	sqlite3_bind_text(emailStmt, 1, [[data objectForKey:@"senderName"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 2, [[data objectForKey:@"senderAddress"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 3, [[data objectForKey:@"tos"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 4, [[data objectForKey:@"ccs"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 5, [[data objectForKey:@"bccs"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 6, [[data objectForKey:@"datetime"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 7, [[data objectForKey:@"msgId"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 8, [[data objectForKey:@"attachments"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 9, [[data objectForKey:@"folderPath"] UTF8String], -1, NULL);
	sqlite3_bind_text(emailStmt, 10, [[data objectForKey:@"uid"] UTF8String], -1, NULL);
	sqlite3_bind_int(emailStmt, 11, [[data objectForKey:@"folderNum"] intValue]);
	
	if(self.shuttingDown) return;
	
	if (sqlite3_step(emailStmt) != SQLITE_DONE)	{
		NSLog(@"Failed step in emailStmt: '%s', '%i'", sqlite3_errmsg([[AddEmailDBAccessor sharedManager] database]), [[data objectForKey:@"seq"] intValue]);
	}
	sqlite3_reset(emailStmt);
	
	int pk = (int)sqlite3_last_insert_rowid([[AddEmailDBAccessor sharedManager] database]);
	
	[data setObject:[NSNumber numberWithInt:pk] forKey:@"pk"];
	
	//TODO(gabor): massage body for insertion into virtual table
	
	[self insertIntoSearch:pk withMetaString:[data objectForKey:@"metaString"] withSubject:[data objectForKey:@"subject"] withBody:[data objectForKey:@"body"]
				  withFrom:[data objectForKey:@"senderFlat"] withTo:[data objectForKey:@"toFlat"] withCc:[data objectForKey:@"ccFlat"] withFolder:[data objectForKey:@"folderDisplayName"]]; //TODO(gabor): Needs improvement
	
	
	//update the contact table
	int dbNum = [[data objectForKey:@"dbNum"] intValue];
	[self updateContactName:[data objectForKey:@"senderName"] withAddress:[data objectForKey:@"senderAddress"] withSubject:[data objectForKey:@"subject"] withDbNum:dbNum];	
	
	NSString* md5hash = [data objectForKey:@"md5hash"];
	[self writeUidEntry:[data objectForKey:@"uid"] folderNum:[[data objectForKey:@"folderNum"] intValue] md5:md5hash];
	
}
@end
