// Written in ObjC++ because it was part of a previous project.
// Also we can do cool (and useful) stuff like Credits.inc.

#import "AboutBushelScriptViewController.h"

#import <QuartzCore/CoreAnimation.h>

// MARK: GCD Convenience

#define MAIN_QUEUE dispatch_get_main_queue()
#define GLOBAL_QUEUE(qos_class) dispatch_get_global_queue(qos_class, 0)
#define NEW_QUEUE(name, type, qos_class) dispatch_queue_create(name, dispatch_queue_attr_make_with_qos_class(type, qos_class, 0))
#define NEW_SERIAL_QUEUE(name, qos_class) NEW_QUEUE(name, DISPATCH_QUEUE_SERIAL, qos_class)
#define NEW_CONCURRENT_QUEUE(name, qos_class) NEW_QUEUE(name, DISPATCH_QUEUE_CONCURRENT, qos_class)

#define DISPATCH_AFTER_NANOSECONDS(delay_in_nsecs, queue, block) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay_in_nsecs)), queue, block)
#define DISPATCH_AFTER_MILLISECONDS(delay_in_msecs, queue, block) DISPATCH_AFTER_NANOSECONDS(delay_in_msecs * NSEC_PER_MSEC, queue, block)
#define DISPATCH_AFTER_SECONDS(delay_in_secs, queue, block) DISPATCH_AFTER_NANOSECONDS(delay_in_secs * NSEC_PER_SEC, queue, block)

static const NSTimeInterval kTitleCenterDuration = 0.8,
                            kTitleSlideToLeadingEdgeDuration = 1.0,
                            kCreditsFadeInDuration = 0.6,
                            kVersionFadeInDuration = 0.6,
                            kGitHubLinkFadeInDuration = 0.6,
                            kSupportDevelopmentFadeInDuration = 0.6;
static const NSTimeInterval kCreditsFadeInPriorDuration = 0.1,
                            kVersionFadeInPriorDuration = 0.0,
                            kGitHubLinkFadeInPriorDuration = 0.0,
                            kSupportDevelopmentFadeInPriorDuration = 0.0;

static NSString *const kCreditsStrings[] = {
    @"Next-generation open-source AppleScript",
    @"Created by Ian A. Gregory",
    @"Great thanks to contributors:",
#define X(...) @#__VA_ARGS__,
    #include "Credits.inc"
    @"Open-source libraries used:",
    #include "Libraries.inc"
#undef X
    @""
    };
static const NSTimeInterval kCreditsTransitionDuration = 1.0,
                            kCreditsFirstToSecondItemTransitionDuration = 1.6,
                            kCreditsLastToFirstItemTransitionDuration = 2.6,
                            kCreditsBetweenTransitionDuration = 3.5,
                            kCreditsBetweenTransitionTimerTolerance = 0.2;

@implementation AboutBushelScriptViewController {
    NSTimer *_creditsAnimationTimer;
    int _creditsStringIndex;
    
    __weak IBOutlet NSTextField *_titleLabel;
    __weak IBOutlet NSImageView *_titleIcon;
    __weak IBOutlet NSTextField *_animatedCreditsLabel;
    __weak IBOutlet NSTextField *_versionLabel;
    __weak IBOutlet NSTextField *_gitHubLinkLabel;
    __weak IBOutlet NSTextField *_supportDevelopmentLabel;
    __weak IBOutlet NSTextField *_supportDevelopmentLinkLabel;
    
    IBOutlet NSLayoutConstraint *_centerXTitleToSuper;
    IBOutlet NSLayoutConstraint *_leadingTitleToSuper;
}

- (void)viewDidLoad {
    _leadingTitleToSuper.active = NO;
    _animatedCreditsLabel.stringValue = kCreditsStrings[0];
    _versionLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Version %@", @"Version in About box"), [[NSBundle bundleWithIdentifier:@"com.justcheesy.Bushel"] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    DISPATCH_AFTER_SECONDS(kTitleCenterDuration, MAIN_QUEUE, ^{
        [self performInitialAnimation];
    });
}

- (void)performInitialAnimation {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = kTitleSlideToLeadingEdgeDuration;
        context.allowsImplicitAnimation = YES;
        
        self->_centerXTitleToSuper.active = NO;
        self->_leadingTitleToSuper.active = YES;
        [self.view layoutSubtreeIfNeeded];
        
        self->_titleIcon.animator.hidden = NO;
    } completionHandler:^{
        [self showCreditsLabel];
    }];
}
- (void)showCreditsLabel {
    [self cycleCreditsString];
    
    DISPATCH_AFTER_SECONDS(kCreditsFadeInPriorDuration, MAIN_QUEUE, ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = kCreditsFadeInDuration;
            
            self->_animatedCreditsLabel.animator.hidden = NO;
        } completionHandler:^{
            [self setUpCreditsTimer];
            
            [self showVersionLabel];
        }];
    });
}
- (void)showVersionLabel {
    DISPATCH_AFTER_SECONDS(kVersionFadeInPriorDuration, MAIN_QUEUE, ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = kVersionFadeInDuration;
            
            self->_versionLabel.animator.hidden = NO;
        } completionHandler:^{
            [self showGitHubLinkLabel];
        }];
    });
}
- (void)showGitHubLinkLabel {
    DISPATCH_AFTER_SECONDS(kGitHubLinkFadeInPriorDuration, MAIN_QUEUE, ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = kGitHubLinkFadeInDuration;
            
            self->_gitHubLinkLabel.animator.hidden = NO;
        } completionHandler:^{
            [self showSupportDevelopmentLabel];
        }];
    });
}
- (void)showSupportDevelopmentLabel {
    DISPATCH_AFTER_SECONDS(kSupportDevelopmentFadeInPriorDuration, MAIN_QUEUE, ^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = kSupportDevelopmentFadeInDuration;
            
            self->_supportDevelopmentLabel.animator.hidden = NO;
            self->_supportDevelopmentLinkLabel.animator.hidden = NO;
        } completionHandler:nil];
    });
}

- (void)setUpCreditsTimer {
    _creditsAnimationTimer = [NSTimer scheduledTimerWithTimeInterval:kCreditsBetweenTransitionDuration target:self selector:@selector(performCreditsAnimation:) userInfo:nil repeats:YES];
    _creditsAnimationTimer.tolerance = kCreditsBetweenTransitionTimerTolerance;
}

- (void)performCreditsAnimation:(NSTimer *)__unused timer {
    static CATransition *animation;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        animation = [CATransition animation];
        animation.type = kCATransitionPush;
        animation.subtype = kCATransitionFromBottom;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    });
    
    animation.duration =
        (_creditsStringIndex == 1) ?
        kCreditsFirstToSecondItemTransitionDuration :
        (_creditsStringIndex == sizeof kCreditsStrings / sizeof kCreditsStrings[0]) ?
        kCreditsLastToFirstItemTransitionDuration :
        kCreditsTransitionDuration;
    
    // Sometimes the animation gets (seemingly randomly) deleted from the text field, so just add it back every time
    [_animatedCreditsLabel.layer addAnimation:animation forKey:kCATransition];
    
    [self cycleCreditsString];
}

- (void)cycleCreditsString {
    _animatedCreditsLabel.stringValue = (_creditsStringIndex < 3) ? // Only localize non-names
        NSLocalizedString(kCreditsStrings[_creditsStringIndex], nil) :
        kCreditsStrings[_creditsStringIndex];
    
    _creditsStringIndex++;
    if (_creditsStringIndex >= sizeof kCreditsStrings / sizeof kCreditsStrings[0]) {
        _creditsStringIndex = 0;
    }
}

@end
