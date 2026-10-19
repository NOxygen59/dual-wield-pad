#import <Preferences/PSListController.h>
#import <notify.h>

@interface DWPRootListController : PSListController
@end

@implementation DWPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

/// The tweak (in SpringBoard) stores the angle the screen is at now as the reference.
- (void)useCurrentAngle {
    notify_post("com.dualwieldpad/capture");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self reloadSpecifiers];
    });
}

@end
