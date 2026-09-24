#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>

// Build: clang -fobjc-arc tools/encode_kitchen_walkthrough.m \
//   -framework Foundation -framework AVFoundation -framework ImageIO \
//   -framework CoreGraphics -framework CoreVideo -framework CoreMedia \
//   -o /private/tmp/encode_kitchen_walkthrough

static void fail(NSString *message) {
    fprintf(stderr, "%s\n", message.UTF8String);
    exit(1);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 4) fail(@"Usage: encode_kitchen_walkthrough <frames-directory> <output.mp4> <fps>");
        NSURL *folder = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES];
        NSURL *output = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
        int fps = atoi(argv[3]);
        if (fps < 1) fail(@"FPS must be positive");
        NSError *error = nil;
        NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:folder
            includingPropertiesForKeys:nil options:0 error:&error];
        if (!contents) fail(error.localizedDescription);
        NSPredicate *framesOnly = [NSPredicate predicateWithBlock:^BOOL(NSURL *url, NSDictionary *bindings) {
            return [url.lastPathComponent hasPrefix:@"frame_"] &&
                [url.pathExtension.lowercaseString isEqualToString:@"jpg"];
        }];
        NSArray<NSURL *> *frames = [[contents filteredArrayUsingPredicate:framesOnly]
            sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
                return [a.lastPathComponent compare:b.lastPathComponent];
            }];
        if (frames.count == 0) fail(@"No JPEG frames found");

        CGImageSourceRef firstSource = CGImageSourceCreateWithURL((__bridge CFURLRef)frames[0], NULL);
        CGImageRef first = firstSource ? CGImageSourceCreateImageAtIndex(firstSource, 0, NULL) : NULL;
        if (!first) fail(@"The first frame cannot be read");
        size_t width = CGImageGetWidth(first), height = CGImageGetHeight(first);
        CGImageRelease(first);
        CFRelease(firstSource);

        [[NSFileManager defaultManager] removeItemAtURL:output error:nil];
        AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:output fileType:AVFileTypeMPEG4 error:&error];
        if (!writer) fail(error.localizedDescription);
        NSDictionary *settings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(width),
            AVVideoHeightKey: @(height),
            AVVideoCompressionPropertiesKey: @{
                AVVideoAverageBitRateKey: @5000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            }
        };
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
            outputSettings:settings];
        input.expectsMediaDataInRealTime = NO;
        if (![writer canAddInput:input]) fail(@"Cannot add the video track");
        [writer addInput:input];
        NSDictionary *attributes = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferWidthKey: @(width),
            (id)kCVPixelBufferHeightKey: @(height),
            (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
            (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
        };
        AVAssetWriterInputPixelBufferAdaptor *adaptor =
            [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
                sourcePixelBufferAttributes:attributes];
        if (![writer startWriting]) fail(writer.error.localizedDescription);
        [writer startSessionAtSourceTime:kCMTimeZero];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        for (NSUInteger index = 0; index < frames.count; index++) {
            @autoreleasepool {
                while (!input.readyForMoreMediaData) [NSThread sleepForTimeInterval:0.005];
                CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)frames[index], NULL);
                CGImageRef image = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
                if (!image || CGImageGetWidth(image) != width || CGImageGetHeight(image) != height)
                    fail([NSString stringWithFormat:@"Bad frame: %@", frames[index].path]);
                CVPixelBufferRef buffer = NULL;
                if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool, &buffer) != kCVReturnSuccess)
                    fail(@"Cannot allocate a video frame");
                CVPixelBufferLockBaseAddress(buffer, 0);
                CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(buffer), width, height,
                    8, CVPixelBufferGetBytesPerRow(buffer), colorSpace,
                    kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
                if (!context) fail(@"Cannot draw a video frame");
                CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
                CGContextRelease(context);
                CVPixelBufferUnlockBaseAddress(buffer, 0);
                CMTime timestamp = CMTimeMake((int64_t)index, fps);
                if (![adaptor appendPixelBuffer:buffer withPresentationTime:timestamp])
                    fail([NSString stringWithFormat:@"Cannot append frame %lu: %@", (unsigned long)index,
                        writer.error.localizedDescription ?: @"unknown error"]);
                CVPixelBufferRelease(buffer);
                CGImageRelease(image);
                CFRelease(source);
                if (index % 240 == 0) printf("Encoded %lu/%lu frames\n", (unsigned long)index,
                    (unsigned long)frames.count);
            }
        }
        CGColorSpaceRelease(colorSpace);
        [input markAsFinished];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        if (writer.status != AVAssetWriterStatusCompleted) fail(writer.error.localizedDescription);
        printf("Wrote %s: %lu frames, %zux%zu, %d fps\n", output.path.UTF8String,
            (unsigned long)frames.count, width, height, fps);
    }
    return 0;
}
