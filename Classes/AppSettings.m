//
//  AppSettings.m
//  ReMailIPhone
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

#import "AppSettings.h"
#import "StringUtil.h"
#import <UIKit/UIDevice.h>

@implementation AppSettings

+(remail_edition_enum)reMailEdition {
	return ReMailOpenSource;
}


+(NSString*)appID {
	// returns "com.remail.reMail", "com.remail.reMail2", "com.remail.reMail2G"
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
}

+(NSString*)version {
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

+(NSString*)dataInitVersion {
	// version of the software at which the data store was initialized
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return  [defaults stringForKey:@"app_data_init_version"];
}

+(void)setDataInitVersion {
	// version of the software at which the data store was initialized
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:[AppSettings version] forKey:@"app_data_init_version"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)datastoreVersion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults integerForKey:@"datastore_version"];
}

+(void)setDatastoreVersion:(int)value {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:value forKey:[NSString stringWithFormat:@"datastore_version"]];
	[NSUserDefaults resetStandardUserDefaults];
}


+(NSString*)systemVersion {
	NSString* systemVersion = [UIDevice currentDevice].systemVersion;
	return systemVersion;
}


+(NSString*)model {
	NSString* model = [UIDevice currentDevice].model;
	return model;
}


+(NSString*)udid {
	NSString* udid = [UIDevice currentDevice].uniqueIdentifier;
	return udid;
}

+(BOOL)firstSync {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return ([defaults boolForKey:@"app_first_sync"] == NO); //stores the opposite!
}

+(void)setFirstSync:(BOOL)firstSync {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setBool:!firstSync forKey:@"app_first_sync"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(BOOL)promo {
	// returns YES if we can sign users' replies with a reMail promo line
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	BOOL promoPreference = [defaults boolForKey:@"promo_preference"]; 
	
	return promoPreference;
}

+(BOOL)logAllServerCalls {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	BOOL promoPreference = [defaults boolForKey:@"log_all_server_calls"]; 

	return promoPreference;
}

+(BOOL)reset {
	// returns YES if application should be reset at startup
	// this is triggered by setting the "reset" switch in App preferences to yes
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	BOOL resetPreference = [defaults boolForKey:@"reset_preference"]; 
	
	return resetPreference;
}

+(void)setReset:(BOOL)value {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setBool:value forKey:@"reset_preference"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)interval {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int intervalPreference = [defaults integerForKey:@"interval_preference"]; 
	
	if(intervalPreference == 0) {
		return 300;
	}
	
	return intervalPreference;
}

+(BOOL)last12MosOnly {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	BOOL y = [defaults boolForKey:@"last_12mo_preference"]; 
	
	return y;
}


+(NSString*)pushDeviceToken {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	NSString* y = [defaults stringForKey:@"push_device_token"]; 
	return y;
}

+(void)setPushDeviceToken:(NSString*)y {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:y forKey:@"push_device_token"];
}


