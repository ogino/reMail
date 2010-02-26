//
//  EmailProcessor.h
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

#import <Foundation/Foundation.h>

@interface EmailProcessor : NSObject {
	NSOperationQueue *operationQueue;
	NSDateFormatter* dbDateFormatter;
	int currentDBNum;
	int addsSinceTransaction;
	volatile BOOL shuttingDown; // this avoids doing db access while the app is shutting down. It's triggered in ReMailAppDelegate.applicationWillTerminate
	
	id updateSubscriber;	
}


@property (nonatomic, retain) NSOperationQueue *operationQueue;
@property (nonatomic, retain) NSDateFormatter* dbDateFormatter;
@property (nonatomic, retain) id updateSubscriber;
@property (assign) volatile BOOL shuttingDown;

+(id)getSingleton;
+(void)clearPreparedStmts;
+(void)finalClearPreparedStmts;

-(void)beginTransactions;
-(void)endTransactions;

-(void)endNewSync:(int)endSeq folderNum:(int)folderNum accountNum:(int)accountNum;
-(void)endOldSync:(int)startSeq folderNum:(int)folderNum accountNum:(int)accountNum;

+(int)combinedFolderNumFor:(int)folderNumInAccount withAccount:(int)accountNum;
+(int)folderNumForCombinedFolderNum:(int)folderNum;
+(int)accountNumForCombinedFolderNum:(int)folderNum;	

+(int)dbNumForDate:(NSDate*)date;
+(int)folderCountLimit;

-(void)addToFolderWrapper:(NSMutableDictionary *)data;
-(void)addEmailWrapper:(NSMutableDictionary *)data;
-(void)addEmail:(NSMutableDictionary *)data;

+(NSDictionary*)readUidEntry:(NSString*)md5;
+(BOOL)searchUidEntry:(NSString*)md5;
-(void)writeUidEntry:(NSString*)uid folderNum:(int)folderNum md5:(NSString*)md5;

+(NSString*)md5WithDatetime:(NSString*)datetime senderAddress:(NSString*)address subject:(NSString*)subject;
+(BOOL)searchUidEntry:(NSString*)md5;
@end
