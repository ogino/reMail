//
//  GlobalDBFunctions.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 6/29/09.
//  Copyright 2009 NextMail Corporation. All rights reserved.
//

#import "GlobalDBFunctions.h"
#import "SearchRunner.h"
#import "AddEmailDBAccessor.h"
#import "UidDBAccessor.h"
#import "ContactDBAccessor.h"
#import "StringUtil.h"
#import "EmailProcessor.h"
#import "ContactName.h"
#import "Email.h"
#import "PastQuery.h"
#import "UidEntry.h"
#import "SyncManager.h"
#import "AttachmentDownloader.h"
#import "AppSettings.h"
#import "BuchheitTimer.h"

@implementation GlobalDBFunctions

#pragma	mark Add DB management
NSInteger intSortReverse(id num1, id num2, void *context){
    int v1 = [num1 intValue];
    int v2 = [num2 intValue];
    if (v1 < v2)
        return NSOrderedDescending;
    else if (v1 > v2)
        return NSOrderedAscending;
    else
        return NSOrderedSame;
}

+(void)deleteAllAttachments {
	NSString* attachmentPath = [AttachmentDownloader attachmentDirPath];
	
	[[NSFileManager defaultManager] removeItemAtPath:attachmentPath error:nil];
}

+(void)deleteAll {
	[GlobalDBFunctions deleteAllAttachments];

	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	
	NSString* fileName;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
	while (fileName = [dirEnum nextObject]) {
		NSString* filePath = [StringUtil filePathInDocumentsDirectoryForFileName:fileName];
		[[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
	}
}

+(NSArray*)emailDBNumbers {
	// returns the names of all email DB's in the directory
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	
	NSString* file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
	
	NSMutableArray *numbers = [NSMutableArray arrayWithCapacity:20];
	while (file = [dirEnum nextObject]) {
		if ([[file pathExtension] isEqualToString: @"edb"]) {
			NSString* fileName = [file stringByDeletingPathExtension];
			if ([[fileName substringToIndex:6] isEqualToString:@"email-"]) {
				NSString* fileNumber = [fileName substringFromIndex:6];
				int number = [fileNumber intValue];
				[numbers addObject:[NSNumber numberWithInt:number]];
			}
		}
	}
	
	// sort the array in reverse (we want the newest db files first)
	NSArray* sortedArray = [numbers sortedArrayUsingFunction:intSortReverse context:NULL];
	
	return sortedArray;
}

+(NSArray*)emailDBNames {
	// returns the names of all email DB's in the directory
	NSArray* sortedArray = [GlobalDBFunctions emailDBNumbers];
	
	NSMutableArray* res = [NSMutableArray arrayWithCapacity:[sortedArray count]];
	for(int i = 0; i < [sortedArray count]; i++) {
		int num = [[sortedArray objectAtIndex:i] intValue];
		NSString* fileName = [NSString stringWithFormat:@"email-%i.edb", num];
		[res addObject:fileName];
	}
	
	return res;
}

+(int)highestDBNum {
	// returns the highest DB number currently out there ...
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	
	NSString* file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
	
	int highest = 0;
	while (file = [dirEnum nextObject]) {
		if ([[file pathExtension] isEqualToString: @"edb"]) {
			NSString* fileName = [file stringByDeletingPathExtension];
			if ([[fileName substringToIndex:6] isEqualToString:@"email-"]) {
				NSString* fileNumber = [fileName substringFromIndex:6];
				int number = [fileNumber intValue];
				if(number > highest) {
					highest = number;
				}
			}
		}
	}
	
	return highest;
}

+(NSString*)addDBFilename {
	// what the current add DB is called (note that this goes to disk)
	int highest = [GlobalDBFunctions highestDBNum];
	
	return [NSString stringWithFormat:@"email-%i.edb", highest];
}

+(NSString*)dbFileNameForNum:(int)dbNum {
	return [NSString stringWithFormat:@"email-%i.edb", dbNum];
}

+(unsigned long long)freeSpaceOnDisk {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *dbPath = [[ContactDBAccessor sharedManager] databaseFilepath];
	NSDictionary *fsAttributes = [fileManager attributesOfFileSystemForPath:dbPath error:nil];
	if(fsAttributes != nil) {
		return [[fsAttributes objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
	}
	
	return 0;
}

+(BOOL)enoughFreeSpaceForSync {
	// returns NO if not enough free space is available on disk to start a new sync
	float freeSpace = [GlobalDBFunctions freeSpaceOnDisk] / 1024.0f / 1024.0f;
	
	return (freeSpace > 4.0f); // at least 4 MB must be available
}

+(unsigned long long)totalAttachmentsFileSize {
	
	[AttachmentDownloader ensureAttachmentDirExists];
	
	NSString *attDirectory = [AttachmentDownloader attachmentDirPath]; 
	
	NSString* file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:attDirectory];

	unsigned long long total = 0;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	while (file = [dirEnum nextObject]) {
		NSString *filePath = [attDirectory stringByAppendingPathComponent:file];
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:nil];
		
		if (fileAttributes != nil) {
			NSNumber *fileSize;
			if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
				total += [fileSize unsignedLongValue];
			}
		}
	}
	
	return total;
}

+(unsigned long long)totalFileSize {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	unsigned long long total = 0;

	// ContactDB 
	NSString *dbPath = [[ContactDBAccessor sharedManager] databaseFilepath];
	if(dbPath != nil) {
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:dbPath error:nil];
		if (fileAttributes != nil) {
			NSNumber *fileSize;
			if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
				total += [fileSize unsignedLongValue];
			}
		}
	}

	// UidDB
	dbPath = [[UidDBAccessor sharedManager] databaseFilepath];
	if(dbPath != nil) {
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:dbPath error:nil];
		if (fileAttributes != nil) {
			NSNumber *fileSize;
			if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
				total += [fileSize unsignedLongValue];
			}
		}
	}
	
	
	NSArray* a = [self emailDBNames];
	NSEnumerator* e = [a objectEnumerator];
	
	NSString* fileName;
	while(fileName = [e nextObject]) {
		NSString *dbPath = [StringUtil filePathInDocumentsDirectoryForFileName:fileName];
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:dbPath error:nil];
		
		if (fileAttributes != nil) {
			NSNumber *fileSize;
			if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
				total += [fileSize unsignedLongValue];
			}
		}
	}
	
	return total;
}

+ (void)tableCheck {
	// NOTE: need to change dbGlobalTableVersion every time we change the schema
	if([AppSettings globalDBVersion] < 1) {
		[ContactName tableCheck];
		[PastQuery tableCheck];
		[UidEntry tableCheck];
		[AppSettings setGlobalDBVersion:1];
	}	
}
@end
