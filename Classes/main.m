//
//  main.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 2/26/09.
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

void sig_handler (int sig)
{
	//TODO(gabor): Really do this?
    signal(SIGPIPE, SIG_IGN);  /* completely block the signal */
	switch(sig)
	{
		case SIGPIPE:
			NSLog(@"Caught a SIG_PIPE");
		    /* do stuff here */
		    break;
		case  SIGABRT:
		    /* do stuff here */
		    break;
		default:
		    break;    
	} 
	signal(SIGPIPE, sig_handler); /* restore signal handling */
}


int main(int argc, char *argv[]) {
	signal(SIGPIPE, sig_handler);

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}
