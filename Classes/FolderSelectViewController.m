//
//  FolderSelectViewController.m
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

#import "FolderSelectViewController.h"
#import "HomeViewController.h"
#import "AppSettings.h"
#import "SyncManager.h"
#import "EmailProcessor.h"
#import "StringUtil.h"

#define BASE64_UNIT_SIZE 4

//
// Mapping from ASCII character to 6 bit pattern.
//
// The "xx"s in this table are just a #define of 65 (i.e. outside the
// valid range of Base64) but they provide an interesting visual
// representation of the 6-bits that each Base64 character can occupy
// within the 8-bit byte.
//
#define xx 65
static unsigned char base64DecodeLookup[256] =
{
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 62, xx, xx, xx, 63,  
  52, 53, 54, 55, 56, 57, 58, 59, 60, 61, xx, xx, xx, xx, xx, xx, 
  xx,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 
  15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, xx, xx, xx, xx, xx, 
  xx, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
  41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, 
};

size_t addDecodedCharacters(
  unsigned char *outBuf,
  size_t to,
  const unsigned char *accumulated,
  size_t length
)
{
  // cleared accumulated, so any bytes beyond [i] are 0, and thus safe to include
  // but we don't want to keep incrementing 'to' if we don't have characters
  size_t i = to;
  outBuf[i++] = (accumulated[0] << 2) | (accumulated[1] >> 4);
  if (length>1) outBuf[i++] = (accumulated[1] << 4) | (accumulated[2] >> 2);
  if (length>3) outBuf[i++] = (accumulated[2] << 6) | (accumulated[3]);
  NSLog( @"decoded characters: %x %x %x",
         (int)outBuf[to],
         (length>1) ? (int)outBuf[to+1] : ' ',
         (length>3) ? (int)outBuf[to+2] : ' '
  );
  return i - to;
}

/*
 * imap uses modified BASE64 encoded UTF-16 strings
 * network-byte-order (big endian - NSUTF16BigEndianStringEncoding) 
 * but with ',' instead of '/' and allowing a few more characters
 * to be un-escaped ("IMAP/modified UTF-7" defined in rfc3501 5.1.3 citing rfc 2152)
 *
 * Python code:
 *   http://www.koders.com/python/fid744B4E448B1689C0963942A7928FA049084FAC86.aspx?s=search
 *
 * Perl docs:
 *    http://search.cpan.org/~pmakholm/Encode-IMAPUTF7-1.04/lib/Encode/IMAPUTF7.pm
 *
 * Base64 on mac/iPhone:
 *    http://cocoawithlove.com/2009/06/base64-encoding-options-on-mac-and.html
 */
NSString* imapUTF7Decode(NSString* in)
{
  // UTF7 is an all-ASCII format, by design
  const char *inBuf = [in cStringUsingEncoding: NSASCIIStringEncoding]; 
  size_t inLength = inBuf ? strlen( inBuf ) : 0;
  
  // outBuf needs to be UTF-16 (so twice inLength). actual characters in
  // outBuf may be shorter than inBuf characters, because of the 4::3 decoding
  unsigned char *outBuf = (unsigned char*)malloc( 2*inLength );
  NSString *out;

  unsigned char accumulated[BASE64_UNIT_SIZE]; // block of chars to translate at once
  unsigned char cur; // most recent BASE64 char to decode
  unsigned char decode; // decoded single BASE64 char value

  size_t from = 0; // index into inBuf. goes up to inLength
  size_t to = 0; // index into outBuf. Always less than inLength
  size_t i = 0; //index into accumulated
  int accumulating = 0;
  int timeToAdd = 0;

  if ( !outBuf ) {
    NSLog( @"Unable to allocate memory for decoded string or unknown encoding of input data: %p:%@", inBuf, in );
    return in; // best option available?  unique, maybe-recognizable string
  }

  memset( accumulated, 0, sizeof accumulated );
  while ( from < inLength ) // could do pointer arithmetic through this...
  {
    cur = inBuf[from++];
    if ( cur == '&' )
    {
      accumulating = 1;
      // don't add this character
    }
    else if ( !accumulating )
    {
      // not accumulating, just copy the character
      outBuf[to++] = 0;
      outBuf[to++] = cur;
    }
    else
    {
      if ( cur == '-' )
      {
        // end of block
        accumulating = 0;
        if ( i == 0 ) // only character
        {
          outBuf[to++] = 0;
          outBuf[to++] = '&';
        }
        else
        {
          timeToAdd = 1;
        }
      }
      else
      {
        decode = base64DecodeLookup[cur];
        if ( decode == xx ) 
        {
          // skip over invalid characters, like linefeeds, etc.
          // needed for general BASE64, but probably not this case
          NSLog( @"Unexpected character in UTF-7: %c", cur );
        }
        else
        {
          accumulated[i++] = decode;
          if ( i >= BASE64_UNIT_SIZE )
          {
            timeToAdd = 1;
          }
        }
      }
      if ( timeToAdd )
      {
        timeToAdd = 0;
        to += addDecodedCharacters( outBuf, to, accumulated, i );
        memset( accumulated, 0, sizeof accumulated );
        i = 0;
      }
    }
  }

  if ( accumulating && i )
  {
    to += addDecodedCharacters( outBuf, to, accumulated, i );
  }
  
  // if all went well, we now have a UTF16 Big-Endian string.
  out = [[NSString alloc]
            initWithBytes: outBuf
                   length: to
                 encoding:NSUTF16BigEndianStringEncoding];
  free( outBuf );
  
  return out;
}
    
