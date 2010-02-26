//
//  AppSettings.h
//  NextMailIPhone
//
//  Created by Gabor Cselle on 2/3/09.
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

typedef enum {
	AccountTypeImap = 1 // Add more account types (e.g. Exchange, Pop) here once they're supported	
} email_account_type_enum;

typedef enum {
	ReMailOpenSource = 4 // open source version
} remail_edition_enum;

@interface AppSettings : NSObject {
}

+(remail_edition_enum)reMailEdition;
+(NSString*)version;
+(NSString*)appID;
+(NSString*)udid;
+(NSString*)systemVersion;
+(NSString*)model;
+(BOOL)reset;
+(void)setReset:(BOOL)value;
+(int)interval;
+(BOOL)promo;
+(void)setLastpos:(NSString*)y;
+(NSString*)lastpos;
+(BOOL)firstSync;
+(void)setFirstSync:(BOOL)firstSync;
+(NSString*)dataInitVersion;
+(void)setDataInitVersion;
+(int)datastoreVersion;
+(void)setDatastoreVersion:(int)value;
+(BOOL)logAllServerCalls;
	

+(int)globalDBVersion;
+(void)setGlobalDBVersion:(int)version;

// data about accounts
+(int)numAccounts;
+(void)setNumAccounts:(int)value;
+(BOOL)accountDeleted:(int)accountNum;
+(void)setAccountDeleted:(BOOL)value accountNum:(int)accountNum;

+(BOOL)last12MosOnly;

+(email_account_type_enum)accountType:(int)accountNum;
+(void)setAccountType:(email_account_type_enum)type accountNum:(int)accountNum;
+(NSString*)server:(int)accountNum;
+(void)setServer:(NSString*)value accountNum:(int)accountNum;
+(int)serverEncryption:(int)accountNum;
+(void)setServerEncryption:(int)type accountNum:(int)accountNum;
+(int)serverPort:(int)accountNum;
+(void)setServerPort:(int)port accountNum:(int)accountNum;
+(int)serverAuthentication:(int)accountNum;
+(void)setServerAuthentication:(int)type accountNum:(int)accountNum;
+(NSString*)username:(int)accountNum;
+(void)setUsername:(NSString*)y accountNum:(int)accountNum;
+(NSString*)password:(int)accountNum;
+(void)setPassword:(NSString*)y accountNum:(int)accountNum;

+(int)searchCount;
+(void)incrementSearchCount;

+(BOOL)pinged;
+(void)setPinged;

+(NSString*)pushDeviceToken;
+(void)setPushDeviceToken:(NSString*)y;
+(void)setPushTime:(NSDate*)date;
+(NSDate*)pushTime;

+(int)recommendationCount;
+(void)incrementRecommendationCount;

// in-store sales
+(BOOL)featurePurchased:(NSString*)productIdentifier;
+(void)setFeaturePurchased:(NSString*)productIdentifier;
+(void)setFeatureUnpurchased:(NSString*)productIdentifier;
@end
