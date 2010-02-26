//
//  StoreObserver.m
//  ReMailIPhone
//
//  Created by Gabor Cselle on 11/11/09.
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

#import "StoreObserver.h"
#import "AppSettings.h"

static StoreObserver *storeSingleton = nil;

@implementation StoreObserver

@synthesize delegate;

#pragma mark Singleton
+ (id)getSingleton { 
	@synchronized(self) {
		if (storeSingleton == nil) {
			storeSingleton = [[self alloc] init];
		}
	}
	return storeSingleton;
}

#pragma mark Internal functions
-(void)recordTransaction:(SKPaymentTransaction*)transaction {
	// fire off a call to our server in an asyncronous manner?
}

-(void)provideFeature:(NSString*)pid {
	NSLog(@"Purchased feature: %@", pid);
	
	// basically, write this into AppSettings
	[AppSettings setFeaturePurchased:pid];
	
	if([pid isEqualToString:@"RM_IMAP"]) {
		// purchasing IMAP support also purchases Rackspace support
		[AppSettings setFeaturePurchased:@"RM_RACKSPACE"];
	}
	//TODO(gabor): Seriously think about whether we want to throw in "no ads" for free :-)

	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(purchased:)]) {
		[self.delegate performSelectorOnMainThread:@selector(purchased:) withObject:pid waitUntilDone:NO];
	}
}

-(void)completeTransaction:(SKPaymentTransaction *)transaction {
	// Your application should implement these two methods.
    [self recordTransaction: transaction];
    [self provideFeature:transaction.payment.productIdentifier];
	// Remove the transaction from the payment queue.
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

-(void)restoreTransaction:(SKPaymentTransaction *)transaction {
    [self recordTransaction: transaction];
    [self provideFeature: transaction.originalTransaction.payment.productIdentifier];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

#pragma mark SKPaymentTransactionObserver Interface
- (void)failedTransaction: (SKPaymentTransaction *)transaction {
	NSLog(@"transaction failed: %@", transaction.error);
    if (transaction.error.code != SKErrorPaymentCancelled) {
		// display error to the user
		if(self.delegate != nil && [self.delegate respondsToSelector:@selector(showError:)]) {
			[self.delegate performSelectorOnMainThread:@selector(showError:) withObject:transaction.error waitUntilDone:NO];
		}        
    } else {
		if(self.delegate != nil && [self.delegate respondsToSelector:@selector(cancelled)]) {
			[self.delegate performSelectorOnMainThread:@selector(cancelled) withObject:nil waitUntilDone:NO];
		}        
	}
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
	// ignore this: Just tells us transaction has been removed from the queue
}

- (void)paymentQueue:(SKPaymentQueue *)queuerestoreCompletedTransactionsFailedWithError:(NSError *)error {
	NSLog(@"Restore failed: %@", error);
	
	// display error to the user	
	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(showError:)]) {
		[self.delegate performSelectorOnMainThread:@selector(showError:) withObject:error waitUntilDone:NO];
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
	// display "restore complete!"
	if(self.delegate != nil && [self.delegate respondsToSelector:@selector(restoreComplete)]) {
		[self.delegate performSelectorOnMainThread:@selector(restoreComplete) withObject:nil waitUntilDone:NO];
	}
}

@end
