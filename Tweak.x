// Dual Wield Pad: as an iPad on a Magic Keyboard closes, the whole screen (SpringBoard's windows,
// which also show the apps) is warped in perspective so that, from the viewer's seat, the picture
// stays where it was at the reference angle. An iPad take on hrtowii's dual-wield (MacBooks).
//
// - The hinge angle comes from gravity (the keyboard lying flat): no hinge sensor needed.
// - The warp is each window layer's sublayerTransform: no screen capture, nothing re-rendered.
// - Armed once the screen opens past the reference angle; closing below it starts the effect,
//   opening past it again restores the screen (as dual-wield does).

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import <GameController/GameController.h>
#import <notify.h>

#include "DWGeometry.h"

#define DW_DOMAIN @"com.dualwieldpad.prefs"
#define DW_RELOAD "com.dualwieldpad/reload"
#define DW_CAPTURE "com.dualwieldpad/capture"

@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@end

@interface UIWindow (DWPrivate)
+ (NSArray<UIWindow *> *)allWindowsIncludingInternalWindows:(BOOL)internal onlyVisibleWindows:(BOOL)visible;
@end

@interface SpringBoard : UIApplication
@end

typedef NS_ENUM(NSInteger, DWHingeEdge) { DWHingeBottom, DWHingeTop, DWHingeLeft, DWHingeRight };

/// A window layer's own values, put back when the effect ends.
@interface DWSaved : NSObject
@property (nonatomic) CATransform3D sublayerTransform;
@property (nonatomic, copy) NSArray *filters;
@property (nonatomic) float opacity;
@end

@implementation DWSaved
@end

@interface DWController : NSObject
+ (instancetype)shared;
- (void)start;
@end

@implementation DWController {
    CMMotionManager *_motion;
    double _gx, _gy, _gz;
    BOOL _haveGravity;
    double _angle;
    BOOL _armed, _active, _blanked;
    /// A hardware keyboard is connected (GameController announces it after the framework loads).
    BOOL _keyboard;
    // Settings.
    BOOL _enabled, _needsKeyboard;
    double _threshold, _distance, _eyeHeight, _blur;
    NSMapTable<CALayer *, DWSaved *> *_saved;
    DWPoint _lastQuad[4];
    BOOL _haveQuad;
}

+ (instancetype)shared {
    static DWController *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [DWController new];
    });
    return shared;
}

- (void)start {
    _saved = [NSMapTable weakToStrongObjectsMapTable];
    [self loadSettings];
    _keyboard = GCKeyboard.coalescedKeyboard != nil;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:GCKeyboardDidConnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self->_keyboard = YES;
    }];
    [center addObserverForName:GCKeyboardDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        self->_keyboard = GCKeyboard.coalescedKeyboard != nil;
    }];
    int token;
    notify_register_dispatch(DW_RELOAD, &token, dispatch_get_main_queue(), ^(int t) {
        [self loadSettings];
        [self updateMotion];
    });
    notify_register_dispatch(DW_CAPTURE, &token, dispatch_get_main_queue(), ^(int t) {
        [self captureThreshold];
    });
    // No sensor reading while the screen is off.
    notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &token, dispatch_get_main_queue(), ^(int t) {
        uint64_t state = 0;
        notify_get_state(t, &state);
        self->_blanked = state != 0;
        [self updateMotion];
    });
    [self updateMotion];
}

- (void)loadSettings {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:DW_DOMAIN];
    [d registerDefaults:@{
        @"enabled": @YES,
        @"needsKeyboard": @YES,
        @"threshold": @105.0,
        @"distance": @2.4,
        @"eyeHeight": @0.6,
        @"blur": @8.0,
    }];
    _enabled = [d boolForKey:@"enabled"];
    _needsKeyboard = [d boolForKey:@"needsKeyboard"];
    _threshold = fmin(fmax([d doubleForKey:@"threshold"], 60), 160);
    _distance = fmin(fmax([d doubleForKey:@"distance"], 0.8), 6);
    _eyeHeight = fmin(fmax([d doubleForKey:@"eyeHeight"], 0), 1.5);
    _blur = fmin(fmax([d doubleForKey:@"blur"], 0), 40);
}

