//
//  AddEmailDBManager.m
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

#import "AddEmailDBManager.h"

static AddEmailDBManager *sharedSQLiteManager = nil;

#pragma mark Private Method Declarations
@interface AddEmailDBManager (private)
- (NSString *)databaseFilepath;
- (void)executeUpdateSQL:(NSString *) updateSQL;
@end

@implementation AddEmailDBManager

@synthesize databaseFilepath,delegate;

#pragma mark From SyncManager

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

-(NSArray*)emailDBNames {
	// returns the names of all email DB's in the directory
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	
	NSString* file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
	
	NSMutableArray *numbers = [NSMutableArray arrayWithCapacity:20];
	while (file = [dirEnum nextObject]) {
		if ([[file pathExtension] isEqualToString: @"trie"]) {
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
	
	NSMutableArray* res = [NSMutableArray arrayWithCapacity:[sortedArray count]];
	for(int i = 0; i < [sortedArray count]; i++) {
		int num = [[sortedArray objectAtIndex:i] intValue];
		NSString* fileName = [NSString stringWithFormat:@"email-%i.trie", num];
		[res addObject:fileName];
	}
	
	return res;
}

-(int)highestDBNum {
	// returns the highest DB number currently out there ...
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	
	NSString* file;
	NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
	
	int highest = 0;
	while (file = [dirEnum nextObject]) {
		if ([[file pathExtension] isEqualToString: @"trie"]) {
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

-(NSString*)addDBFilename {
	// what the current add DB is called (note that this goes to disk)
	int highest = [self highestDBNum];
	
	return [NSString stringWithFormat:@"email-%i.trie", highest];
}

-(NSString*)nextAddDBFilename {
	// what the next add DB should be called (note that this goes to disk)
	int highest = [self highestDBNum];
	
	return [NSString stringWithFormat:@"email-%i.trie", highest+1];
}

-(BOOL)shouldRolloverAddEmailDB {
	if(emailCountStmt == nil) {
		NSString* querySQL = @"SELECT count(datetime) FROM email;";
		int dbrc = sqlite3_prepare_v2([[AddEmailDBManager sharedManager] database], [querySQL UTF8String], -1, &emailCountStmt, nil);	
		if (dbrc != SQLITE_OK) {
			assert(NO);//That's a fail fast sort of thing.
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

-(void)rolloverAddEmailDB {
	// rolls over AddEmailDB, starts a new email-X file
	[SyncManager clearPreparedStmts];
	[[AddEmailDBManager sharedManager] close];
	
	// create new, empty db file
	NSString* fileName = [self nextAddDBFilename];
	NSString *dbPath = [StringUtil filePathInDocumentsDirectoryForFileName:fileName];			
	if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) 
	{
		[[NSFileManager defaultManager] createFileAtPath:dbPath contents:nil attributes:nil];
	}
	
	[[AddEmailDBManager sharedManager] setDatabaseFilepath:[StringUtil filePathInDocumentsDirectoryForFileName:fileName]];
	[[AddEmailDBManager sharedManager] setDelegate:self];
	[StartupLogic tableCheck];
}

-(unsigned long long)totalFileSize {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	unsigned long long total = 0;
	
	NSString *dbPath = [StringUtil filePathInDocumentsDirectoryForFileName:CONTACT_DB_NAME];
	NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:dbPath traverseLink:YES];
	if (fileAttributes != nil) {
		NSNumber *fileSize;
		if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
			total += [fileSize unsignedLongValue];
		}
	}
	
	NSArray* a = [self emailDBNames];
	NSEnumerator* e = [a objectEnumerator];
	
	NSString* fileName;
	while(fileName = [e nextObject]) {
		NSString *dbPath = [StringUtil filePathInDocumentsDirectoryForFileName:fileName];
		NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:dbPath traverseLink:YES];
		
		if (fileAttributes != nil) {
			NSNumber *fileSize;
			if (fileSize = [fileAttributes objectForKey:NSFileSize]) {
				total += [fileSize unsignedLongValue];
			}
		}
	}
	
	return total;
}


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
