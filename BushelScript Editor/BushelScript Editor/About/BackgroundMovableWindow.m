#import "BackgroundMovableWindow.h"

@implementation BackgroundMovableWindow

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)__unused style backing:(NSBackingStoreType)backing defer:(BOOL)defer {
    self = [super initWithContentRect:contentRect styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskFullSizeContentView backing:backing defer:defer];
    if (!self) return nil;
    
    return self;
}

- (BOOL)isMovableByWindowBackground {
    return YES;
}
- (BOOL)isOpaque {
    return NO;
}
- (NSColor *)backgroundColor {
    return [NSColor clearColor];
}
- (BOOL)titlebarAppearsTransparent {
    return YES;
}
- (NSWindowTitleVisibility)titleVisibility {
    return NSWindowTitleHidden;
}

@end