/// Settings › Dual Wield Pad › Use Current Angle: the angle now becomes the reference.
- (void)captureThreshold {
    if (!_haveGravity || !isfinite(_angle)) {
        return;
    }
    double angle = fmin(fmax(round(_angle), 60), 160);
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:DW_DOMAIN];
    [d setDouble:angle forKey:@"threshold"];
    [d synchronize];
    _threshold = angle;
    _armed = YES;
}

- (void)updateMotion {
    BOOL run = _enabled && !_blanked;
    if (!_motion) {
        _motion = [CMMotionManager new];
    }
    if (run && !_motion.accelerometerActive && _motion.accelerometerAvailable) {
        _motion.accelerometerUpdateInterval = 1.0 / 60.0;
        [_motion startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *data, NSError *error) {
            if (data) {
                [self sample:data.acceleration];
            }
        }];
    } else if (!run && _motion.accelerometerActive) {
        [_motion stopAccelerometerUpdates];
        _haveGravity = NO;
        [self restore];
    }
}

- (void)sample:(CMAcceleration)a {
    // Gravity: the acceleration low-passed (typing and small knocks don't move the picture).
    const double k = 0.18;
    if (!_haveGravity) {
        _gx = a.x, _gy = a.y, _gz = a.z;
        _haveGravity = YES;
    } else {
        _gx += k * (a.x - _gx), _gy += k * (a.y - _gy), _gz += k * (a.z - _gz);
    }
    _angle = DWHingeAngle(_gx, _gy, _gz);
    double g = sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    // Held in the hands, carried, or no keyboard: the angle isn't the hinge's.
    BOOL steady = g > 0.85 && g < 1.15 && isfinite(_angle);
    BOOL keyboard = !_needsKeyboard || _keyboard || GCKeyboard.coalescedKeyboard != nil;
    if (!_enabled || !steady || !keyboard) {
        [self restore];
        return;
    }
    if (_angle >= _threshold) {
        [self restore];
        _armed = YES;
        return;
    }
    if (_armed && (_active || _angle < _threshold - 1.0)) {
        _active = YES;
        [self applyClosing:(_threshold - _angle) * M_PI / 180.0];
    }
}

/// The edge of the screen nearest the ground (the hinge), from gravity in the screen's plane.
- (DWHingeEdge)hingeEdge {
    if (fabs(_gy) >= fabs(_gx)) {
        return _gy < 0 ? DWHingeBottom : DWHingeTop;
    }
    return _gx < 0 ? DWHingeLeft : DWHingeRight;
}

/// A point in hinge coordinates (u along the hinge from the viewer's left, v up the screen) in the
/// screen's fixed (portrait, y down) coordinates.
static CGPoint DWToFixed(DWPoint p, DWHingeEdge edge, CGSize fixed) {
    switch (edge) {
        case DWHingeBottom: return CGPointMake(p.x, fixed.height - p.y);
        case DWHingeTop: return CGPointMake(fixed.width - p.x, p.y);
        case DWHingeLeft: return CGPointMake(p.y, p.x);
        case DWHingeRight: return CGPointMake(fixed.width - p.y, fixed.height - p.x);
    }
    return CGPointMake(p.x, p.y);
}

- (NSArray<UIWindow *> *)windows {
    if ([UIWindow respondsToSelector:@selector(allWindowsIncludingInternalWindows:onlyVisibleWindows:)]) {
        return [UIWindow allWindowsIncludingInternalWindows:YES onlyVisibleWindows:YES];
    }
    NSMutableArray *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    return windows;
}

