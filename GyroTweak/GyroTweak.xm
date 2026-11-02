#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import "GyroTweak.h"

static CMMotionManager* _motionManager = nil;
static dispatch_queue_t _motionQueue = nil;
static volatile float _sensitivity = 1.0f;
static UIWindow* _settingsWindow = nil;
static BOOL _gestureInstalled = NO;

static const float kDefaultSensitivity = 1.0f;
static const float kMinSensitivity = 0.1f;
static const float kMaxSensitivity = 5.0f;

static os_unfair_lock _dataLock = OS_UNFAIR_LOCK_INIT;
static float _gyroX = 0.0f, _gyroY = 0.0f, _gyroZ = 0.0f;
static float _accelX = 0.0f, _accelY = 0.0f, _accelZ = 0.0f;
static float _quatX = 0.0f, _quatY = 0.0f, _quatZ = 0.0f, _quatW = 1.0f;
static BOOL _hasGyro = NO, _hasAccel = NO, _hasAttitude = NO;

static void GyroTweak_LoadSettings(void) {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    float saved = [prefs floatForKey:@"GyroTweakSensitivity"];
    _sensitivity = saved > 0 ? saved : kDefaultSensitivity;
}

static void GyroTweak_SaveSettings(void) {
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setFloat:_sensitivity forKey:@"GyroTweakSensitivity"];
}

@interface GyroSettingsViewController : UIViewController
@end

@implementation GyroSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.9];
    self.view.layer.cornerRadius = 16;
    self.view.layer.masksToBounds = YES;

    UIView* container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:container];

    UILabel* title = [[UILabel alloc] init];
    title.text = @"GyroTweak";
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:title];

    UILabel* sensLabel = [[UILabel alloc] init];
    sensLabel.text = @"Чувствительность";
    sensLabel.font = [UIFont systemFontOfSize:16];
    sensLabel.textColor = [UIColor lightGrayColor];
    sensLabel.textAlignment = NSTextAlignmentCenter;
    sensLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:sensLabel];

    UISlider* slider = [[UISlider alloc] init];
    slider.minimumValue = kMinSensitivity;
    slider.maximumValue = kMaxSensitivity;
    slider.value = _sensitivity;
    slider.minimumTrackTintColor = [UIColor systemBlueColor];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:slider];

    UILabel* valueLabel = [[UILabel alloc] init];
    valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    valueLabel.textColor = [UIColor whiteColor];
    valueLabel.text = [NSString stringWithFormat:@"%.2f", _sensitivity];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:valueLabel];

    UIButton* closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"Готово" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor systemBlueColor];
    closeBtn.layer.cornerRadius = 10;
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeBtn];

    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [container.widthAnchor constraintEqualToConstant:300],

        [title.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],

        [sensLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:20],
        [sensLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],

        [slider.topAnchor constraintEqualToAnchor:sensLabel.bottomAnchor constant:12],
        [slider.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [slider.trailingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor constant:-12],

        [valueLabel.centerYAnchor constraintEqualToAnchor:slider.centerYAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [valueLabel.widthAnchor constraintEqualToConstant:50],

        [closeBtn.topAnchor constraintEqualToAnchor:slider.bottomAnchor constant:24],
        [closeBtn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [closeBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [closeBtn.heightAnchor constraintEqualToConstant:48],
        [closeBtn.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-20]
    ]];

    objc_setAssociatedObject(self, "slider", slider, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, "valueLabel", valueLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self updateLabel];
}

- (void)updateLabel {
    UILabel* valueLabel = objc_getAssociatedObject(self, "valueLabel");
    valueLabel.text = [NSString stringWithFormat:@"%.2f", _sensitivity];
}

- (void)sliderChanged:(UISlider*)sender {
    GyroTweak_SetSensitivity(sender.value);
    [self updateLabel];
}

- (void)closeTapped:(id)sender {
    GyroTweak_SaveSettings();
    [self dismissWindow];
}

- (void)dismissWindow {
    if (_settingsWindow) {
        _settingsWindow.hidden = YES;
        _settingsWindow.rootViewController = nil;
        _settingsWindow = nil;
    }
}

@end

static UIWindow* GyroTweak_FindKeyWindow(void) {
    for (UIWindow* w in [UIApplication sharedApplication].windows) {
        if (w.windowLevel == UIWindowLevelNormal && !w.hidden && w.frame.size.width > 0) {
            return w;
        }
    }
    UIWindow* keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow) return keyWindow;
    for (UIWindow* w in [UIApplication sharedApplication].windows) {
        if (!w.hidden) return w;
    }
    return nil;
}

