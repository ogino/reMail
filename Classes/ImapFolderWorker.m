//
//  ImapFolderWorker.m
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

#import "AppSettings.h"
#import "ImapFolderWorker.h"
#import "SyncManager.h"
#import "EmailProcessor.h"
#import "CTCoreMessage+ReMail.h"
#import "CTCoreAddress.h"
#import "MailCoreTypes.h"
#import "MailCoreUtilities.h"

#define MESSAGES_PER_FETCH 20

@implementation ImapFolderWorker

@synthesize folder;
@synthesize folderNum;
@synthesize account;
@synthesize accountNum;
@synthesize folderPath;
@synthesize folderDisplayName;
@synthesize firstSync;

- (void) dealloc {
	[folder release];
	[account release];
	[folderPath release];
	[folderDisplayName release];
	[super dealloc];
}


-(id)initWithFolder:(CTCoreFolder*)folderLocal folderNum:(int)folderNumLocal account:(CTCoreAccount*)accountLocal accountNum:(int)accountNumLocal {
	// folderLocal: Folder object to sync
	// folderAlias: Alias to use for state retrieval / storage
	self = [super init];
	if (self) {
		self.folder = folderLocal;
		self.folderNum = folderNumLocal;
		self.account = accountLocal;
		self.accountNum = accountNumLocal;
	}
	return self;
}

+(int)numberFromError:(NSException*)exp {
	// Parses out the number from "Error number: 5"
	NSString* error = [NSString stringWithFormat:@"%@", exp];
	
	if(![error hasPrefix:@"Error number: "]) {
		return -1;
	}
	
	return [[error substringFromIndex:[@"Error number: " length]] intValue];	
}

-(BOOL)errorFatal:(NSException*)exp {
	int errorNumber = [ImapFolderWorker numberFromError:exp];
	if([[NSString stringWithFormat:@"%@", exp] isEqualToString:CTMIMEParseErrorDesc]) {
		// Just a MIME parse error - we can just ignore and go on
		return NO;
	}
	
	switch (errorNumber) {
		case MAILIMAP_ERROR_STREAM:
			return NO;
		case MAILIMAP_ERROR_PROTOCOL: // being really cocky here - I'm ignoring the protocol errors after last mail from Sigward
			return NO;
		case MAILIMAP_ERROR_PARSE:
			return NO;
		case 31: // Email by Florian Heusel
			return NO;
		case 23:
			return NO; // Email by Karl Heindel - seems to be MAILIMAP_ERROR_FETCH which I will treat as non-fatal for now
		case 26:
			return NO;
		case 42:
			return NO; // various people have reported this error and I'm just not sure whether this is a problem or not
		default:
			return YES;		
	}
}

