//
//  SyncManager.m
//  Remail iPhone
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

#import <CommonCrypto/CommonDigest.h>
#import "SyncManager.h"
#import "ActivityIndicator.h"
#import "BuchheitTimer.h"
#import "StringUtil.h"
#import "Reachability.h"
#import "UidDBAccessor.h"
#import "AppSettings.h"
#import "ImapSync.h"
#import "GlobalDBFunctions.h"

#define SYNC_STATE_FILE_NAME_TEMPLATE    @"sync_state_%i.plist"
#define FOLDER_STATES_KEY		@"folderStates"

static SyncManager *singleton = nil;

@implementation SyncManager

@synthesize progressDelegate;
@synthesize progressNumbersDelegate;
@synthesize clientMessageDelegate;
@synthesize clientMessageWasError;
@synthesize newEmailDelegate;
@synthesize syncStates;
@synthesize syncInProgress;

@synthesize okContentTypes;
@synthesize extensionContentType;

@synthesize lastErrorAccountNum;
@synthesize lastErrorFolderNum;
@synthesize lastErrorStartSeq;
@synthesize skipMessageAccountNum;
@synthesize skipMessageFolderNum;
@synthesize skipMessageStartSeq;
@synthesize lastAbort;

- (void) dealloc {
	[progressDelegate release];
	[progressNumbersDelegate release];
	[clientMessageDelegate release];
	[syncStates release];
	
	[okContentTypes release];
	[extensionContentType release];
	
	[lastAbort release];
	
	[super dealloc];
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
	if (self = [super init]) {
		self.skipMessageAccountNum = -1;
		self.skipMessageFolderNum = -1;
		self.skipMessageStartSeq = -1;
		self.lastErrorAccountNum = -1;
		self.lastErrorFolderNum = -1;
		self.lastErrorStartSeq = -1;
		self.lastAbort = [NSDate distantPast];
		self.clientMessageWasError = NO;
		
		//Get the persistent state
		self.syncStates = [NSMutableArray arrayWithCapacity:2];
		for(int i = 0; i < [AppSettings numAccounts]; i++) {
			if([AppSettings accountDeleted:i]) {
				[self.syncStates addObject:[NSMutableDictionary dictionaryWithCapacity:1]];
			} else {
				NSString *filePath = [StringUtil filePathInDocumentsDirectoryForFileName:[NSString stringWithFormat:SYNC_STATE_FILE_NAME_TEMPLATE, i]];
				
				if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
					NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
					NSMutableDictionary* props = [NSPropertyListSerialization propertyListFromData:fileData mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:nil];
					
					[self.syncStates addObject:props];
					
					[fileData release];
				} else { 
					NSMutableDictionary* props = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:@"2", @"__version", [NSMutableArray array], FOLDER_STATES_KEY, nil] autorelease];
					[self.syncStates addObject:props];
				}		
			}
		}
	}
	
	return self;
}

-(void)runLoop {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[NSThread setThreadPriority:0.1];

	@synchronized(self) {
		if(self.syncInProgress) {
			return;
		}
		self.syncInProgress = YES;
	}
	
	@try {
		[ActivityIndicator on]; // turned back off in syncAborted / syncDone
		
		UIApplication* application = [UIApplication sharedApplication];
		application.idleTimerDisabled = YES;
		
		[self clearClientMessage];
		
		for(int i = 0; i < [AppSettings numAccounts]; i++) {
			if([AppSettings accountDeleted:i]) {
				continue;
			}		
			
			ImapSync* imapSync;
			switch([AppSettings accountType:i]) {
				case AccountTypeImap:
					imapSync = [[ImapSync alloc] init];
					imapSync.accountNum = i;
					[imapSync run];
					[imapSync release];
					break;
				default:
					NSLog(@"Account type currently not supported");
					break;
			}			
		}
	} @catch(NSException* exp) {
		NSLog(@"Exception in runLoop: %@", exp);
	} @finally {
		[ActivityIndicator off];
		UIApplication* application = [UIApplication sharedApplication];
		application.idleTimerDisabled = NO;

		self.syncInProgress = NO;
		[pool release];
	}
}

