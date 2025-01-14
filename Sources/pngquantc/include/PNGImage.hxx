//
//  Header.h
//
//
//  Created by Radzivon Bartoshyk on 27/04/2022.
//

#ifndef PNGQuantBinding_h
#define PNGQuantBinding_h

#import <Foundation/Foundation.h>
#import "TargetConditionals.h"

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define PNGImage NSImage
#else
#import <UIKit/UIKit.h>
#define PNGImage UIImage
#endif

@interface PNGImage (PngQuant)

- (NSData *_Nullable)pngRGBA:(int)speed;
- (NSData *_Nullable)quantizedImageData:(int)quality speed:(int)speed;
- (NSError *_Nullable)quantizedImageTo:(NSString *_Nonnull)path quality:(int)quality speed:(int)speed;

@end

#endif /* PNGQuantBinding_h */
