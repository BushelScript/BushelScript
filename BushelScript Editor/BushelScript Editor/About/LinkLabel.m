#import "LinkLabel.h"

static bool mouseDown_;

@implementation LinkLabel

@synthesize link = _link;

- (NSString *)link {
    @synchronized (self) {
        return _link ?: self.stringValue;
    }
}
- (void)setLink:(NSString *)link {
    @synchronized (self) {
        _link = link;
    }
}

- (void)mouseDown:(NSEvent *)__unused event {
    mouseDown_ = true;
}
- (void)mouseUp:(NSEvent *)__unused event {
    if (!mouseDown_) return;
    mouseDown_ = false;
    
    [self openLink];
}

- (void)openLink {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:self.link]];
}

@end