-(void)run {
	if(self.syncInProgress) {
		return;
	}
	
	//Fire the sync in a separate thread
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoop) object:nil];
	[driverThread start];
	[driverThread release];
}

#pragma mark Request sync
-(BOOL)serverReachable:(int)accountNum {
	NSString *checkHost = [AppSettings server:accountNum];
	[[Reachability sharedReachability] setHostName:checkHost];
	NetworkStatus status =[[Reachability sharedReachability] remoteHostStatus];
	if(status != NotReachable) {
		return YES;
	} else {
		return NO;
	}
}

- (void) requestSyncIfNoneInProgressAndConnectedThread {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	@try {
		//Check there are no push in progres.
		if(self.syncInProgress) {
			return;
		}
		
		BOOL found = NO;
		for(int i = 0; i < [AppSettings numAccounts]; i++) {
			if(![AppSettings accountDeleted:i]) {
				if ([self serverReachable:i]) {
					found = YES;
					break;
				}
			}
		}
		
		if(!found) {
			if([AppSettings numAccounts] > 1) {
				[self reportProgressString:NSLocalizedString(@"Email servers unreachable", nil)];
			} else {
				[self reportProgressString:NSLocalizedString(@"Email server unreachable", nil)];
			}
		} else {
			[self run];
		}
	} @finally {
		[pool release];
	}
}

- (void) requestSyncIfNoneInProgressAndConnected {
	// This can be called from main thread -> thread off
	NSThread *driverThread = [[NSThread alloc] initWithTarget:self selector:@selector(requestSyncIfNoneInProgressAndConnectedThread) object:nil];
	[driverThread start];
	[driverThread release];
}

-(void)requestSyncIfNoneInProgress {	
	//Check there are no push in progres.
	if(![GlobalDBFunctions enoughFreeSpaceForSync]) {
		[self setClientMessage:NSLocalizedString(@"iPhone/iPod disk full", nil) withColor:@"red" withErrorDetail:nil];
		[self reportProgressString:NSLocalizedString(@"Sync aborted", nil)];
		return;
	}
	
	if(self.syncInProgress) {
		return;
	}
	
	[self run];
}

#pragma	mark Update and retrieve syncState
-(int)folderCount:(int)accountNum {
	NSArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	return [folderStates count];
}

-(NSMutableDictionary*)retrieveState:(int)folderNum accountNum:(int)accountNum {
	NSArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	
	if (folderNum >= [folderStates count]) {
		return nil;
	}
	
	return [folderStates objectAtIndex:folderNum];
}

-(void)addAccountState {
	int numAccounts = [AppSettings numAccounts];
	
	NSMutableDictionary* props = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:@"2", @"__version", [NSMutableArray array], FOLDER_STATES_KEY, nil] autorelease];
	[self.syncStates addObject:props];
	
	NSString* filePath = [StringUtil filePathInDocumentsDirectoryForFileName:[NSString stringWithFormat:SYNC_STATE_FILE_NAME_TEMPLATE, numAccounts+1]];
	if(![[self.syncStates objectAtIndex:numAccounts] writeToFile:filePath atomically:YES]) {
		NSLog(@"Unsuccessful in persisting state to file %@", filePath);
	}
	
	[AppSettings setNumAccounts:numAccounts+1];
	[AppSettings setAccountDeleted:NO accountNum:numAccounts];
}


-(void)addFolderState:(NSMutableDictionary *)data accountNum:(int)accountNum {
	NSMutableArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	
	[folderStates addObject:data];
	
	NSString* filePath = [StringUtil filePathInDocumentsDirectoryForFileName:[NSString stringWithFormat:SYNC_STATE_FILE_NAME_TEMPLATE, accountNum]];
	if(![[self.syncStates objectAtIndex:accountNum] writeToFile:filePath atomically:YES]) {
		NSLog(@"Unsuccessful in persisting state to file %@", filePath);
	}
}

