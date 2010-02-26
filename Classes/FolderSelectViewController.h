//
//  FolderSelectViewController.h
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

#import <UIKit/UIKit.h>


@interface FolderSelectViewController : UITableViewController {
	NSArray* folderPaths;
	NSDictionary* utf7Decoder;
	NSMutableSet* folderSelected;
	
	NSString* username;
	NSString* password;
	NSString* server;
	
	int encryption;
	int port;
	int authentication;
	
	int firstSetup;
	int accountNum;
	BOOL newAccount;
}

@property (nonatomic, retain) NSDictionary* utf7Decoder;
@property (nonatomic, retain) NSArray* folderPaths;
@property (nonatomic, retain) NSMutableSet* folderSelected;

@property (nonatomic, retain) NSString* username;
@property (nonatomic, retain) NSString* password;
@property (nonatomic, retain) NSString* server;

@property (assign) int encryption;
@property (assign) int port;
@property (assign) int authentication;

@property (assign) int firstSetup;
@property (assign) int accountNum;
@property (assign) BOOL newAccount;
@end
