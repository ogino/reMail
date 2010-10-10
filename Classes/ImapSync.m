//
//  ImapSync.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/15/09.
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

#import "ImapSync.h"
#import "SyncManager.h"
#import "AppSettings.h"
#import "CTCoreAccount.h"
#import "CTCoreMessage+ReMail.h"
#import "StringUtil.h"
#import "ImapFolderWorker.h"
#import "MailCoreUtilities.h"

@implementation ImapSync
@synthesize accountNum;

-(void)run {	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	SyncManager *sm = [SyncManager getSingleton];
	[sm clearWarning];
	
	[NSThread setThreadPriority:0.1];
	// connect to IMAP server
	[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Logging into %@ ...", nil), [AppSettings username:self.accountNum]]];
	
	NSString* username = [AppSettings username:self.accountNum];
	NSString* password = [AppSettings password:self.accountNum];
	NSString* server = [AppSettings server:self.accountNum];
	int port = [AppSettings serverPort:self.accountNum];
	int encryption = [AppSettings serverEncryption:self.accountNum];
	int authentication = [AppSettings serverAuthentication:self.accountNum];
	
	if(username == nil || [username length] == 0 || password == nil) {
		[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"Incomplete credentials for account %i", nil), self.accountNum] detail:NSLocalizedString(@"http://www.remail.com/app_incomplete_credentials?lang=en", nil)];
		[pool release];
		return;
	}
	
	// log in 
	CTCoreAccount* account = [[CTCoreAccount alloc] init];
	
	@try {
		@try   {
			struct timeval before_delay = {  45, 0 };
			mailstream_network_delay = before_delay; // plenty of time for gmail to give us folder count
			
			[account connectToServer:server port:port connectionType:encryption authType:authentication login:username password:password];
			
			struct timeval after_delay = {  15, 0 };
			mailstream_network_delay = after_delay; // reset to the standard one so we can know when our connection gets interrupted
		} @catch (NSException *exp) {
			NSLog(@"Connect: %@", [ImapFolderWorker decodeError:exp]);
			
			NSString* error = [NSString stringWithFormat:NSLocalizedString(@"Connect: %@", nil), [ImapFolderWorker decodeError:exp]];
			if([StringUtil stringContains:error subString:@"Parse error"]) {
				error = NSLocalizedString(@"Error connecting to server.", nil);
			} else if([StringUtil stringContains:error subString:@"Error logging into account."]) {
				error = NSLocalizedString(@"Invalid login. Fix in Home>Settings", nil);
			}
					  
			[sm syncAborted:error detail:[NSString stringWithFormat:@"Login response: %@|\n%@", exp, [ImapFolderWorker decodeError:exp]]];
			return; 
		}
		
		if([AppSettings logAllServerCalls]) {
			MailCoreEnableLogging();
		}
		
		[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Checking folders for %@", nil), [AppSettings username:self.accountNum]]];
		
		// get list of all folders
		NSSet* folders;
		@try {
			folders = [account allFolders];
		} @catch (NSException *exp) {
			NSLog(@"Error getting folders: %@", exp);
			[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"List folders: %@", nil), [ImapFolderWorker decodeError:exp]] detail:nil];
			return; 
		}
		
		// mark folders that were deleted on the server as deleted on the client
		int i = 0;
		while(i < [sm folderCount:self.accountNum]) {
			NSDictionary* folderState = [sm retrieveState:i accountNum:self.accountNum];
			NSString* folderPath = [folderState objectForKey:@"folderPath"];
			
			if([sm isFolderDeleted:i accountNum:self.accountNum]) {
				NSLog(@"Folder is deleted: %i %i", i, self.accountNum);
			}
			
			if(![sm isFolderDeleted:i accountNum:self.accountNum] && ![folders containsObject:folderPath]) {
				[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Missing folder: %@", nil), folderPath]];
				NSLog(@"Folder %@ has been deleted - deleting FolderState", folderPath);
				[sm markFolderDeleted:i accountNum:self.accountNum];
				i = 0;
			}
			i++;
		}

		// count all folders that haven't been counted yet
		NSMutableArray* foldersToPreSync = [[NSMutableArray alloc] initWithCapacity:[sm folderCount:self.accountNum]];
		for(int i = 0; i < [sm folderCount:self.accountNum]; i++) {
			if([sm isFolderDeleted:i accountNum:self.accountNum]) {
				continue;
			}
			
			NSMutableDictionary* folderState = [sm retrieveState:i accountNum:self.accountNum];

			NSString* folderCountObj = [folderState objectForKey:@"folderCount"];
			if(folderCountObj != nil) {
				continue;
			}
			
			int folderCount;
			NSString* folderPath = [folderState objectForKey:@"folderPath"];
			NSString* folderDisplayName = [folderState objectForKey:@"folderDisplayName"];
			
			CTCoreFolder* folder;
			@try {
				folder = [account folderWithPath:folderPath];
				[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Counting folder: %@", nil), folderDisplayName]];
				folderCount = [folder totalMessageCount];
				[folderState setValue:[NSNumber numberWithInt:folderCount] forKey:@"folderCount"];
				[sm persistState:folderState forFolderNum:i accountNum:self.accountNum];
				
				[foldersToPreSync addObject:[NSNumber numberWithInt:i]];
			} @catch (NSException *exp) {
				[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Count / first sync error in %@: %@", nil), folderDisplayName, [ImapFolderWorker decodeError:exp]]];
				continue;
			} @finally {
				if(folder != nil) {
					[folder disconnect];				
				}
			}
		}
		
		// pre-sync folders that haven't been synced yet
		for(NSNumber* iN in foldersToPreSync) {			
			if([sm folderCount:self.accountNum] <= 1) { // (not necessary if there's only one folder!
				break;
			}
			
			i = [iN intValue];
			if([sm isFolderDeleted:i accountNum:self.accountNum]) {
				continue;
			}
			
			// do an initial sync of the folder
			NSMutableDictionary* folderState = [sm retrieveState:i accountNum:self.accountNum];
			NSString* folderPath = [folderState objectForKey:@"folderPath"];
			NSString* folderDisplayName = [folderState objectForKey:@"folderDisplayName"];
			
			CTCoreFolder* folder = nil;
			@try {
				folder = [account folderWithPath:folderPath];
				[sm reportProgressString:[NSString stringWithFormat:NSLocalizedString(@"Pre-syncing folder: %@", nil), folderDisplayName]];
								 
				ImapFolderWorker* ifw = [[ImapFolderWorker alloc] initWithFolder:folder folderNum:i account:account accountNum:self.accountNum];
				ifw.firstSync = YES;
				BOOL success = [ifw run];
				[ifw release];
				
				if(!success) {
					break;
				}
			} @catch (NSException *exp) {
				[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Pre-sync error in %@: %@", nil), folderDisplayName, [ImapFolderWorker decodeError:exp]]];
				continue;
			} @finally {
				if(folder != nil) {
					[folder disconnect];				
				}
			}
		}
		
		// select each folder and sync it
		for(int i = 0; i < [sm folderCount:self.accountNum]; i++) {
			if([sm isFolderDeleted:i accountNum:self.accountNum]) {
				continue;
			}
			
			NSDictionary* folderState = [sm retrieveState:i accountNum:self.accountNum];
			NSString* folderPath = [folderState objectForKey:@"folderPath"];
			
			CTCoreFolder *folder;
			@try {
				folder = [account folderWithPath:folderPath];
			} @catch (NSException *exp) {
				if(folder != nil) { // I'm not sure if this is necessary or could prevent crashes, but doing it anyway
					[folder disconnect];
				}
				
				NSLog(@"Error getting folder: %@", exp);
				[sm syncWarning:[NSString stringWithFormat:NSLocalizedString(@"Error getting folder: %@", nil), folderPath]];
				continue; 
			}
			
			if(folder == nil) {
				[sm syncAborted:[NSString stringWithFormat:NSLocalizedString(@"Error getting folder: %@", nil), folderPath] detail:nil];
				return; 
			}

			//Sync it!
			ImapFolderWorker* ifw = [[ImapFolderWorker alloc] initWithFolder:folder folderNum:i account:account accountNum:self.accountNum];
			BOOL success = [ifw run];
			[ifw release];
			[folder disconnect];
			
			if(!success) {
				return; 
			}
		}
		
		[sm syncDone];
	} @finally {
		if([AppSettings logAllServerCalls]) {
			MailCoreDisableLogging();
		}
		
		[account disconnect];
		[account release];
		[pool release];
	}
}

#pragma mark IMAP-related stuff
+(NSString*)validate:(NSString*)username password:(NSString*)password server:(NSString*)server port:(int)port encryption:(int)encryption authentication:(int)authentication folders:(NSMutableArray*)folders {
	CTCoreAccount* account = [[CTCoreAccount alloc] init];
	
	@try   {
        [account connectToServer:server port:port connectionType:encryption authType:authentication login:username password:password];
    } @catch (NSException *exp) {
        NSLog(@"connect exception: %@", exp);
        return [NSString stringWithFormat:@"Connect error: %@", [ImapFolderWorker decodeError:exp]]; 
	}
	
	NSSet* folderSet;
	@try {
		folderSet = [account allFolders];
	} @catch (NSException *exp) {
		[account disconnect];
		[account release];
        return [NSString stringWithFormat:NSLocalizedString(@"Error getting folders: %@", nil), [ImapFolderWorker decodeError:exp]];
	}
	
	NSString* folderName = nil;
	NSEnumerator *folderEnumError = [folderSet objectEnumerator];
	NSMutableArray *gmailFolders = [NSMutableArray arrayWithCapacity:10];
	while(folderName = [folderEnumError nextObject]) {
		if([folderName isEqualToString:@"[Gmail]"] || [folderName isEqualToString:@"[Google Mail]"]) {
			continue;
		}
		
		if([StringUtil stringStartsWith:folderName subString:@"[Gmail]"] ||[StringUtil stringStartsWith:folderName subString:@"[Google Mail]"]) {
			[gmailFolders addObject:folderName];
		} else {
			[folders addObject:folderName];
		}
	}
	
	[folders sortUsingSelector: @selector( caseInsensitiveCompare: )];
	[gmailFolders sortUsingSelector: @selector( caseInsensitiveCompare: )];
	[folders addObjectsFromArray:gmailFolders];
	
	int inboxIndex = [folders indexOfObject:@"INBOX"];
	if(inboxIndex != NSNotFound) {
		[folders removeObject:@"INBOX"];
		[folders insertObject:@"INBOX" atIndex:0];
	}
	
	[account disconnect];
	[account release];
	return @"OK";
}

@end