+(NSString*)decodeError:(NSException*)exp {
	int errorNumber = [ImapFolderWorker numberFromError:exp];
	switch (errorNumber) {
		case MAILIMAP_ERROR_BAD_STATE:
			return @"Bad state";
		case MAILIMAP_ERROR_STREAM:
			return @"Stream error"; // Used to be @"Lost connection"
		case MAILIMAP_ERROR_PARSE:
			return @"Parse error";
		case MAILIMAP_ERROR_CONNECTION_REFUSED:
			return @"Connection refused";
		case MAILIMAP_ERROR_MEMORY:
			return @"Memory Error";
		case MAILIMAP_ERROR_FATAL:
			return @"IMAP connection lost"; // I renamed this to calm users
		case MAILIMAP_ERROR_PROTOCOL:
			return @"Protocol Error";
		case MAILIMAP_ERROR_DONT_ACCEPT_CONNECTION:
			return @"Connection not accepted";
		case MAILIMAP_ERROR_APPEND:
			return @"Append error";
		case MAILIMAP_ERROR_NOOP:
			return @"NOOP error";
		case MAILIMAP_ERROR_LOGOUT:
			return @"Logout error";
		case MAILIMAP_ERROR_CAPABILITY:
			return @"Capability error";
		case MAILIMAP_ERROR_CHECK:
			return @"Check command error";
		case MAILIMAP_ERROR_CLOSE:
			return @"Close command error";
		case MAILIMAP_ERROR_EXPUNGE:
			return @"Expunge command error";
		case MAILIMAP_ERROR_COPY:
			return @"Copy command error";
		case MAILIMAP_ERROR_UID_COPY:
			return @"UID copy command error";
		case MAILIMAP_ERROR_CREATE:
			return @"Create command error";
		case MAILIMAP_ERROR_DELETE:
			return @"Delete error";
		case MAILIMAP_ERROR_EXAMINE:
			return @"Examine command error";
		case MAILIMAP_ERROR_FETCH:
			return @"Fetch command error";
		case MAILIMAP_ERROR_UID_FETCH:
			return @"UID fetch command error";
		case MAILIMAP_ERROR_LIST:
			return @"List command error";
		case MAILIMAP_ERROR_LOGIN:
			return @"Login error";
		case MAILIMAP_ERROR_LSUB:
			return @"Lsub error";
		case MAILIMAP_ERROR_RENAME:
			return @"Rename error";
		case MAILIMAP_ERROR_SEARCH:
			return @"Search error";
		case MAILIMAP_ERROR_UID_SEARCH:
			return @"Uid search error";
		case MAILIMAP_ERROR_SELECT:
			return @"Select cmnd error";
		case MAILIMAP_ERROR_STATUS:
			return @"Status cmnd error";
		case MAILIMAP_ERROR_STORE:
			return @"Store cmnd error";
		case MAILIMAP_ERROR_UID_STORE:
			return @"Uid store cmd error";
		case MAILIMAP_ERROR_SUBSCRIBE:
			return @"Subscribe error";
		case MAILIMAP_ERROR_UNSUBSCRIBE:
			return @"Unsubscribe error";
		case MAILIMAP_ERROR_STARTTLS:
			return @"StartTLS error";
		case MAILIMAP_ERROR_INVAL:
			return @"Inval cmd error";
		case MAILIMAP_ERROR_EXTENSION:
			return @"Extension error";
		case MAILIMAP_ERROR_SASL:
			return @"SASL error";
		case MAILIMAP_ERROR_SSL:
			return @"SSL error";
		// the following are from maildriver_errors.h
		case MAIL_ERROR_PROTOCOL:
			return @"Protocol error";
		case MAIL_ERROR_CAPABILITY:
			return @"Capability error";
		case MAIL_ERROR_CLOSE:
			return @"Close error";
		case MAIL_ERROR_FATAL:
			return @"Fatal error";
		case MAIL_ERROR_READONLY:
			return @"Readonly error";
		case MAIL_ERROR_NO_APOP:
			return @"No APOP error";
		case MAIL_ERROR_COMMAND_NOT_SUPPORTED:
			return @"Cmd not supported";
		case MAIL_ERROR_NO_PERMISSION:
			return @"No permission";
		case MAIL_ERROR_PROGRAM_ERROR:
			return @"Program error";
		case MAIL_ERROR_SUBJECT_NOT_FOUND:
			return @"Subject not found";
		case MAIL_ERROR_CHAR_ENCODING_FAILED:
			return @"Encoding failed";
		case MAIL_ERROR_SEND:
			return @"Send error";
		case MAIL_ERROR_COMMAND:
			return @"Command error";
		case MAIL_ERROR_SYSTEM:
			return @"System error";
		case MAIL_ERROR_UNABLE:
			return @"Unable error";
		case MAIL_ERROR_FOLDER:
			return @"Folder errror";
			
		default:
			return [NSString stringWithFormat:@"%@", exp];		
	}
}

-(NSString*)lastResponse {
	mailimap* mi = [self.account session];
	
	MMAPString *buf = mi->imap_response_buffer;
	
	// build a string from a sized buffer
	return [NSString stringWithFormat:@"%.*s", buf->len, buf->str];
}

+(BOOL)isProtocolError:(NSException*)exp {
	int errorNumber = [ImapFolderWorker numberFromError:exp];
	// 8 = MAILIMAP_ERROR_FATAL - 26 = MAILIMAP_ERROR_LIST
	return (errorNumber == MAILIMAP_ERROR_PROTOCOL) || (errorNumber == 8) || (errorNumber == 26);
}

