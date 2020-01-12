//
//  AppDelegate+Swizzling.m
//  BushelScript Editor
//
//  Created by Ian Gregory on 26-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "BushelScript_Editor-Swift.h"
#import "OSADictionaryWindowController.h"

@class AppDelegate;

@interface AppDelegate (Swizzling)
@end

__used static void swizzleClassMethod(Class clas, SEL targetSel, SEL newSel) {
    NSLog(@"Swizzling +[%@ %@] -> +%@", NSStringFromClass(clas), NSStringFromSelector(targetSel), NSStringFromSelector(newSel));
    method_exchangeImplementations(class_getClassMethod(clas, targetSel), class_getClassMethod(clas, newSel));
}
static void swizzleInstanceMethod(Class clas, SEL targetSel, SEL newSel) {
    NSLog(@"Swizzling -[%@ %@] -> -%@", NSStringFromClass(clas), NSStringFromSelector(targetSel), NSStringFromSelector(newSel));
    method_exchangeImplementations(class_getInstanceMethod(clas, targetSel), class_getInstanceMethod(clas, newSel));
}

@implementation AppDelegate (Swizzling)

+ (void)initialize {
    swizzleInstanceMethod([NSViewController class], @selector(setRepresentedObject:), @selector(TJC_setRepresentedObject:));
    swizzleInstanceMethod([NSTabViewController class], @selector(tabView:willSelectTabViewItem:), @selector(TJC_tabView:willSelect:));
    swizzleInstanceMethod([NSWindowController class], @selector(windowDidLoad), @selector(TJC_windowDidLoad));
}

@end