@implementation FolderSelectViewController

@synthesize utf7Decoder;
@synthesize folderPaths;
@synthesize folderSelected;
@synthesize username;
@synthesize password;
@synthesize server;

@synthesize encryption;
@synthesize port;
@synthesize authentication;

@synthesize accountNum;
@synthesize newAccount;
@synthesize firstSetup;

-(void)dealloc {
	[utf7Decoder release];
	[folderPaths release];
	[folderSelected release];
	
	[username release];
	[password release];
	[server release];
	
    [super dealloc];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	self.utf7Decoder = nil;
	self.folderPaths = nil;
	self.folderSelected = nil;
	
	self.username = nil;
	self.password = nil;
	self.server = nil;
}

-(void)openRemail {
	// display home screen
	HomeViewController *homeController = [[HomeViewController alloc] initWithNibName:@"HomeView" bundle:nil];
	UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:homeController];
	navController.navigationBarHidden = NO;
	[self.view.window addSubview:navController.view];
	[homeController release];
	
	// Remove own view from screen stack
	[self.view removeFromSuperview];
}

-(NSString*)imapFolderNameToDisplayName:(NSString*)folderPath {
	if([folderPath isEqualToString:@"INBOX"]) {
		return @"Inbox"; // TODO(gabor): Localize name
	}

        NSLog( @"Folder Path: %@", folderPath );
	if(![StringUtil stringContains:folderPath subString:@"&"]) {
		return folderPath;
	}
	
	NSString* display = imapUTF7Decode( folderPath );
        NSLog(@"Final: %@", display);	
	return display;
}

