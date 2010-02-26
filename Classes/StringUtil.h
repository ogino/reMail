//
//  StringUtil.h
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
//  Various String-related utility functions

#import <Foundation/Foundation.h>


@interface StringUtil : NSObject {

}

+(NSArray*)split:(NSString*)s;
+(NSArray*)split:(NSString*)s forCharacters:(NSString*)c;
+(NSArray*)split:(NSString*)s atString:(NSString*)y;
+(NSString*)trim:(NSString*)s;
+(NSString*)deleteQuoteNewLines:(NSString*)s;
+(NSString*)deleteNewLines:(NSString*)s;
+(NSArray*)trimAndSplit:(NSString*)s;
+(NSString*)compressWhiteSpace:(NSString*)s;
+(NSString*)extractHostName:(NSString *)h;
+(BOOL)isSmtpEmailAddress:(NSString*)s;
+(BOOL)stringStartsWith:(NSString*)string subString:(NSString*)sub;
+(BOOL)stringContains:(NSString*)string subString:(NSString*)sub;
+ (NSString *) filePathInDocumentsDirectoryForFileName:(NSString *)filename;
+ (id) stripUnicodeEscapesToPureAscii:(id)maybeText;
+ (NSString *) combineSQLTerms:(NSArray *)terms withOperand:(NSString *)op;
+ (NSString *) twoCharIntRep:(int)integer;
+ (NSString *) rmQuotes:(NSString *)orig;
+(NSString *)flattenHtml:(NSString *)html;
+(BOOL)isOnlyWhiteSpace:(NSString*)y;
NSString* md5( NSString *str );
@end