-(BOOL)isFolderDeleted:(int)folderNum accountNum:(int)accountNum {
	NSArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	
	if (folderNum >= [folderStates count]) {
		return YES;
	}
	
	NSNumber* y =  [[folderStates objectAtIndex:folderNum] objectForKey:@"deleted"];
	
	return (y == nil) || [y boolValue];
}


-(void)markFolderDeleted:(int)folderNum accountNum:(int)accountNum {
	NSMutableArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	
	NSMutableDictionary* y = [folderStates objectAtIndex:folderNum];
	[y setValue:[NSNumber numberWithBool:YES] forKey:@"deleted"];
	
	NSString* filePath = [StringUtil filePathInDocumentsDirectoryForFileName:[NSString stringWithFormat:SYNC_STATE_FILE_NAME_TEMPLATE, accountNum]];
	if(![[self.syncStates objectAtIndex:accountNum] writeToFile:filePath atomically:YES]) {
		NSLog(@"Unsuccessful in persisting state to file %@", filePath);
	}
}

-(void)persistState:(NSMutableDictionary *)data forFolderNum:(int)folderNum accountNum:(int)accountNum {
	NSMutableArray* folderStates = [[self.syncStates objectAtIndex:accountNum] objectForKey:FOLDER_STATES_KEY];
	
	[folderStates replaceObjectAtIndex:folderNum withObject:data];
	
	NSString* filePath = [StringUtil filePathInDocumentsDirectoryForFileName:[NSString stringWithFormat:SYNC_STATE_FILE_NAME_TEMPLATE, accountNum]];
	if(![[self.syncStates objectAtIndex:accountNum] writeToFile:filePath atomically:YES]) {
		NSLog(@"Unsuccessful in persisting state to file %@", filePath);
	}
}

-(int)emailsOnDeviceExceptFor:(int)folderNum accountNum:(int)accountNum {
	int total = 0;
	for(int a = 0; a < [AppSettings numAccounts]; a++) {
		if([AppSettings accountDeleted:a]) {
			continue;
		}
		
		NSMutableArray* folderStates = [[self.syncStates objectAtIndex:a] objectForKey:FOLDER_STATES_KEY];
		for(int i = 0; i < [folderStates count]; i++) {
			if(a == accountNum && i == folderNum) {
				continue;
			}
			
			NSDictionary* folder = [folderStates objectAtIndex:i];
			if ([folder objectForKey:@"numSynced"] != nil) {
				total += [[folder objectForKey:@"numSynced"] intValue];
			}
		}
		
	}
	return total;
}

-(int)emailsOnDevice {
	int total = 0;
	for(int a = 0; a < [AppSettings numAccounts]; a++) {
		NSMutableArray* folderStates = [[self.syncStates objectAtIndex:a] objectForKey:FOLDER_STATES_KEY];
		
		NSEnumerator* stateEnum = [folderStates objectEnumerator];
		
		NSDictionary* folder = nil;
		while(folder = [stateEnum nextObject]) {
			if ([folder objectForKey:@"numSynced"] != nil) {
				total += [[folder objectForKey:@"numSynced"] intValue];
			}
		}
	}
	return total;
}

-(int)emailsInAccounts {
	int total = 0;
	for(int a = 0; a < [AppSettings numAccounts]; a++) {
		if([AppSettings accountDeleted:a]) { // do not count emails from accounts we have deleted
			continue;
		}
		
		NSMutableArray* folderStates = [[self.syncStates objectAtIndex:a] objectForKey:FOLDER_STATES_KEY];
		
		NSEnumerator* stateEnum = [folderStates objectEnumerator];
		
		NSDictionary* folder = nil;
		while(folder = [stateEnum nextObject]) {
			if ([folder objectForKey:@"deleted"] != nil && [[folder objectForKey:@"deleted"] boolValue]) {
				continue;
			}
			
			if ([folder objectForKey:@"folderCount"] != nil) {
				total += [[folder objectForKey:@"folderCount"] intValue];
			}
		}
	}
	
	return total;	
}