static void GyroTweak_ShowSettings(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_settingsWindow) return;

        UIWindow* keyWindow = GyroTweak_FindKeyWindow();
        if (!keyWindow) return;

        GyroSettingsViewController* vc = [[GyroSettingsViewController alloc] init];
        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;

        _settingsWindow = [[UIWindow alloc] initWithFrame:keyWindow.frame];
        _settingsWindow.windowLevel = UIWindowLevelAlert + 1;
        _settingsWindow.rootViewController = vc;
        _settingsWindow.backgroundColor = [UIColor clearColor];
        [_settingsWindow makeKeyAndVisible];
    });
}

@interface GyroTweakGestureHandler : NSObject
+ (void)handleTripleTap:(UITapGestureRecognizer*)gesture;
@end

@implementation GyroTweakGestureHandler
+ (void)handleTripleTap:(UITapGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        GyroTweak_ShowSettings();
    }
}
@end

static void GyroTweak_TryInstallGesture(void) {
    if (_gestureInstalled) return;
    UIWindow* keyWindow = GyroTweak_FindKeyWindow();
    if (!keyWindow) return;

    UITapGestureRecognizer* tap = [[UITapGestureRecognizer alloc] initWithTarget:[GyroTweakGestureHandler class] action:@selector(handleTripleTap:)];
    tap.numberOfTapsRequired = 3;
    tap.numberOfTouchesRequired = 1;
    tap.cancelsTouchesInView = NO;
    [keyWindow addGestureRecognizer:tap];
    _gestureInstalled = YES;
}

static void GyroTweak_InstallGesture(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification* note) {
            (void)note;
            GyroTweak_TryInstallGesture();
        }];
        GyroTweak_TryInstallGesture();
    });
}

__attribute__((constructor))
static void GyroTweak_Constructor(void) {
    GyroTweak_LoadSettings();
    GyroTweak_Init();
    GyroTweak_InstallGesture();
}

__attribute__((destructor))
static void GyroTweak_Destructor(void) {
    GyroTweak_Shutdown();
}

