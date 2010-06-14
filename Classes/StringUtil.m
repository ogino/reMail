//
//  StringUtil.m
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

#import <CommonCrypto/CommonDigest.h>
#import "StringUtil.h"
#import "Three20Core/NSStringAdditions.h"

@implementation StringUtil

+(NSArray*)split:(NSString*)s {
	// this is the official tokenizing function of NextMail Corporation :-)
	
	NSCharacterSet* seperator = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\f"];
	
	NSArray* y = [s componentsSeparatedByCharactersInSet:seperator];
	
	return y;
}

+(NSArray*)split:(NSString*)s forCharacters:(NSString*)c {
	// split on non-standard characters
	
	NSCharacterSet* seperator = [NSCharacterSet characterSetWithCharactersInString:c];
	
	NSArray* y = [s componentsSeparatedByCharactersInSet:seperator];
	
	return y;
}

+(NSArray*)split:(NSString*)s atString:(NSString*)y {
	return [s componentsSeparatedByString:y];
}

+(NSString*)extractHostName:(NSString *)h
{
	
	NSRange nsr = [h rangeOfString:@":"];
	if(nsr.location == NSNotFound) {
		return h;
	}
	return [h substringToIndex:nsr.location];
}


+(NSString*)deleteQuoteNewLines:(NSString*)s {
	// converts:
	//// Gabor wrote:
	//// > blah
	//// > blah
	// to
	//// Gabor wrote: blah blah
	NSString* y = [s stringByReplacingOccurrencesOfString:@"\n>" withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"\r>" withString:@" "];
	return y;
}

+(NSString*)deleteNewLines:(NSString*)s {
	NSString* y = [s stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"\f" withString:@" "];
	return y;
}

+(NSString*)compressWhiteSpace:(NSString*)s {
	//TODO(gabor): this is a hack! I'd love to have some regexp's in da house
	NSString* y = [s stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"   " withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"  " withString:@" "];
	y = [y stringByReplacingOccurrencesOfString:@"  " withString:@" "];
	return y;
}

+(NSString*)trim:(NSString*)s {
	NSCharacterSet* seperator = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n\f"];
	
	NSString* y = [s stringByTrimmingCharactersInSet:seperator];
	
	return y;
}

+(NSArray*)trimAndSplit:(NSString*)s {
	NSString* trimmedString = [StringUtil trim:s];
	return [StringUtil split:trimmedString];
}


+(BOOL)isSmtpEmailAddress:(NSString*)s {
	//TODO(gabor): we could do more advanced checking than this
	NSRange nsr = [s rangeOfString:@"@"];
	if(nsr.location == NSNotFound) {
		return NO;
	}
	
	return YES;
}

+(BOOL)stringStartsWith:(NSString*)string subString:(NSString*)sub {
	if([string length] < [sub length]) {
		return NO;
	}
	
	NSString* comp = [string substringToIndex:[sub length]];
	return [comp isEqualToString:sub];
}

+(BOOL)stringContains:(NSString*)string subString:(NSString*)sub {
	//returns YES is string contains subString, False otherwise
	NSRange nsr = [string rangeOfString:sub];
	if(nsr.location == NSNotFound) {
		return NO;
	}
	
	return YES;
}

+ (NSString *) filePathInDocumentsDirectoryForFileName:(NSString *)filename
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES); 
	NSString *documentsDirectory = [paths objectAtIndex: 0]; 
	NSString *pathName = [documentsDirectory stringByAppendingPathComponent:filename];
	return pathName;
}