#pragma mark Backchannel for IMAP workers
-(void)clearClientMessage {
	self.clientMessageWasError = NO;
	[self setClientMessage:nil withColor:nil withErrorDetail:nil];
	return;
}

-(void)clearWarning {
	if(!self.clientMessageWasError) {
		[self setClientMessage:nil withColor:nil withErrorDetail:nil];
	}
}

-(void)syncWarning:(NSString*)description {
	NSLog(@"Sync warning: %@", description);
	self.clientMessageWasError = NO;
	[self setClientMessage:description withColor:@"black" withErrorDetail:nil];
	return;
}

-(void)syncAborted:(NSString*)reason detail:(NSString*)detail accountNum:(int)accountNum folderNum:(int)folderNum startSeq:(int)startSeq {
	self.clientMessageWasError = YES;
	self.lastErrorAccountNum = accountNum;
	self.lastErrorFolderNum = folderNum;
	self.lastErrorStartSeq = startSeq;
	
	NSLog(@"Sync aborted: %@|%@", reason, detail);
	[self setClientMessage:reason withColor:@"red" withErrorDetail:detail];
	[self reportProgressString:NSLocalizedString(@"Sync aborted",nil)];

	NSTimeInterval sinceLastAbort = [self.lastAbort timeIntervalSinceNow];
	if(sinceLastAbort < -30.0) {
		// timer to restart sync, as that's a good idea for "connection lost" type cases
		NSTimer *timer = [NSTimer timerWithTimeInterval:30.0
												 target: singleton
											   selector: @selector(requestSyncIfNoneInProgressAndConnected)
											   userInfo: nil
												repeats: NO];
		NSRunLoop *curr = [NSRunLoop mainRunLoop];
		[curr addTimer: timer  forMode: NSRunLoopCommonModes];
		self.lastAbort = [NSDate date];
	}
	
	return;
}

-(void)syncAborted:(NSString*)reason detail:(NSString*)detail {
	[self syncAborted:reason detail:detail accountNum:-1 folderNum:-1 startSeq:-1];
}

-(void)syncDone {
	UIApplication* application = [UIApplication sharedApplication];
	application.idleTimerDisabled = NO;
	
	[self reportProgressString:nil]; // calling this with nil results in "Updated at 11:19am" being shown on the screen
	return;
}

#pragma mark Progress reporting
-(void)reportProgressString:(NSString*)progress {
	if(self.progressDelegate != nil && [self.progressDelegate respondsToSelector:@selector(didChangeProgressStringTo:)]) {
		[self.progressDelegate performSelectorOnMainThread:@selector(didChangeProgressStringTo:) withObject:progress waitUntilDone:NO];
	}
}

-(void)reportProgress:(float)progress withMessage:(NSString*)message {
	NSDictionary* progressDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:progress], @"progress", message, @"message", nil];
	
	if(self.progressDelegate != nil && [self.progressDelegate respondsToSelector:@selector(didChangeProgressTo:)]) {
		[self.progressDelegate performSelectorOnMainThread:@selector(didChangeProgressTo:) withObject:progressDict waitUntilDone:NO];
	}
}

-(void)reportProgressNumbers:(int)total synced:(int)synced folderNum:(int)folderNum accountNum:(int)accountNum {
	NSDictionary* progressDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:total], @"total", [NSNumber numberWithInt:synced], 
								  @"synced", [NSNumber numberWithInt:folderNum], @"folderNum", [NSNumber numberWithInt:accountNum], @"accountNum", nil];
	
	if(self.progressNumbersDelegate != nil && [self.progressNumbersDelegate respondsToSelector:@selector(didChangeProgressNumbersTo:)]) {
		[self.progressNumbersDelegate performSelectorOnMainThread:@selector(didChangeProgressNumbersTo:) withObject:progressDict waitUntilDone:NO];
	}
}