+(void)setPushTime:(NSDate*)date {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	double value = (double)[date timeIntervalSince1970];
	[defaults setFloat:value forKey:@"push_time"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(NSDate*)pushTime {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	double interval = [defaults doubleForKey:@"push_time"]; 
	if(interval == 0.0) {
		return nil;
	}
	return [NSDate dateWithTimeIntervalSince1970:interval];	
}


+(NSString*)lastpos {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	NSString* y = [defaults stringForKey:@"lastpos_preference"]; 
	
	if(y == nil) {
		return @"home";
	}
	
	return y;
}

+(void)setLastpos:(NSString*)y {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:y forKey:@"lastpos_preference"];
}

+(int)searchCount {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int searchCount = [defaults integerForKey:@"search_count_preference"]; 
	return searchCount;
}

+(void)incrementSearchCount {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int searchCount = [defaults integerForKey:@"search_count_preference"]; 
	[defaults setInteger:searchCount+1 forKey:@"search_count_preference"];
}

+(BOOL)pinged {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return  [defaults boolForKey:@"pinged"];
}

+(void)setPinged {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:@"pinged"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)recommendationCount {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int searchCount = [defaults integerForKey:@"recommendation_count_preference"]; 
	return searchCount;
}

+(void)incrementRecommendationCount {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int searchCount = [defaults integerForKey:@"recommendation_count_preference"]; 
	[defaults setInteger:searchCount+1 forKey:@"recommendation_count_preference"];
}

//////
// Features purchased?

+(BOOL)featurePurchased:(NSString*)productIdentifier {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return  [defaults boolForKey:[NSString stringWithFormat:@"feature_%@", productIdentifier]];
}

+(void)setFeaturePurchased:(NSString*)productIdentifier {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:[NSNumber numberWithBool:YES] forKey:[NSString stringWithFormat:@"feature_%@", productIdentifier]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(void)setFeatureUnpurchased:(NSString*)productIdentifier {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:[NSNumber numberWithBool:NO] forKey:[NSString stringWithFormat:@"feature_%@", productIdentifier]];
	[NSUserDefaults resetStandardUserDefaults];
}

////////////////////////////////////////////////////////
// Data schema version for DB

+(int)globalDBVersion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int pref = [defaults integerForKey:@"global_db_version"]; 
	
	return pref;
}

+(void)setGlobalDBVersion:(int)version {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:version forKey:@"global_db_version"];
	[NSUserDefaults resetStandardUserDefaults];
}

////////////////////////////////////////////////////////
// New preferences for server settings

+(int)numAccounts {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	
	return [defaults integerForKey:@"num_accounts"];		
}

+(void)setNumAccounts:(int)value {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:value forKey:@"num_accounts"];
	[NSUserDefaults resetStandardUserDefaults];
}

+(BOOL)accountDeleted:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	
	return [defaults boolForKey:[NSString stringWithFormat:@"account_deleted_%i", accountNum]];		
}

+(void)setAccountDeleted:(BOOL)value accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setBool:value forKey:[NSString stringWithFormat:@"account_deleted_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(email_account_type_enum)accountType:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	int pref = [defaults integerForKey:[NSString stringWithFormat:@"account_type_%i", accountNum]]; 
	
	return (email_account_type_enum)pref;
}
+(void)setAccountType:(email_account_type_enum)type accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:(int)type forKey:[NSString stringWithFormat:@"account_type_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(NSString*)server:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	
	return [defaults stringForKey:[NSString stringWithFormat:@"server_%i", accountNum]];		
}

+(void)setServer:(NSString*)value accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:value forKey:[NSString stringWithFormat:@"server_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)serverEncryption:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return [defaults integerForKey:[NSString stringWithFormat:@"server_encryption_%i", accountNum]]; 
}

+(void)setServerEncryption:(int)type accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:type forKey:[NSString stringWithFormat:@"server_encryption_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)serverPort:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return [defaults integerForKey:[NSString stringWithFormat:@"server_port_%i", accountNum]]; 
}

+(void)setServerPort:(int)port accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:port forKey:[NSString stringWithFormat:@"server_port_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(int)serverAuthentication:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	return [defaults integerForKey:[NSString stringWithFormat:@"server_authentication_%i", accountNum]]; 
}

+(void)setServerAuthentication:(int)type accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setInteger:type forKey:[NSString stringWithFormat:@"server_authentication_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(NSString*)username:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	NSString* usernamePreference = [defaults stringForKey:[NSString stringWithFormat:@"username_%i", accountNum]];
	
	return usernamePreference;
}

+(void)setUsername:(NSString*)y accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:y forKey:[NSString stringWithFormat:@"username_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}

+(NSString*)password:(int)accountNum{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	NSString* passwordPreference = [defaults stringForKey:[NSString stringWithFormat:@"password_%i", accountNum]]; 
	
	return passwordPreference;
}

+(void)setPassword:(NSString*)y accountNum:(int)accountNum {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
	[defaults setObject:y forKey:[NSString stringWithFormat:@"password_%i", accountNum]];
	[NSUserDefaults resetStandardUserDefaults];
}
@end