int GyroTweak_Init(void) {
    if (_motionManager != nil) return 0;

    _motionManager = [[CMMotionManager alloc] init];
    if (!_motionManager) return -1;

    _motionQueue = dispatch_queue_create("com.gyrotweak.motion", DISPATCH_QUEUE_SERIAL);
    if (!_motionQueue) {
        _motionManager = nil;
        return -1;
    }

    _motionManager.gyroUpdateInterval = 1.0 / 60.0;
    _motionManager.accelerometerUpdateInterval = 1.0 / 60.0;
    _motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;

    if ([_motionManager isGyroAvailable]) {
        [_motionManager startGyroUpdatesToQueue:_motionQueue withHandler:^(CMGyroData* gyroData, NSError* err) {
            (void)err;
            if (gyroData) {
                os_unfair_lock_lock(&_dataLock);
                _gyroX = (float)gyroData.rotationRate.x;
                _gyroY = (float)gyroData.rotationRate.y;
                _gyroZ = (float)gyroData.rotationRate.z;
                _hasGyro = YES;
                os_unfair_lock_unlock(&_dataLock);
            }
        }];
    }
    if ([_motionManager isAccelerometerAvailable]) {
        [_motionManager startAccelerometerUpdatesToQueue:_motionQueue withHandler:^(CMAccelerometerData* accelData, NSError* err) {
            (void)err;
            if (accelData) {
                os_unfair_lock_lock(&_dataLock);
                _accelX = (float)accelData.acceleration.x;
                _accelY = (float)accelData.acceleration.y;
                _accelZ = (float)accelData.acceleration.z;
                _hasAccel = YES;
                os_unfair_lock_unlock(&_dataLock);
            }
        }];
    }
    if ([_motionManager isDeviceMotionAvailable]) {
        [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                           toQueue:_motionQueue
                                                       withHandler:^(CMDeviceMotion* motion, NSError* err) {
            (void)err;
            if (motion) {
                os_unfair_lock_lock(&_dataLock);
                _quatX = (float)motion.attitude.quaternion.x;
                _quatY = (float)motion.attitude.quaternion.y;
                _quatZ = (float)motion.attitude.quaternion.z;
                _quatW = (float)motion.attitude.quaternion.w;
                _hasAttitude = YES;
                os_unfair_lock_unlock(&_dataLock);
            }
        }];
    }
    return 0;
}

void GyroTweak_Shutdown(void) {
    if (_motionManager) {
        [_motionManager stopGyroUpdates];
        [_motionManager stopAccelerometerUpdates];
        [_motionManager stopDeviceMotionUpdates];
        _motionManager = nil;
    }
    _motionQueue = nil;

    os_unfair_lock_lock(&_dataLock);
    _hasGyro = NO;
    _hasAccel = NO;
    _hasAttitude = NO;
    os_unfair_lock_unlock(&_dataLock);
}

int GyroTweak_GetRotationRate(float* outX, float* outY, float* outZ) {
    if (!_motionManager) return -1;

    os_unfair_lock_lock(&_dataLock);
    BOOL has = _hasGyro;
    float x = _gyroX, y = _gyroY, z = _gyroZ;
    os_unfair_lock_unlock(&_dataLock);
    if (!has) return -1;

    float s = _sensitivity;
    if (outX) *outX = x * s;
    if (outY) *outY = y * s;
    if (outZ) *outZ = z * s;
    return 0;
}

int GyroTweak_GetAcceleration(float* outX, float* outY, float* outZ) {
    if (!_motionManager) return -1;

    os_unfair_lock_lock(&_dataLock);
    BOOL has = _hasAccel;
    float x = _accelX, y = _accelY, z = _accelZ;
    os_unfair_lock_unlock(&_dataLock);
    if (!has) return -1;

    float s = _sensitivity;
    if (outX) *outX = x * s;
    if (outY) *outY = y * s;
    if (outZ) *outZ = z * s;
    return 0;
}

int GyroTweak_GetAttitudeQuaternion(float* outX, float* outY, float* outZ, float* outW) {
    if (!_motionManager) return -1;

    os_unfair_lock_lock(&_dataLock);
    BOOL has = _hasAttitude;
    float x = _quatX, y = _quatY, z = _quatZ, w = _quatW;
    os_unfair_lock_unlock(&_dataLock);
    if (!has) return -1;

    if (outX) *outX = x;
    if (outY) *outY = y;
    if (outZ) *outZ = z;
    if (outW) *outW = w;
    return 0;
}

int GyroTweak_IsAvailable(void) {
    if (!_motionManager) return 0;
    return [_motionManager isGyroAvailable] || [_motionManager isDeviceMotionAvailable];
}

float GyroTweak_GetSensitivity(void) { return _sensitivity; }
void GyroTweak_SetSensitivity(float v) {
    if (v < kMinSensitivity) v = kMinSensitivity;
    if (v > kMaxSensitivity) v = kMaxSensitivity;
    _sensitivity = v;
    GyroTweak_SaveSettings();
}