-(void)done {
	if([self.folderSelected count] == 0) {
		UIAlertView* alertView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Folders Selected", nil) 
															 message:NSLocalizedString(@"Need to select at least one folder to download.", nil) 
															delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
		[alertView show];
		
		return;
	}
		
	SyncManager *sm = [SyncManager getSingleton];
	
	if(self.newAccount) {
		[sm addAccountState];
		[AppSettings setAccountType:AccountTypeImap accountNum:self.accountNum];
		[AppSettings setUsername:self.username accountNum:self.accountNum];
		[AppSettings setPassword:self.password accountNum:self.accountNum];
		[AppSettings setServerAuthentication:self.authentication accountNum:self.accountNum];
		[AppSettings setServer:self.server accountNum:self.accountNum];
		[AppSettings setServerPort:self.port accountNum:self.accountNum];
		[AppSettings setServerEncryption:self.encryption accountNum:self.accountNum];
		
		if(self.firstSetup) {
			[AppSettings setDataInitVersion];
		}
		
		int i = 0;
		for(NSString* folderPath in self.folderPaths) {
			if(![self.folderSelected containsObject:folderPath]) {
				continue;
			}
			
			NSString* folderDisplayName = [self imapFolderNameToDisplayName:folderPath];
			if ([StringUtil stringContains:folderDisplayName subString:@"&"]) {
				folderDisplayName = @"";
			} 
		 	NSLog( @"generated folder display name: %@ for %@", folderDisplayName, folderPath );
			NSMutableDictionary* folderState = [NSMutableDictionary dictionaryWithObjectsAndKeys:
													[NSNumber numberWithInt:0], @"accountNum", 
													folderDisplayName, @"folderDisplayName",
													folderPath, @"folderPath",
													[NSNumber numberWithBool:NO], @"deleted", 
													nil];
			
			if (i < [EmailProcessor folderCountLimit]-1) { // only add up do 1000 folders!
				[sm addFolderState:folderState accountNum:self.accountNum];
			}
			
			i++;
		}
		
		if(self.firstSetup) {
			[self openRemail];
		} else {
			[self.navigationController popToRootViewControllerAnimated:YES];
		}
		return;
	} else {
		// calculate the delta between current folders and the selected ones
		NSMutableSet* syncedFolders = [NSMutableSet set];
		
		for(int i = 0; i < [sm folderCount:self.accountNum]; i++) {
			if(![sm isFolderDeleted:i accountNum:self.accountNum]) {
				NSString* folderPath = [[sm retrieveState:i accountNum:self.accountNum] objectForKey:@"folderPath"];
				[syncedFolders addObject:folderPath];
			}
		}
		
		NSMutableSet* toDelete = [syncedFolders mutableCopy];
		[toDelete minusSet:self.folderSelected];
		
		for(int i = 0; i < [sm folderCount:self.accountNum]; i++) {
			if(![sm isFolderDeleted:i accountNum:self.accountNum]) {
				NSString* folderPath = [[sm retrieveState:i accountNum:self.accountNum] objectForKey:@"folderPath"];
				if([toDelete containsObject:folderPath]) {
					[sm markFolderDeleted:i accountNum:self.accountNum];
				}
			}
		}
		[toDelete release];
		
		NSMutableSet* toAdd = [self.folderSelected mutableCopy];
		[toAdd minusSet:syncedFolders];
		
		for(NSString* folderPath in toAdd) {
			NSString* folderDisplayName = folderPath;
			if([folderPath isEqualToString:@"INBOX"]) {
				folderDisplayName = @"Inbox"; // TODO(gabor): Localize name
			} else {
              folderDisplayName = [self imapFolderNameToDisplayName:folderPath];
              if ([StringUtil stringContains:folderDisplayName subString:@"&"]) {
				folderDisplayName = @"";
              }
			}
			
			NSMutableDictionary* folderState = [NSMutableDictionary dictionaryWithObjectsAndKeys:
												[NSNumber numberWithInt:0], @"accountNum", 
												folderDisplayName, @"folderDisplayName",
												folderPath, @"folderPath",
												[NSNumber numberWithBool:NO], @"deleted", 
												nil];
			
			if ([sm folderCount:self.accountNum] < [EmailProcessor folderCountLimit]-2) {
				[sm addFolderState:folderState accountNum:self.accountNum];
			}
		}
		[toAdd release]; //mutableCopy actually retains the data in it!
		
		[self.navigationController popToRootViewControllerAnimated:YES];
		return;
	}
}