+ (id)stripUnicodeEscapesToPureAscii:(id)maybeText {
	if([maybeText respondsToSelector:@selector(dataUsingEncoding:)]) {
		NSData* aData;    
		aData = [maybeText dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		maybeText = [[[NSString alloc] initWithData:aData encoding:NSASCIIStringEncoding] autorelease];
	}
	return maybeText;
}

+ (NSString *) twoCharIntRep:(int)integer
{
	if(integer < 10)
		return [NSString stringWithFormat:@"0%i",integer];
	return [NSString stringWithFormat:@"%i",integer];
}

+ (NSString *) rmQuotes:(NSString *)orig
{
	return [orig stringByReplacingOccurrencesOfString:@"'" withString:@""];
}

+ (NSString *) combineSQLTerms:(NSArray *)terms withOperand:(NSString *)op
{
	if([terms count] == 0)
	{
		return @"";
	}
	else if([terms count] == 1 )
	{
		if([[terms objectAtIndex:0] length] > 0)
			return [terms objectAtIndex:0];
		return @"";
	}
	
	NSMutableString *oredString = [NSMutableString stringWithFormat:@" ( "];
	
	BOOL really = NO;
	for(NSString *term in terms)
	{
		if([term length] > 0)
		{
			[oredString appendFormat:@" ( %@ ) %@",term,op];
			really = YES;
		}
	}
	if(!really)
	{
		//return @"( 42 = 42 )";
		return @"";
	}
	[oredString deleteCharactersInRange:NSMakeRange([oredString length]-([op length] + 1), ([op length]+1))];
	
	[oredString appendFormat:@" ) "];
	
	return oredString;
	
}

+(BOOL)isOnlyWhiteSpace:(NSString*)y {
	NSScanner* scanner = [[NSScanner alloc] initWithString:y];
	
	NSString* text = nil;
	[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&text];
	
	if([scanner isAtEnd]) {
		[scanner release];
		return YES;
	}
	
	[scanner release];
	
	return NO;
}

+(NSString *)flattenHtml:(NSString *)html {
	// note that this is open source, originally from:
	// http://www.rudis.net/content/2009/01/21/flatten-html-content-ie-strip-tags-cocoaobjective-c
	// this is pretty rudimentary and needs to be improved a lot!

	html = [html stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	html = [html stringByReplacingOccurrencesOfString:@"<br>" withString:@" \n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	html = [html stringByReplacingOccurrencesOfString:@"<br/>" withString:@" \n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];	html = [html stringByReplacingOccurrencesOfString:@"<br />" withString:@"\n"];
	html = [html stringByReplacingOccurrencesOfString:@"<br />" withString:@" \n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	html = [html stringByReplacingOccurrencesOfString:@"</p>" withString:@"</p>\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	html = [html stringByReplacingOccurrencesOfString:@"</P>" withString:@"</p>\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	html = [html stringByReplacingOccurrencesOfString:@"</div>" withString:@"</div>\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	html = [html stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
	
	NSScanner* styleScanner = [NSScanner scannerWithString:html];
	styleScanner.caseSensitive = NO;
	NSString *text = @"";
    while ([styleScanner isAtEnd] == NO) {
        // find start of tag
        [styleScanner scanUpToString:@"<style" intoString:NULL] ;
		
        // find end of tag
        [styleScanner scanUpToString:@"</style>" intoString:&text] ;
        // replace the found tag with a space
        //(you can filter multi-spaces out later if you wish)
        html = [html stringByReplacingOccurrencesOfString:
				   [ NSString stringWithFormat:@"%@</style>", text] withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
    }
	while ([styleScanner isAtEnd] == NO) {
        // find start of tag
        [styleScanner scanUpToString:@"<title" intoString:NULL] ;
		
        // find end of tag
        [styleScanner scanUpToString:@"</title>" intoString:&text] ;
        // replace the found tag with a space
        //(you can filter multi-spaces out later if you wish)
        html = [html stringByReplacingOccurrencesOfString:
				[ NSString stringWithFormat:@"%@</title>", text] withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, [html length])];
    }
	
	NSString* htmlOut = [html stringByRemovingHTMLTags];
	
    if([htmlOut length] > 0 && ![StringUtil isOnlyWhiteSpace:htmlOut]) {
		return [StringUtil trim:htmlOut];
	}
	
	htmlOut = html;
	
	// remove anything inside <...>
    NSScanner* theScanner = [NSScanner scannerWithString:html];
    while ([theScanner isAtEnd] == NO) {
        // find start of tag
        [theScanner scanUpToString:@"<" intoString:NULL] ;
		
        // find end of tag
        [theScanner scanUpToString:@">" intoString:&text] ;
        // replace the found tag with a space
        //(you can filter multi-spaces out later if you wish)
        htmlOut = [htmlOut stringByReplacingOccurrencesOfString:
				[ NSString stringWithFormat:@"%@>", text] withString:@" "];
    }
	
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\r" withString:@""];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\n \n" withString:@"\n\n"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\n  \n" withString:@"\n\n"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\n\n\n\n\n" withString:@"\n\n"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\n\n\n\n" withString:@"\n\n"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
	
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&auml;" withString:@"ä"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&ouml;" withString:@"ö"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&uuml;" withString:@"ü"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&Auml;" withString:@"Ä"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&Ouml;" withString:@"Ö"];
	htmlOut = [htmlOut stringByReplacingOccurrencesOfString:@"&Uuml;" withString:@"Ü"];
	
	 
	if([htmlOut length] > 0 && ![StringUtil isOnlyWhiteSpace:htmlOut]) {
		return [StringUtil trim:htmlOut];
	}

	return [StringUtil trim:html];
}

NSString* md5( NSString *str ) {
	const char *cStr = [str UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:
			@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
			result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]
			];
} 

@end