-(BOOL)run {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	SyncManager* sm = [SyncManager getSingleton];
	[sm clearClientMessage];
	NSMutableDictionary* folderState = [sm retrieveState:folderNum accountNum:self.accountNum];
	
	self.folderDisplayName = [folderState objectForKey:@"folderDisplayName"];
	if([self.folderDisplayName isEqualToString:@""]) {
		self.folderDisplayName = @"All Mail";
	}
	
	self.folderPath = [folderState objectForKey:@"folderPath"];
	
	// Get message count for folder
	int folderCount;
	@try {
		if(self.folderDisplayName != nil && [self.folderDisplayName length] > 0) {
			[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Checking: %@", nil), self.folderDisplayName]];
		} else {
			[sm reportProgressString:NSLocalizedString(@"Getting message counts ...", nil)];
		}
		
		folderCount = [self.folder totalMessageCount];
	} @catch (NSException *exp) {
		//This used to be a fatal error, testing for Christian at 
		[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Folder count error: %@ %@", nil), self.folderDisplayName, [ImapFolderWorker decodeError:exp]]];
		
		NSNumber* folderCountObj = [folderState objectForKey:@"folderCount"];
		
		if(folderCountObj == nil) {
			// There hasn't been a previous count of this folder - above
			[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Folder count error: %@ %@", nil), self.folderDisplayName, [ImapFolderWorker decodeError:exp]]];
			[pool release];
			return YES;
		}
		
		folderCount = [[folderState objectForKey:@"folderCount"] intValue];
	}
	
	// determine which sequence number to sync
	int newSyncStart = folderCount; // start by syncing messages from this number onward
	int oldSyncStart = folderCount; // then sync message from this seq number downward
	int seqDelta = 0; // when syncing new messages, add this number to the seq number (it's equal to the number of deleted messages so far, and avoids us overwriting old messages)


	if([folderState objectForKey:@"newSyncStart"] != nil && [folderState objectForKey:@"oldSyncStart"] != nil && [folderState objectForKey:@"seqDelta"] != nil) {
		newSyncStart = [[folderState objectForKey:@"newSyncStart"] intValue];
		oldSyncStart = [[folderState objectForKey:@"oldSyncStart"] intValue];
		seqDelta = [[folderState objectForKey:@"seqDelta"] intValue];
	}
	
	NSLog(@"%@ Mail count: %i, newSyncStart: %i, oldSyncStart: %i seqDelta: %i", self.folderPath, folderCount, newSyncStart, oldSyncStart, seqDelta);

	// check folderCount for sanity
	if(folderCount == 0 && newSyncStart > folderCount) {
		[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Empty folder: %@ %i/%i",nil), self.folderDisplayName, folderCount, newSyncStart]];
		//Stop sync but don't quit syncing
		[pool release];
		return YES;
	}
	
	// reset counts if folder has shrunk
	if(newSyncStart > folderCount) {
		seqDelta += newSyncStart - folderCount;
		newSyncStart = folderCount;
	}
	if(oldSyncStart > folderCount) {
		oldSyncStart = folderCount;
	}
	
	// backward UID sync here
	// don't do this the first time we sync, when the folder count hasn't changed, and when we're not skipping errored emails
	if(newSyncStart != oldSyncStart && sm.skipMessageAccountNum == -1 && sm.skipMessageFolderNum == -1 && sm.skipMessageStartSeq == -1) { 
		@try {
			[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Scanning messages in %@", nil), folderDisplayName]];
			int proposedNewSyncStart  = [self backwardScan:newSyncStart];
			if(proposedNewSyncStart < newSyncStart) {
				NSLog(@"Backward sync reset %i to %i", newSyncStart, proposedNewSyncStart);
				seqDelta += newSyncStart - proposedNewSyncStart; // need to add to syncDelta so seq numbers end up being higher
				newSyncStart = proposedNewSyncStart;			
			}		
		} @catch (NSException *exp) {
			NSLog(@"Error in backward scan: %@", exp);
			[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Backward scan: %@", nil), exp]];
		}
	}
	
	[folderState setObject:[NSNumber numberWithInt:newSyncStart] forKey:@"newSyncStart"];
	[folderState setObject:[NSNumber numberWithInt:oldSyncStart] forKey:@"oldSyncStart"];
	[folderState setObject:[NSNumber numberWithInt:folderCount] forKey:@"folderCount"];
	[folderState setObject:[NSNumber numberWithInt:newSyncStart-oldSyncStart] forKey:@"numSynced"];
	[folderState setObject:[NSNumber numberWithInt:seqDelta] forKey:@"seqDelta"];
	[sm persistState:folderState forFolderNum:self.folderNum accountNum:self.accountNum];
	
	EmailProcessor* emailProcessor = [EmailProcessor getSingleton];
	
	[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Downloading new mail in %@", nil), folderDisplayName]];
	
	BOOL success = YES;
	if((newSyncStart != folderCount)) { // NOTE(gabor): I killed off the newSyncStart == 0 condition, don't know what it was for ...
		int alreadySynced = newSyncStart-oldSyncStart;
		
		// do sync of new messages
		success = [self newSync:newSyncStart total:folderCount seqDelta:seqDelta alreadySynced:(int)alreadySynced];
		if(success) {
			// write out that new sync is done and commit open transaction
			[emailProcessor endNewSync:folderCount folderNum:self.folderNum accountNum:self.accountNum];
		}
	}
	
	[sm clearWarning]; // clear any warnings from newSync
	
	[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Downloading mail in %@", nil), folderDisplayName]];
	
	if(success && oldSyncStart > 0){
		// do sync of old messages
		success = [self oldSync:oldSyncStart total:folderCount];
		if(success && !self.firstSync) {
			// write out that old sync is done and commit open transaction
			[emailProcessor endOldSync:0 folderNum:self.folderNum accountNum:self.accountNum];
		}
	}
	
	[sm clearWarning]; // clear any warnings from oldSync
		
	[pool release];
	
	return success;
}

-(int)backwardScan:(int)newSyncStart {
	// scan backwards by 20 messages and see if we have all of them
	if(newSyncStart <= 0) {
		return 0;
	}
	
	EmailProcessor* emailProcessor = [EmailProcessor getSingleton];
	
	// TODO(gabor): Should we scan more than MESSAGES_PER_FETCH?
	int end = newSyncStart;
	int begin = MAX(0,newSyncStart - MESSAGES_PER_FETCH);
	
	NSArray* messages = [[self.folder messageObjectsFromIndex:begin+1 toIndex:end] allObjects];
	
	for (int i = 0; i < [messages count]; i++) {
		CTCoreMessage* msg;
		
		msg = [messages objectAtIndex:i];
		NSString* senderAddress = [[msg.from anyObject] email];
		NSString* subject = msg.subject;
		NSDate* date = [msg sentDateGMT];
		if(date == nil) {
			// if you couldn't get the sent date from the message, use a fake date in the distant past
			date = [NSDate distantPast];
		}
		
		NSString* datetime = [emailProcessor.dbDateFormatter stringFromDate:date];
		// generate MD5 hash
		NSString* md5hash = [EmailProcessor md5WithDatetime:datetime senderAddress:senderAddress subject:subject];
		
		if(![EmailProcessor searchUidEntry:md5hash]) {
			return MAX(0, begin+i-1); // not sure about the -1 in here
		} 
	}
	
	return newSyncStart;
}

-(BOOL)newSync:(int)start total:(int)total seqDelta:(int)seqDelta alreadySynced:(int)alreadySynced {
	// syncs new messages from start to end, returns NO on failure
	// alreadySynced: already synced to date, so we can correctly report progress numbers
	
	int progressTotal = total-start;
	
	int bucket_start = start;
	while(bucket_start < total) {
		int progressOffset = bucket_start - start;
		
		int syncedInFolder = alreadySynced + progressOffset;

		int bucket_end = MIN(total, bucket_start + MESSAGES_PER_FETCH);
		if(![self fetchFrom:bucket_start+1 to:bucket_end seqDelta:seqDelta syncingNew:YES progressOffset:progressOffset progressTotal:progressTotal alreadySynced:syncedInFolder]) {
			return NO;
		}
		bucket_start = bucket_start + MESSAGES_PER_FETCH;
	}
	
	return YES;
}
	
-(BOOL)oldSync:(int)start total:(int)total {
	// syncs old messages from start back to 0, returns NO on failure
	int bucket_start = start - MESSAGES_PER_FETCH;
	
	int progressTotal = total;
	
	while(bucket_start > -MESSAGES_PER_FETCH) {
		int bucket_end = bucket_start + MESSAGES_PER_FETCH;
		bucket_start = MAX(bucket_start, 0);
		
		int progressOffset = total - bucket_end;
		
		if(![self fetchFrom:bucket_start+1 to:bucket_end seqDelta:0 syncingNew:NO progressOffset:progressOffset progressTotal:progressTotal alreadySynced:progressOffset]) {
			return NO;
		}
		bucket_start = bucket_start - MESSAGES_PER_FETCH;
		
		if(self.firstSync) {
			// first sync -> we're done after first 20 messages
			return YES;
		}
	}
	
	return YES;
}

-(void)writeFinishedFolderState:(SyncManager*)sm syncingNew:(BOOL)syncingNew start:(int)start end:(int)end dbNums:(NSMutableSet*)dbNums {
	// used by fetchFrom to write the finished state for this round of syncing to disk
	NSMutableDictionary* syncState = [sm retrieveState:self.folderNum accountNum:self.accountNum];
	
	if(dbNums != nil) { // record which dbNums elements from this folder occur in
		NSMutableArray* dbNumsArray = [syncState objectForKey:@"dbNums"];
		if(dbNumsArray == nil) {
			dbNumsArray = [NSMutableArray arrayWithCapacity:[dbNums count]];
		} 

		// TODO(gabor): Is there a speedier way than building this set first?
		//              (Unfortunately we can't serialize NSMutableSets into plists)
		NSSet* dbNumsSet = [NSSet setWithArray:dbNumsArray];
		for(NSNumber* dbNum in dbNums) {
			if(![dbNumsSet containsObject:dbNum]) {
				[dbNumsArray addObject:dbNum];
			}
		}
		
		[syncState setObject:dbNumsArray forKey:@"dbNums"];
	}	
	
	if(syncingNew) {
		[syncState setObject:[NSNumber numberWithInt:end] forKey:@"newSyncStart"];
		int oldSyncStart = [[syncState objectForKey:@"oldSyncStart"] intValue];
		[syncState setObject:[NSNumber numberWithInt:end-oldSyncStart] forKey:@"numSynced"];
	} else {
		[syncState setObject:[NSNumber numberWithInt:start] forKey:@"oldSyncStart"];
		int newSyncStart = [[syncState objectForKey:@"newSyncStart"] intValue];
		[syncState setObject:[NSNumber numberWithInt:newSyncStart-start+1] forKey:@"numSynced"];
	}
	
	[sm persistState:syncState forFolderNum:self.folderNum accountNum:self.accountNum];
}

-(void)reportProgress:(int)i syncingNew:(BOOL)syncingNew progressOffset:(int)progressOffset progressTotal:(int)progressTotal alreadySynced:(int)alreadySynced {
	SyncManager* sm = [SyncManager getSingleton];
	
	float progress = (float)(i+progressOffset) / (float)progressTotal;
	NSString* progressMessage;
	if(syncingNew) {
		[sm reportProgressNumbers:progressTotal synced:(i+1+alreadySynced) folderNum:self.folderNum accountNum:self.accountNum]; // for status screen
		progressMessage = [NSString stringWithFormat:NSLocalizedString(@"Downloading new mail in %@: %i of %i", nil), self.folderDisplayName, (i+progressOffset), progressTotal];
	} else {
		[sm reportProgressNumbers:progressTotal synced:(i+1+progressOffset) folderNum:self.folderNum accountNum:self.accountNum]; // for status screen
		progressMessage = [NSString stringWithFormat:NSLocalizedString(@"Downloading mail in %@: %i of %i", nil), self.folderDisplayName, (i+progressOffset), progressTotal];
	}

	[sm reportProgress:progress withMessage:progressMessage];
}
 

-(BOOL)fetchFrom:(int)start to:(int)end seqDelta:(int)seqDelta syncingNew:(BOOL)syncingNew progressOffset:(int)progressOffset progressTotal:(int)progressTotal alreadySynced:(int)alreadySynced {
	// Fetches messages with seq numbers from start to end
	// Displays progress using progressOffset, progressTotal, syncingNew
	// (syncingNew is YES when we're syncing new messages)
	
	// For each message:
	// - fetch body
	// - notify to display progress
	// - assemble data for EmailProcessor
	// - send off to EmailProcessor
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	SyncManager* sm = [SyncManager getSingleton];
	
	@try { // This try block is to release the pool at the very bottom
		EmailProcessor* emailProcessor = [EmailProcessor getSingleton];

		// handle skipping
		if(self.accountNum == sm.skipMessageAccountNum && self.folderNum == sm.skipMessageFolderNum && start == sm.skipMessageStartSeq) {
			if(sm.skipMessageStartSeq <= start  && start <= sm.skipMessageStartSeq + MESSAGES_PER_FETCH) {
				// skip these messages next time, too
				[self writeFinishedFolderState:sm syncingNew:syncingNew start:start end:end dbNums:nil];
				
				return YES;
			}
		}

		
		NSArray* messages = nil;
		unsigned int startSeq = (unsigned int)start;
		unsigned int endSeq = (unsigned int)end;
		
		@try  {
			messages = [[self.folder messageObjectsFromIndex:startSeq toIndex:endSeq] allObjects];
			
			IfTrue_RaiseException(messages == nil, CTUnknownError, NSLocalizedString(@"Empty message list",nil));						
		} @catch (NSException *exp) {
			if(![sm serverReachable:self.accountNum]) {
				[sm syncAborted:NSLocalizedString(@"Connection to server lost",nil) detail:[ImapFolderWorker decodeError:exp] accountNum:self.accountNum folderNum:self.folderNum startSeq:start];
				return NO;
			}
			
			if([ImapFolderWorker isProtocolError:exp]) {
				// skip these messages next time
				[self writeFinishedFolderState:sm syncingNew:syncingNew start:start end:end dbNums:nil];
				
				[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"%@ at %i. Try again.", nil), [ImapFolderWorker decodeError:exp], startSeq] 
						 detail:[NSString stringWithFormat:@"Protocol Error at %i-%i: %i", startSeq, endSeq, [ImapFolderWorker numberFromError:exp]] 
						  accountNum:self.accountNum folderNum:self.folderNum startSeq:start];
				
				// set skip stuff
				sm.skipMessageAccountNum = self.accountNum;
				sm.skipMessageFolderNum = self.folderNum;
				sm.skipMessageStartSeq = startSeq;
				
				return NO;
			} else if (![self errorFatal:exp]) {
				[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Warning at %i-%i: %@", nil), startSeq, endSeq, [ImapFolderWorker decodeError:exp]]];
				
				// skip these messages next time - this is just a warning but still a good precaution at the cost of dropping some messages
				[self writeFinishedFolderState:sm syncingNew:syncingNew start:start end:end dbNums:nil];
				
				return YES; // keep on ploughing with the sync
			} else {
				[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"Fetch error at %i: %@", nil), startSeq, [ImapFolderWorker decodeError:exp]] 
						 detail:[NSString stringWithFormat:NSLocalizedString(@"Ways to fix this:\n1. Try syncing again\n2. Copy and email these details for support@yourcompany.com:\n|%i|%@|%@\nUDID: %@\nSeq/Start/End/Total/New:%i/%i/%i/%i", nil), 
								 [ImapFolderWorker numberFromError:exp], [ImapFolderWorker decodeError:exp], [self lastResponse], [AppSettings udid], startSeq, endSeq, progressTotal, (int)syncingNew] 
					 accountNum:self.accountNum  folderNum:self.folderNum startSeq:start];
				return NO;
			}			
		}
		
		NSMutableSet* dbNums = [NSMutableSet setWithCapacity:1];

		int errors = 0;
		BOOL last12MosOnly = [AppSettings last12MosOnly];
		for (int i = 0; i < [messages count]; i++) {
			CTCoreMessage* msg;
			NSString* body = @"";
			NSString* htmlBody = @"";
			
			// declared here so we can use in error reporting
			NSString* senderAddress = @"";
			NSString* subject = @"";
			NSDate* date = nil;
			NSString* md5hash = @"";
			int seqNum = -1; // this is for error reporting only
			
			// fetch body
			@try  {
				if(syncingNew) {
					msg = [messages objectAtIndex:i];
					seqNum = startSeq+i;
				} else {
					// if syncing old messages, sync in reverse order
					msg = [messages objectAtIndex:[messages count]-i-1];
					seqNum = endSeq-i-1;
				}
				
				subject = msg.subject;
				senderAddress = [[msg.from anyObject] email];
				date = [msg sentDateGMT];
				if(date == nil) {
					// if you couldn't get the sent date from the message, use a fake date in the distant past
					date = [NSDate distantPast];
				}
				
				// only fetch items from last 12 moths?
				if(last12MosOnly) {
					int timeInterval = [[NSDate date] timeIntervalSinceDate:date];
					
					if(timeInterval > 365*24*3600) {
						[self reportProgress:i syncingNew:syncingNew progressOffset:progressOffset progressTotal:progressTotal alreadySynced:alreadySynced];
						continue;
					}
				}
				
				// maintain folder -> db num list
				int dbNum = [EmailProcessor dbNumForDate:date];
				[dbNums addObject:[NSNumber numberWithInt:dbNum]];

				// check if we already have this email
				NSString *datetime = [emailProcessor.dbDateFormatter stringFromDate:date];
				md5hash = [EmailProcessor md5WithDatetime:datetime senderAddress:senderAddress subject:subject];
				if([EmailProcessor searchUidEntry:md5hash]) {
					// already have this email -> add folder info
					
					NSNumber* folderNumObj = [NSNumber numberWithInt:self.folderNum];
					NSNumber* accountNumObj = [NSNumber numberWithInt:self.accountNum]; 
					// messageData retain count is 1, addToFolderWrapper has to release
					NSMutableDictionary* messageData = [[NSMutableDictionary alloc] initWithObjectsAndKeys:senderAddress, @"senderAddress", subject, @"subject", 
														date, @"datetime", subject, @"subject",
														folderNumObj, @"folderNumInAccount", accountNumObj, @"accountNum",
														md5hash, @"md5hash", nil];
					
					NSInvocationOperation *nextOp = [[NSInvocationOperation alloc] initWithTarget:emailProcessor selector:@selector(addToFolderWrapper:) object:messageData];
					[emailProcessor.operationQueue addOperation:nextOp];
					[nextOp release];
					
					[self reportProgress:i syncingNew:syncingNew progressOffset:progressOffset progressTotal:progressTotal alreadySynced:alreadySynced];
					
					continue;
				}
				
				// Sleep for 20 milliseconds after each email - improves UI performance
				[NSThread sleepForTimeInterval:0.02]; 
				
				// fetch bodies here
				int err = [msg fetchBody];
				IfTrue_RaiseException(err != 0, CTUnknownError, [NSString stringWithFormat:@"Error number: %i", err]); 
				
				body = msg.body;

				if([body length] == 0) {
					// no text/plain body found - try getting a htmlBody
					htmlBody = msg.htmlBody;
				}
				if(body == nil) {
					body = @"";
				}
				if(htmlBody == nil) {
					htmlBody = @"";
				}
			} @catch (NSException *exp) {
				errors++;
				NSLog(@"Fetching bodies: %@", exp);
				if([ImapFolderWorker isProtocolError:exp]) {
					NSLog(@"LastResponse #2: %@", [self lastResponse]);
				}
				
				if(![sm serverReachable:self.accountNum]) {
					[sm syncAborted:NSLocalizedString(@"Connection to server lost",nil) detail:[ImapFolderWorker decodeError:exp] 
						 accountNum:self.accountNum folderNum:self.folderNum startSeq:start];
					return NO;
				} else if (![self errorFatal:exp]) {
					// just display a warning and continue
					if(![[ImapFolderWorker decodeError:exp] isEqualToString:CTMIMEParseErrorDesc]) {
						[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Warning at seq %i: %@", nil), seqNum, [ImapFolderWorker decodeError:exp]]];
					}
					continue;
				} else {
					NSString* detail = [NSString stringWithFormat:NSLocalizedString(@"Email that caused error:\nSubject: %@\nSender: %@\nDate: %@\nUDID: %@\nSeq/Start/End/Total/New/E:%i/%i/%i/%i/%i/%@.\n\nWays to fix this:\n1. Try syncing again :-)\n2. Hit Skip button below\n3. Delete this email or move it to a location that isn't downloaded by reMail.\n4. Copy and email error to support@yourcompany.com", nil), 
										subject, senderAddress, date, [AppSettings udid], seqNum, startSeq, endSeq, progressTotal, (int)syncingNew, [ImapFolderWorker decodeError:exp]];
					[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"Error fetching message %i: %@", nil), seqNum, [ImapFolderWorker decodeError:exp]] detail:detail 
						 accountNum:self.accountNum  folderNum:self.folderNum startSeq:start];
					return NO;
				}
			}

			// report as progress, right after downloading
			[self reportProgress:i syncingNew:syncingNew progressOffset:progressOffset progressTotal:progressTotal alreadySynced:alreadySynced];
			
			@try {
				NSString* senderName = [[msg.from anyObject] decodedName];
				
				NSSet* to = msg.to;
				NSSet* cc = msg.cc;
				NSSet* bcc = msg.bcc;
				NSNumber* seq;
				if(syncingNew) {
					seq = [NSNumber numberWithInt:seqDelta+startSeq+i];
				} else {
					seq = [NSNumber numberWithInt:seqDelta+startSeq+[messages count]-i-1];
				}
				
				NSString* messageID = [msg messageId];
				NSString* uid = msg.uid;

				NSArray* attachments = [msg attachments];
				
				NSNumber* syncingNewLocal = [NSNumber numberWithBool:syncingNew];
				NSNumber* startSeqObj = [NSNumber numberWithUnsignedInt:startSeq];
				NSNumber* endSeqObj = [NSNumber numberWithUnsignedInt:endSeq];
				
				NSNumber* folderNumObj = [NSNumber numberWithInt:self.folderNum];
				NSNumber* accountNumObj = [NSNumber numberWithInt:self.accountNum]; 
							
				// released in EmailProcessor.addEmailWrapper
				NSMutableDictionary* messageData = [[NSMutableDictionary alloc] initWithObjectsAndKeys:senderAddress, @"senderAddress", senderName, @"senderName", to, @"toList", 
													cc, @"ccList", bcc, @"bccList", subject, @"subject", body, @"body", htmlBody, @"htmlBody", seq, @"seq", date, @"datetime", 
													messageID, @"messageID", uid, @"uid", attachments, @"attachments", self.folderPath, @"folderPath", self.folderDisplayName, @"folderDisplayName", 
													folderNumObj, @"folderNumInAccount", accountNumObj, @"accountNum",
													body, @"body", subject, @"subject", syncingNewLocal, @"syncingNew", startSeqObj, @"startSeq", endSeqObj, @"endSeq", md5hash, @"md5hash", nil];
				
				NSInvocationOperation *nextOp = [[NSInvocationOperation alloc] initWithTarget:emailProcessor selector:@selector(addEmailWrapper:) object:messageData];
				[emailProcessor.operationQueue addOperation:nextOp];
				[nextOp release];
			} @catch (NSException *exp) {
				NSLog(@"Calling addEmailWrapper: %@", exp);
				continue;
			}
		}
		
		// persist sync state
		[self writeFinishedFolderState:sm syncingNew:syncingNew start:start end:end dbNums:dbNums];
	} @finally {
		[pool release];
	}	
	
	return YES;
}
@end