-(void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedString(@"Folders", nil);
	self.navigationItem.prompt = NSLocalizedString(@"Select folders to download.", nil);
	
	self.utf7Decoder = [NSDictionary dictionaryWithObjectsAndKeys:
						@"À", @"&AMA-",
						@"Á", @"&AME-",
						@"Â", @"&AMI-",
						@"Ã", @"&AMM-",
						@"Ä", @"&AMQ-",
						@"Å", @"&AMU-",
						@"Æ", @"&AMY-",
						@"Ç", @"&AMc-",
						@"È", @"&AMg-",
						@"É", @"&AMk-",
						@"Ê", @"&AMo-",
						@"Ë", @"&AMs-",
						@"Ì", @"&AMw-",
						@"Í", @"&AM0-",
						@"Î", @"&AM4-",
						@"Ï", @"&AM8-",
						@"Ñ", @"&ANE-",
						@"Ò", @"&ANI-",
						@"Ó", @"&ANM-",
						@"Ô", @"&ANQ-",
						@"Õ", @"&ANU-",
						@"Ö", @"&ANY-",
						@"Ø", @"&ANg-",
						@"Ù", @"&ANk-",
						@"Ú", @"&ANo-",
						@"Û", @"&ANs-",
						@"Ü", @"&ANw-",
						@"ß", @"&AN8-",
						@"à", @"&AOA-",
						@"á", @"&AOE-",
						@"â", @"&AOI-",
						@"ã", @"&AOM-",
						@"ä", @"&AOQ-",
						@"å", @"&AOU-",
						@"æ", @"&AOY-",
						@"ç", @"&AOc-",
						@"è", @"&AOg-",
						@"é", @"&AOk-",
						@"ê", @"&AOo-",
						@"ë", @"&AOs-",
						@"ì", @"&AOw-",
						@"í", @"&AO0-",
						@"î", @"&AO4-",
						@"ï", @"&AO8-",
						@"ò", @"&API-",
						@"ó", @"&APM-",
						@"ô", @"&APQ-",
						@"õ", @"&APU-",
						@"ö", @"&APY-",
						@"ù", @"&APk-",
						@"ú", @"&APo-",
						@"û", @"&APs-",
						@"ü", @"&APw-", nil];
	
	self.folderSelected = [NSMutableSet set];
	
	if(!self.newAccount) {
		SyncManager *sm = [SyncManager getSingleton];
		for(int i = 0; i < [sm folderCount:self.accountNum]; i++) {
			if([sm isFolderDeleted:i accountNum:self.accountNum]) {
				continue;
			}
			
			NSString* folderPath = [[sm retrieveState:i accountNum:self.accountNum] objectForKey:@"folderPath"];
			[self.folderSelected addObject:folderPath];
		}
	} else {
		// pre-select Inbox and Sent Messages
		for(NSString* folderPath in self.folderPaths) {
			if([folderPath isEqualToString:@"INBOX"]) {
				[self.folderSelected addObject:folderPath];
			}
			
			int cutaway = 0;
			if([StringUtil stringStartsWith:folderPath subString:@"[Gmail]/"]) {
				cutaway = [@"[Gmail]/" length];
			} else if ([StringUtil stringStartsWith:folderPath subString:@"[Google Mail]/"]) {
				cutaway = [@"[Google Mail]/" length];
			}
			
			if(cutaway > 0) {
				NSString* stringAfterCut = [folderPath substringFromIndex:cutaway];
				
				// include sent folder as well
				if([stringAfterCut isEqualToString:@"Sent Mail"] ||
				   [stringAfterCut isEqualToString:@"Gesendet"] ||
				   [stringAfterCut isEqualToString:@"Messages envoy&AOk-s"]) {
					[self.folderSelected addObject:folderPath];
				}  
			}
			
		}
	}
	
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self.folderPaths count] + 1;
}


-(UITableViewCell*) createNewFolderNameCell { 
	UITableViewCell* cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FolderNameCell"] autorelease];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
	
	return cell; 
} 

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.row == 0) {
		cell.backgroundColor = [UIColor lightGrayColor];
	}
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell* cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"FolderNameCell"];
	if (cell == nil) {
		cell = [self createNewFolderNameCell];
	}

	if(indexPath.row == 0) {
		cell.imageView.image = nil;
		cell.textLabel.text = NSLocalizedString(@"Select All", nil);
		
		return cell;
	}
	
	NSString* folderPath = [self.folderPaths objectAtIndex:indexPath.row - 1]; 
	
	BOOL selected = [self.folderSelected containsObject:folderPath];
	
	// Take care of Umlauts
	NSString* display = [self imapFolderNameToDisplayName:folderPath];
	cell.textLabel.text = display;	
	
	if(selected) {
		cell.imageView.image = [UIImage imageNamed:@"checkboxChecked.png"];
	} else {
		cell.imageView.image = [UIImage imageNamed:@"checkbox.png"];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if(indexPath.row == 0) {
		for(NSString* folderPath in folderPaths) {
			
			int cutaway = 0;
			if([StringUtil stringStartsWith:folderPath subString:@"[Gmail]/"]) {
				cutaway = [@"[Gmail]/" length];
			} else if ([StringUtil stringStartsWith:folderPath subString:@"[Google Mail]/"]) {
				cutaway = [@"[Google Mail]/" length];
			}
			
			if(cutaway > 0) {
				NSString* stringAfterCut = [folderPath substringFromIndex:cutaway];
				
				// include sent folder as well
				if(!([stringAfterCut isEqualToString:@"Sent Mail"] ||
					 [stringAfterCut isEqualToString:@"Gesendet"] ||
					 [stringAfterCut isEqualToString:@"Messages envoy&AOk-s"])) {
					continue;
				}  
			}
			
			BOOL selected = [self.folderSelected containsObject:folderPath];
			
			if(!selected) {
				[self.folderSelected addObject:folderPath];
			}
		}
		[self.tableView reloadData];
	} else {
		int folderIndex = indexPath.row - 1;
		NSString* folderPath = [self.folderPaths objectAtIndex:folderIndex];
		BOOL selected = [self.folderSelected containsObject:folderPath];
		
		if(selected) {
			[self.folderSelected removeObject:folderPath];
		} else {
			[self.folderSelected addObject:folderPath];
		}
		
		[self.tableView reloadData];
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}
@end
