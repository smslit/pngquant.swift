//
//  PNGQuantBinding.m
//  
//
//  Created by Radzivon Bartoshyk on 27/04/2022.
//

#include "PNGQuantBinding.h"
#include "libimagequant.h"
#include "lodepng.h"

@implementation UIImage (ColorData)

- (unsigned char *)rgbaPixels {
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    return rawData;
}

@end


NSData * quantizedImageData(UIImage *image, int speed)
{
    CGImageRef imageRef = image.CGImage;
    
    size_t _bitsPerPixel           = CGImageGetBitsPerPixel(imageRef);
    size_t _bitsPerComponent       = CGImageGetBitsPerComponent(imageRef);
    int _width = (int)(image.size.width * image.scale);
    int _height = (int)(image.size.height * image.scale);
    size_t _bytesPerRow            = CGImageGetBytesPerRow(imageRef);
    
    unsigned char *bitmap = [image rgbaPixels];
    
    size_t _gamma = 0;
    
    //create liq attribute
    liq_attr *liq = liq_attr_create();
    liq_set_speed(liq, MAX(MIN(speed, 10), 1));
    
    liq_image *img = liq_image_create_rgba(liq,
                                           (void **)bitmap,
                                           (int)_width,
                                           (int)_height,
                                           _gamma);
    
    if (!img)
    {
        free(bitmap);
        return nil;
    }
    
    liq_result *quantization_result;
    if (liq_image_quantize(img, liq, &quantization_result) != LIQ_OK)
    {
        free(bitmap);
        return nil;
    }
    
    size_t pixels_size = _width * _height;
    unsigned char *raw_8bit_pixels = malloc(pixels_size);
    liq_set_dithering_level(quantization_result, 1.0);
    
    liq_write_remapped_image(quantization_result, img, raw_8bit_pixels, pixels_size);
    const liq_palette *palette = liq_get_palette(quantization_result);
    
    //save convert pixels to png file
    LodePNGState state;
    lodepng_state_init(&state);
    state.info_raw.colortype = LCT_PALETTE;
    state.info_raw.bitdepth = 8;
    state.info_png.color.colortype = LCT_PALETTE;
    state.info_png.color.bitdepth = 8;
    
    for (size_t i = 0; i < palette->count; ++i)
    {
        lodepng_palette_add(&state.info_png.color, palette->entries[i].r, palette->entries[i].g, palette->entries[i].b, palette->entries[i].a);
        
        lodepng_palette_add(&state.info_raw, palette->entries[i].r, palette->entries[i].g, palette->entries[i].b, palette->entries[i].a);
    }
    
    unsigned char *output_file_data;
    size_t output_file_size;
    unsigned int out_state = lodepng_encode(&output_file_data,
                                            &output_file_size,
                                            raw_8bit_pixels,
                                            (int)_width,
                                            (int)_height,
                                            &state);
    
    if (out_state)
    {
        NSLog(@"error can't encode image %s", lodepng_error_text(out_state));
        if (raw_8bit_pixels) {
            free(raw_8bit_pixels);
        }
        free(bitmap);
        return nil;
    }
    
    NSData *data_out = [[NSData alloc] initWithBytes:output_file_data length:output_file_size];
    
    liq_result_destroy(quantization_result);
    liq_image_destroy(img);
    liq_attr_destroy(liq);
    
    free(raw_8bit_pixels);
    free(bitmap);
    
    lodepng_state_cleanup(&state);
    
    return data_out;
}

NSError * _Nullable quantizedImageTo(NSString * _Nonnull path, UIImage * _Nonnull image, int speed)
{
    CGImageRef imageRef = image.CGImage;
    
    size_t _bitsPerPixel           = CGImageGetBitsPerPixel(imageRef);
    size_t _bitsPerComponent       = CGImageGetBitsPerComponent(imageRef);
    int _width = (int)(image.size.width * image.scale);
    int _height = (int)(image.size.height * image.scale);
    size_t _bytesPerRow            = CGImageGetBytesPerRow(imageRef);
    
    unsigned char *bitmap = [image rgbaPixels];
    
    size_t _gamma = 0;
    
    //create liq attribute
    liq_attr *liq = liq_attr_create();
    liq_set_speed(liq, MAX(MIN(speed, 10), 1));
    liq_image *img = liq_image_create_rgba(liq,
                                           (void *)bitmap,
                                           (int)_width,
                                           (int)_height,
                                           _gamma);
    
    if (!img)
    {
        free(bitmap);
        return [[NSError alloc] initWithDomain:@"quantizedImageTo" code:500 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"`quantizedImageTo` failed with create image", nil) }];;
    }
    
    liq_result *quantization_result;
    if (liq_image_quantize(img, liq, &quantization_result) != LIQ_OK)
    {
        free(bitmap);
        return [[NSError alloc] initWithDomain:@"quantizedImageTo" code:500 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"`liq_image_quantize` failed", nil) }];;
    }
    
    size_t pixels_size = _width * _height;
    unsigned char *raw_8bit_pixels = malloc(pixels_size);
    liq_set_dithering_level(quantization_result, 1.0);
    
    liq_write_remapped_image(quantization_result, img, raw_8bit_pixels, pixels_size);
    const liq_palette *palette = liq_get_palette(quantization_result);
    
    //save convert pixels to png file
    LodePNGState state;
    lodepng_state_init(&state);
    state.info_raw.colortype = LCT_PALETTE;
    state.info_raw.bitdepth = 8;
    state.info_png.color.colortype = LCT_PALETTE;
    state.info_png.color.bitdepth = 8;
    
    for(int i=0; i < palette->count; i++) {
        lodepng_palette_add(&state.info_png.color, palette->entries[i].r, palette->entries[i].g, palette->entries[i].b, palette->entries[i].a);
        lodepng_palette_add(&state.info_raw, palette->entries[i].r, palette->entries[i].g, palette->entries[i].b, palette->entries[i].a);
    }
    
    unsigned char *output_file_data;
    size_t output_file_size;
    unsigned int out_state = lodepng_encode(&output_file_data,
                                            &output_file_size,
                                            raw_8bit_pixels,
                                            (int)_width,
                                            (int)_height,
                                            &state);
    
    if (out_state)
    {
        if (raw_8bit_pixels) {
            free(raw_8bit_pixels);
        }
        free(bitmap);
        NSLog(@"error can't encode image %s", lodepng_error_text(out_state));
        return [[NSError alloc] initWithDomain:@"quantizedImageTo" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithUTF8String:lodepng_error_text(out_state)] }];;
    }
    
    if (lodepng_save_file(output_file_data, output_file_size, [path UTF8String]) != LIQ_OK) {
        free(raw_8bit_pixels);
        free(bitmap);
        return [[NSError alloc] initWithDomain:@"quantizedImageTo" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"LODE PNG SAVE FILE ERROR" }];;
    }
    
    liq_result_destroy(quantization_result);
    liq_image_destroy(img);
    liq_attr_destroy(liq);
    
    free(raw_8bit_pixels);
    free(bitmap);
    
    lodepng_state_cleanup(&state);
    
    return nil;
}
