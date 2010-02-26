//
//  SyncManager.h
//  Remail
//
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
//
//  Singleton. SyncManager is the central place for coordinating syncs:
//  - starting syncs if not in progress
//  - registering for sync-related events
//  - persists sync state of sync processes
//
//  However, SyncManager itself has none of the syncing logic.
//  That's contained in GmailSync, ImapFolderWorker, etc.

#import <Foundation/Foundation.h>

@interface SyncManager : NSObject {
	// delegates for reporting progress
	id progressDelegate;
	id progressNumbersDelegate;
	id clientMessageDelegate;
	id newEmailDelegate;

	// sync-related stuff
	NSMutableArray *syncStates;
	BOOL syncInProgress;
	BOOL clientMessageWasError;

	// Attachment checks
	NSSet* okContentTypes;
	NSDictionary* extensionContentType;
	
	// message to skip while syncing
	int lastErrorAccountNum;
	int lastErrorFolderNum;
	int lastErrorStartSeq;
	int skipMessageAccountNum;
	int skipMessageFolderNum;
	int skipMessageStartSeq;
	NSDate* lastAbort;
}

@property (nonatomic,retain) id progressDelegate;
@property (nonatomic,retain) id progressNumbersDelegate;
@property (nonatomic,retain) id clientMessageDelegate;
@property (nonatomic,retain) id newEmailDelegate;

@property (nonatomic,retain) NSMutableArray *syncStates;
@property (assign) BOOL syncInProgress;
@property (nonatomic) BOOL clientMessageWasError;

//for checking attachments
@property (nonatomic, retain) NSSet* okContentTypes;
@property (nonatomic, retain) NSDictionary* extensionContentType;

// skip message
@property (nonatomic) int lastErrorAccountNum;
@property (nonatomic) int lastErrorFolderNum;
@property (nonatomic) int lastErrorStartSeq;
@property (nonatomic) int skipMessageAccountNum;
@property (nonatomic) int skipMessageFolderNum;
@property (nonatomic) int skipMessageStartSeq;
@property (nonatomic, retain) NSDate* lastAbort;


+(id)getSingleton;
-(id)init; 

//Request a sync
-(BOOL)serverReachable:(int)accountNum;
- (void)requestSyncIfNoneInProgress;
- (void)requestSyncIfNoneInProgressAndConnected;

//Run the sync
-(void)run;

//Update recorded state
-(int)folderCount:(int)accountNum;
-(void)addAccountState;
-(void)addFolderState:(NSMutableDictionary *)data accountNum:(int)accountNum;
-(BOOL)isFolderDeleted:(int)folderNum accountNum:(int)accountNum;
-(void)markFolderDeleted:(int)folderNum accountNum:(int)accountNum;
-(void)persistState:(NSMutableDictionary *)data forFolderNum:(int)folderNum accountNum:(int)accountNum;
-(int)emailsOnDeviceExceptFor:(int)folderNum accountNum:(int)accountNum;
-(int)emailsOnDevice;
-(int)emailsInAccounts;

-(NSMutableDictionary*)retrieveState:(int)folderNum accountNum:(int)accountNum;

//Sync process results
-(void)syncDone;
-(void)syncAborted:(NSString*)reason detail:(NSString*)detail accountNum:(int)accountNum folderNum:(int)folderNum startSeq:(int)startSeq;
-(void)syncAborted:(NSString*)reason detail:(NSString*)detail;
-(void)syncWarning:(NSString*)description;
-(void)clearClientMessage;
-(void)clearWarning;

//Sync process feedback endpoint
-(void)reportProgressString:(NSString*)progress;
-(void)reportProgress:(float)progress withMessage:(NSString*)message;
-(void)reportProgressNumbers:(int)total synced:(int)synced folderNum:(int)folderNum accountNum:(int)accountNum;

// Client messages
-(void)setClientMessage:(NSString*)message withColor:(NSString*)color withErrorDetail:(NSString*)errorDetailLocal;

// registration for notifications
-(void)registerForNewEmail:(id)delegate;
-(void)registerForProgressWithDelegate:(id)delegate;
-(void)registerForProgressNumbersWithDelegate:(id) delegate;
-(void)registerForClientMessageWithDelegate:(id) delegate;

// attachment supported stuff
-(BOOL)isAttachmentViewSupported:(NSString*)contentType filename:(NSString*)filename;
-(NSString*)correctContentType:(NSString*)contentType filename:(NSString*)filename;

@end



