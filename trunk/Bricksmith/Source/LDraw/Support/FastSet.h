//
//  FastSet.h
//  Bricksmith
//
//  Created by Sergey Slobodenyuk on 15.09.21.
//

#import <Foundation/Foundation.h>

@interface FastSet : NSObject {
}

- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (NSEnumerator *)objectEnumerator;

@end
