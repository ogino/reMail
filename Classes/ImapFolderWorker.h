//
//  ImapFolderWorker.h
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
#import "CTCoreFolder.h"
#import "CTCoreAccount.h"

@interface ImapFolderWorker : NSObject {
	CTCoreFolder* folder;
	CTCoreAccount* account;
	int folderNum;
	int accountNum;
	NSString* folderDisplayName;
	NSString* folderPath;
	
	BOOL firstSync;
}

+(NSString*)decodeError:(NSException*)exp;

-(id)initWithFolder:(CTCoreFolder*)folderLocal folderNum:(int)folderNumLocal account:(CTCoreAccount*)accountLocal accountNum:(int)accountNum;
-(BOOL)run;
-(int)backwardScan:(int)newSyncStart;
-(BOOL)newSync:(int)start total:(int)total seqDelta:(int)seqDelta alreadySynced:(int)alreadySynced;
-(BOOL)oldSync:(int)start total:(int)total;
-(BOOL)fetchFrom:(int)start to:(int)end seqDelta:(int)seqDelta syncingNew:(BOOL)syncingNew progressOffset:(int)progressOffset progressTotal:(int)progressTotal alreadySynced:(int)alreadySynced;

@property (nonatomic, retain) CTCoreFolder* folder;
@property (nonatomic, retain) CTCoreAccount* account;
@property (assign) int folderNum;
@property (assign) int accountNum;
@property (nonatomic, retain) NSString* folderDisplayName;
@property (nonatomic, retain) NSString* folderPath;

@property (assign) BOOL firstSync;
@end
