//
//  SearchRunner.h
//  ReMailIPhone
//
//  Created by Gabor Cselle on 3/29/09.
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
//  Executes searches, notifies UI of results.

#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "StringUtil.h"
#import "ActivityIndicator.h"
#import "JSON.h"
#import "Email.h"

@interface SearchRunner : NSObject {
	NSObject *autocompleteLock; // makes sure only one autocomplete happens at a time
	NSOperationQueue *operationQueue;
	volatile BOOL cancelled;
}

@property (nonatomic,retain) NSObject *autocompleteLock;
@property (assign) volatile BOOL cancelled; // flag for when we cancel a search op
@property (nonatomic,readwrite,retain) NSOperationQueue *operationQueue;

//Interface
+(id)getSingleton;
+ (void)clearPreparedStmts;
-(void)ftSearch:(NSString*)query withDelegate:(id)delegate withSnippetDelims:(NSArray *)snippetDelims startWithDB:(int)dbIndex;
-(void)allMailWithDelegate:(id)delegate startWithDB:(int)dbIndex;
-(void)senderSearch:(NSString*)addressess withDelegate:(id)delegate startWithDB:(int)dbIndex dbMin:(int)dbMin dbMax:(int)dbMax;
-(void)folderSearch:(int)folderNum withDelegate:(id)delegate startWithDB:(int)dbIndex;
-(void)autocomplete:(NSString *)query withDelegate:(id)autocompleteDelegate;
-(NSDictionary*)findContact:(NSString*)name;
-(void)deleteEmail:(int)pk dbNum:(int)dbNum;
-(Email*)loadEmail:(int)pk dbNum:(int)dbNum;
-(void)cancel;
@end

@protocol SearchManagerDelegate
//Called with a local search result in *absolute* position pos
- (void) deliverSearchResults: (NSArray *)results;
//Called with either YES or NO depending on if there are more results after pos.
- (void) deliverAdditionalResults:(NSNumber *)availableResults;
//Called with the number of the DB we're currently searching through
- (void) deliverProgressUpdate:(NSNumber *)progressNum;
@end