- (void)applyClosing:(double)closeRadians {
    UIScreen *screen = UIScreen.mainScreen;
    id<UICoordinateSpace> fixedSpace = screen.fixedCoordinateSpace;
    CGSize fixed = fixedSpace.bounds.size;
    DWHingeEdge edge = [self hingeEdge];
    BOOL sideways = edge == DWHingeLeft || edge == DWHingeRight;
    double width = sideways ? fixed.height : fixed.width;
    double height = sideways ? fixed.width : fixed.height;

    DWPoint quad[4];
    if (DWProjectCorners(width, height, _distance * height, _eyeHeight * height, closeRadians, quad)) {
        memcpy(_lastQuad, quad, sizeof quad);
        _haveQuad = YES;
    } else if (_haveQuad) {
        // Nearly closed: keep the last warp (the picture fades out meanwhile).
        memcpy(quad, _lastQuad, sizeof quad);
    } else {
        return;
    }
    const DWPoint rect[4] = {{0, 0}, {width, 0}, {width, height}, {0, height}};
    double progress = fmin(fmax(closeRadians / (_threshold * M_PI / 180.0), 0), 1);
    // Fades out over the last 20 degrees before closed.
    float fade = (float)fmin(fmax(_angle / 20.0, 0), 1);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UIWindow *window in [self windows]) {
        CALayer *layer = window.layer;
        CGRect b = layer.bounds;
        CGPoint anchor = CGPointMake(b.origin.x + layer.anchorPoint.x * b.size.width, b.origin.y + layer.anchorPoint.y * b.size.height);
        DWPoint src[4], dst[4];
        for (int i = 0; i < 4; i++) {
            CGPoint s = [window convertPoint:DWToFixed(rect[i], edge, fixed) fromCoordinateSpace:fixedSpace];
            CGPoint t = [window convertPoint:DWToFixed(quad[i], edge, fixed) fromCoordinateSpace:fixedSpace];
            src[i] = (DWPoint){s.x - anchor.x, s.y - anchor.y};
            dst[i] = (DWPoint){t.x - anchor.x, t.y - anchor.y};
        }
        double h[9];
        if (!DWHomography(src, dst, h)) {
            continue;
        }
        DWSaved *saved = [_saved objectForKey:layer];
        if (!saved) {
            saved = [DWSaved new];
            saved.sublayerTransform = layer.sublayerTransform;
            saved.filters = layer.filters;
            saved.opacity = layer.opacity;
            [_saved setObject:saved forKey:layer];
        }
        CATransform3D m = CATransform3DIdentity;
        m.m11 = h[0], m.m21 = h[1], m.m41 = h[2];
        m.m12 = h[3], m.m22 = h[4], m.m42 = h[5];
        m.m14 = h[6], m.m24 = h[7], m.m44 = h[8];
        layer.sublayerTransform = m;
        NSMutableArray *filters = [NSMutableArray arrayWithArray:saved.filters ?: @[]];
        double radius = _blur * progress;
        Class filterClass = NSClassFromString(@"CAFilter");
        if (radius > 0.25 && filterClass) {
            CAFilter *blur = [filterClass filterWithType:@"gaussianBlur"];
            [blur setValue:@(radius) forKey:@"inputRadius"];
            [filters addObject:blur];
        }
        layer.filters = filters.count ? filters : nil;
        layer.opacity = saved.opacity * fade;
    }
    [CATransaction commit];
}

- (void)restore {
    _active = NO;
    _haveQuad = NO;
    if (_saved.count == 0) {
        return;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in _saved.keyEnumerator.allObjects) {
        DWSaved *saved = [_saved objectForKey:layer];
        layer.sublayerTransform = saved.sublayerTransform;
        layer.filters = saved.filters;
        layer.opacity = saved.opacity;
    }
    [CATransaction commit];
    [_saved removeAllObjects];
}

@end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    [[DWController shared] start];
}

%end