-(void)registerForProgressNumbersWithDelegate:(id) delegate {
	//assert([delegate respondsToSelector:@selector(didChangeProgressNumbersTo:)]); // can be reset to zero
	self.progressNumbersDelegate = delegate;
}

-(void)registerForProgressWithDelegate:(id) delegate {
	assert([delegate respondsToSelector:@selector(didChangeProgressStringTo:)]);
	assert([delegate respondsToSelector:@selector(didChangeProgressTo:)]);
	self.progressDelegate = delegate;
}

#pragma mark Client Messages
- (void) registerForClientMessageWithDelegate:(id) delegate {
	assert([delegate respondsToSelector:@selector(didChangeClientMessageTo:)]);
	self.clientMessageDelegate = delegate;
}

-(void)setClientMessage:(NSString*)message withColor:(NSString*)color withErrorDetail:(NSString*)errorDetailLocal {
	NSDictionary* dict = nil;
	if((message != nil) && (color != nil)) {
		dict = [NSDictionary dictionaryWithObjectsAndKeys:message, @"message", color, @"color", errorDetailLocal, @"errorDetail", nil];
	}
	
	if(self.clientMessageDelegate != nil && [self.clientMessageDelegate respondsToSelector:@selector(didChangeClientMessageTo:)]) {
		[self.clientMessageDelegate performSelectorOnMainThread:@selector(didChangeClientMessageTo:) withObject:dict waitUntilDone:NO];
	}
}

#pragma mark New Email notifications
- (void)registerForNewEmail:(id)delegate {
	assert([delegate respondsToSelector:@selector(didSyncNewEmail)]);
	self.newEmailDelegate = delegate;
}

-(void)triggerNewEmail {
	if(self.newEmailDelegate != nil && [self.newEmailDelegate respondsToSelector:@selector(didSyncNewEmail:)]) {
		[self.newEmailDelegate performSelectorOnMainThread:@selector(didSyncNewEmail:) withObject:nil waitUntilDone:NO];
	}
}

#pragma mark Attachment handling
-(BOOL)isAttachmentViewSupported:(NSString*)contentType filename:(NSString*)filename {
	if(self.okContentTypes == nil) {
		self.okContentTypes = [NSSet setWithObjects:@"image/gif", @"image/png", @"image/tiff", @"image/jpeg", 
							   @"text/plain", @"text/html", @"text/xml", @"application/pdf", @"application/msword", @"application/vnd.ms-excel", nil];
	}
	
	if([self.okContentTypes containsObject:contentType]) {
		return YES;
	}
	
	// else, return yes if content type gets autocorrected
	if(![[self correctContentType:contentType filename:filename] isEqualToString:contentType]) {
		return YES;
	}
	
	return NO;
}
-(NSString*)correctContentType:(NSString*)contentType filename:(NSString*)filename {
	if(self.extensionContentType == nil) {
		self.extensionContentType = [NSDictionary dictionaryWithObjectsAndKeys:@"text/plain", @"m",
									 @"text/plain", @"h",
									 @"text/plain", @"c",
									 @"text/plain", @"cpp",
									 @"text/plain", @"py",
									 @"text/plain", @"rb",
									 @"text/plain", @"cs",
									 @"text/plain", @"csv",
									 @"text/plain", @"java",
									 @"text/plain", @"txt",
									 @"text/plain", @"text",
									 
									 @"text/plain", @"tex", // Latex, as reported by Beta user Kai Kunze
									 
									 @"image/png", @"png",
									 @"image/gif", @"gif",
									 @"image/tiff", @"tiff",
									 @"image/tiff", @"tif",
									 @"image/jpeg", @"jpeg",
									 @"image/jpeg", @"jpg",
									 @"application/pdf", @"pdf", nil];
	}
	
	NSString* extension = [filename pathExtension];
	
	if([self.extensionContentType objectForKey:extension] != nil) {
		return [self.extensionContentType objectForKey:extension];
	}
	
	return contentType;	
}
@end
