//
//  ContactDBManager.h
// ----------------------------------------------------------------------
// Part of the SQLite Persistent Objects for Cocoa and Cocoa Touch
//
// Original Version: (c) 2008 Jeff LaMarche (jeff_Lamarche@mac.com)
// ----------------------------------------------------------------------
// This code may be used without restriction in any software, commercial,
// free, or otherwise. There are no attribution requirements, and no
// requirement that you distribute your changes, although bugfixes and 
// enhancements are welcome.
// 
// If you do choose to re-distribute the source code, you must retain the
// copyright notice and this license information. I also request that you
// place comments in to identify your changes.
//
// For information on how to use these classes, take a look at the 
// included Readme.txt file
// ----------------------------------------------------------------------
#import <UIKit/UIKit.h>
#import "sqlite3.h"

#import "AddEmailDBManager.h" // for SQLite3 constants

#import <objc/runtime.h>
#import <objc/message.h>

@interface UidDBManager : NSObject {
	@private
	UidDBManager *singleton;
	NSString *databaseFilepath;
	sqlite3 *database;
}

@property (readwrite,retain) NSString *databaseFilepath;

+ (id)sharedManager;
+ (BOOL)beginTransaction;
+ (BOOL)endTransaction;
- (sqlite3 *)database;
- (void)setAutoVacuum:(SQLITE3AutoVacuum)mode;
- (void)setCacheSize:(NSUInteger)pages;
- (void)setLockingMode:(SQLITE3LockingMode)mode;
- (void)deleteDatabase;
- (void)vacuum;
@end
