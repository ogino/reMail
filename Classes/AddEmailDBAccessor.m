//
//  AddEmailDBAccessor.m
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

#import "AddEmailDBAccessor.h"

static AddEmailDBAccessor *sharedSQLiteManager = nil;

#pragma mark Private Method Declarations
@interface AddEmailDBAccessor (private)
- (NSString *)databaseFilepath;
- (void)executeUpdateSQL:(NSString *) updateSQL;
@end

@implementation AddEmailDBAccessor

@synthesize databaseFilepath,delegate;

#pragma mark -
#pragma mark Singleton Methods
+ (id)sharedManager 
{
	@synchronized(self) 
	{
		if (sharedSQLiteManager == nil) 
			sharedSQLiteManager = [[[self alloc] init] retain];; 
	}
	return sharedSQLiteManager;
}
+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		if (sharedSQLiteManager == nil) {
			sharedSQLiteManager = [[super allocWithZone:zone] retain];
		}
	}
	
	return sharedSQLiteManager; 

	return nil;
}


//Einar added for sanity.
+ (BOOL)beginTransaction
{
	const char *sql1 = "BEGIN TRANSACTION"; //Should be exclusive?
	sqlite3_stmt *begin_statement;
	if (sqlite3_prepare_v2([[self sharedManager] database], sql1, -1, &begin_statement, NULL) != SQLITE_OK)
	{
		sqlite3_finalize(begin_statement);
		return NO;
	}
	if (sqlite3_step(begin_statement) != SQLITE_DONE) 
	{
		NSLog(@"Failed step in beginTransaction with error %s", sqlite3_errmsg([[self sharedManager] database]));
		sqlite3_finalize(begin_statement);
		return NO;
	}
	sqlite3_finalize(begin_statement);
	return YES;
}


+ (BOOL)endTransaction
{
    const char *sql2 = "COMMIT TRANSACTION";
    sqlite3_stmt *commit_statement;
    if (sqlite3_prepare_v2([[self sharedManager] database], sql2, -1, &commit_statement, NULL) != SQLITE_OK)
    {
		sqlite3_finalize(commit_statement);
        return NO;
    }
    if (sqlite3_step(commit_statement) != SQLITE_DONE) 
    {
		NSLog(@"Failed step in endTransaction with error %s", sqlite3_errmsg([[self sharedManager] database]));
		sqlite3_finalize(commit_statement);
        return NO;
    }
    sqlite3_finalize(commit_statement);
    return YES;
}
- (id)copyWithZone:(NSZone *)zone
{
	return self;
}
- (id)retain
{
	return self;
}
- (unsigned)retainCount
{
	return UINT_MAX;  //denotes an object that cannot be released
}
- (void)release
{
	// never release
}
- (id)autorelease
{
	return self;
}
#pragma mark -
#pragma mark Public Instance Methods
-(sqlite3 *)database {
	static BOOL first = YES;
	
	if (first || database == NULL) {
		first = NO;
		if (!sqlite3_open([[self databaseFilepath] UTF8String], &database) == SQLITE_OK) {
			NSAssert1(0, @"Attempted to open database at path %s, but failed",[[self databaseFilepath] UTF8String]);
			// Even though the open failed, call close to properly clean up resources.
			NSAssert1(0, @"Failed to open database with message '%s'.", sqlite3_errmsg(database));
			sqlite3_close(database);
		} else {
			// Modify cache size so we don't overload memory. 50 * 1.5kb
			[self executeUpdateSQL:@"PRAGMA CACHE_SIZE=1000"];
			
			// Default to UTF-8 encoding
			[self executeUpdateSQL:@"PRAGMA encoding = \"UTF-8\""];
			
			// Turn on full auto-vacuuming to keep the size of the database down
			// This setting can be changed per database using the setAutoVacuum instance method
			[self executeUpdateSQL:@"PRAGMA auto_vacuum=1"];

			// Turn off synchronous update. This is recommended here:
			// http://www.sqlite.org/cvstrac/wiki?p=FtsOne
			[self executeUpdateSQL:@"PRAGMA synchronous=NORMAL"];
		}
	}
	return database;
}

-(void)close {
	// close DB
	if(database != NULL) {
		sqlite3_close(database);
		database = NULL;
	}
}

- (void)setAutoVacuum:(SQLITE3AutoVacuum)mode
{
	NSString *updateSQL = [NSString stringWithFormat:@"PRAGMA auto_vacuum=%d", mode];
	[self executeUpdateSQL:updateSQL];
}
- (void)setCacheSize:(NSUInteger)pages
{
	NSString *updateSQL = [NSString stringWithFormat:@"PRAGMA cache_size=%d", pages];
	[self executeUpdateSQL:updateSQL];
}
- (void)setLockingMode:(SQLITE3LockingMode)mode
{
	NSString *updateSQL = [NSString stringWithFormat:@"PRAGMA cache_size=%d", mode];
	[self executeUpdateSQL:updateSQL];
}
- (void)deleteDatabase
{
	NSString* path = [self databaseFilepath];
	NSFileManager* fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:path error:nil];
	
	database = NULL;
}
- (void)vacuum
{
	[self executeUpdateSQL:@"VACUUM"];
}

#pragma mark -
- (void)dealloc
{
	[databaseFilepath release];
	[super dealloc];
}
#pragma mark -
#pragma mark Private Methods
- (void)executeUpdateSQL:(NSString *) updateSQL
{
	char *errorMsg;
	if (sqlite3_exec([self database],[updateSQL UTF8String] , NULL, NULL, &errorMsg) != SQLITE_OK) {
		NSString *errorMessage = [NSString stringWithFormat:@"Failed to execute SQL '%@' with message '%s'.", updateSQL, errorMsg];
		NSAssert(0, errorMessage);
		sqlite3_free(errorMsg);
	}
}
- (NSString *)databaseFilepath {
	if (databaseFilepath == nil) {
		//assert(FALSE); // You should init CacheManager first, then this won't happen.
		NSMutableString *ret = [NSMutableString string];
		NSString *appName = [[NSProcessInfo processInfo] processName];
		for (int i = 0; i < [appName length]; i++)
		{
			NSRange range = NSMakeRange(i, 1);
			NSString *oneChar = [appName substringWithRange:range];
			if (![oneChar isEqualToString:@" "]) 
				[ret appendString:[oneChar lowercaseString]];
		}
		
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *saveDirectory = [paths objectAtIndex:0];
		NSString *saveFileName = [NSString stringWithFormat:@"%@.sqlite3", ret];
		NSString *filepath = [saveDirectory stringByAppendingPathComponent:saveFileName];
		
		databaseFilepath = [filepath retain];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:saveDirectory]) 
			[[NSFileManager defaultManager] createDirectoryAtPath:saveDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return databaseFilepath;
}
@end
