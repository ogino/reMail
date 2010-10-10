//
//  GmailAttachmentDownloader.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 7/7/09.
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

#import "EmailProcessor.h"
#import "AttachmentDownloader.h"
#import "StringUtil.h"
#import "AppSettings.h"
#import "CTCoreAccount.h"
#import "CTCoreFolder.h"
#import "CTCoreMessage.h"
#import "CTBareAttachment.h"
#import "CTCoreAttachment.h"
#import "ActivityIndicator.h"
#import "GlobalDBFunctions.h"
#import "SyncManager.h"
#import "ImapFolderWorker.h"

@implementation AttachmentDownloader
@synthesize uid;
@synthesize attachmentNum;
@synthesize delegate;
@synthesize folderNum;
@synthesize accountNum;

-(void)dealloc {
	[uid release];
	[delegate release];
	[super dealloc];
}

+(NSString*)attachmentDirPath {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *saveDirectory = [paths objectAtIndex:0];
	
	NSString* attachmentDir = [saveDirectory stringByAppendingPathComponent:@"at"];
	return attachmentDir;
}

+(void)ensureAttachmentDirExists {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *saveDirectory = [paths objectAtIndex:0];

	NSString* attachmentDir = [saveDirectory stringByAppendingPathComponent:@"at"];

	NSFileManager* fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:attachmentDir]) {
		return;
	}
	
	[fileManager createDirectoryAtPath:attachmentDir withIntermediateDirectories:NO attributes:nil error:nil];
}

+(NSString*)fileNameForAccountNum:(int)accountNum folderNum:(int)folderNum uid:(NSString*)uid attachmentNum:(int)attachmentNum {
	int combined = [EmailProcessor combinedFolderNumFor:folderNum withAccount:accountNum];
	NSString* fileName = [NSString stringWithFormat:@"%i-%@-%i", combined, uid, attachmentNum];
	return fileName;
}

-(void)deliverProgress:(NSString*)message {
	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(deliverProgress:)]) {
		[self.delegate performSelectorOnMainThread:@selector(deliverProgress:) withObject:message waitUntilDone:NO];
	}
}

-(void)deliverError:(NSString*)message {
	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(deliverError:)]) {
		[self.delegate performSelectorOnMainThread:@selector(deliverError:) withObject:message waitUntilDone:NO];
	}
}

-(void)deliverAttachment {
	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(deliverAttachment)]) {
		[self.delegate performSelectorOnMainThread:@selector(deliverAttachment) withObject:nil waitUntilDone:NO];
	}
}


-(void)run {
	NSLog(@"AttachmentDownloader run: %i %@", attachmentNum, uid);
	
	[NSThread setThreadPriority:0.1];
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	if(![GlobalDBFunctions enoughFreeSpaceForSync]) {
		[self deliverError:[NSString stringWithFormat:NSLocalizedString(@"iPhone/iPod disk full", nil), exp]];
		[pool release];
		return;
	}
	
	[ActivityIndicator on];
	
	// connect to IMAP server
	[self deliverProgress:NSLocalizedString(@"Logging into Account ...", nil)];
	
	NSString* username = [AppSettings username:self.accountNum];
	NSString* password = [AppSettings password:self.accountNum];
	
	if(username == nil || [username length] == 0 || password == nil) {
		[self deliverError:NSLocalizedString(@"Invalid credentials", nil)];
		[pool release];
		return;
	}
	
	// log in 
	CTCoreAccount* account = [[CTCoreAccount alloc] init];
	
	@try   {
        [account connectToServer:[AppSettings server:self.accountNum] 
							port:[AppSettings serverPort:self.accountNum]
				  connectionType:[AppSettings serverEncryption:self.accountNum]
						authType:[AppSettings serverAuthentication:self.accountNum] 
						   login:username 
						password:password];
    } @catch (NSException *exp) {
		[ActivityIndicator off];
		[account disconnect];
        NSLog(@"Connect exception: %@", exp);
		[self deliverError:[ImapFolderWorker decodeError:exp]];
		[pool release];
        return; 
	}
	
	[self deliverProgress:NSLocalizedString(@"Opening Folder ...", nil)];
	
	// figure out name of folder to fetch (i.e. the Gmail name)
	NSSet* folders;
	@try {
		folders = [account allFolders];
	} @catch (NSException *exp) {
		[ActivityIndicator off];
		[account disconnect];
		[pool release];
        NSLog(@"Error getting folders: %@", exp);
		[self deliverError:[NSString stringWithFormat:NSLocalizedString(@"List Folders: %@", nil), [ImapFolderWorker decodeError:exp]]];
        return; 
	}
	
	NSString* folderPath = nil;
	if ([AppSettings accountType:self.accountNum] == AccountTypeImap) {
		SyncManager* sm = [SyncManager getSingleton];
		
		NSDictionary* folderStatus = [sm retrieveState:self.folderNum accountNum:self.accountNum];
		folderPath = [folderStatus objectForKey:@"folderPath"];
	} else {
		NSLog(@"Account type not recognized");
	}
	
	CTCoreFolder *folder;
	@try {
		folder = [account folderWithPath:folderPath];
	} @catch (NSException *exp) {
		[ActivityIndicator off];
		[account disconnect];
        NSLog(@"Error getting folder: %@", exp);
		[self deliverError:[NSString stringWithFormat:NSLocalizedString(@"Folder: %@", nil), [ImapFolderWorker decodeError:exp]]];
        return; 
	}
	
	if(folder == nil) {
		[ActivityIndicator off];
		[self deliverError:NSLocalizedString(@"Folder not found", nil)];
		[pool release];
        return; 
	}
	
	[self deliverProgress:NSLocalizedString(@"Fetching Attachment ...", nil)];
	
	CTCoreMessage* message;
	@try  {
		message = [folder messageWithUID:self.uid];
		
		NSLog(@"Subject: %@", message.subject);
		
		[message fetchBody];
		
		NSArray* attachments = [message attachments];
		
		if([attachments count] <= self.attachmentNum)  {
			[self deliverError:NSLocalizedString(@"Can't find attachment on server", nil)];
			[pool release];
			return;
		}
		
		CTBareAttachment* attachment = [attachments objectAtIndex:self.attachmentNum];
		
		CTCoreAttachment* fullAttachment = [attachment fetchFullAttachment];
		
		NSString* filename = [AttachmentDownloader fileNameForAccountNum:self.accountNum folderNum:self.folderNum uid:self.uid attachmentNum:self.attachmentNum];
		NSString* attachmentDir = [AttachmentDownloader attachmentDirPath];
		NSString* attachmentPath = [attachmentDir stringByAppendingPathComponent:filename];
		
		[fullAttachment writeToFile:attachmentPath];		
	} @catch (NSException *exp) {
		[self deliverError:[NSString stringWithFormat:NSLocalizedString(@"Fetch error: %@", nil), [ImapFolderWorker decodeError:exp]]];
		[ActivityIndicator off];
		[account disconnect];
		[pool release];
		return;
	}
	
	[ActivityIndicator off];
	[account disconnect];
	[self deliverAttachment];
	[pool release];
}
@end
