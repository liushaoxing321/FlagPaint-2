#import <Accelerate/Accelerate.h>
#import <BulletinBoard/BBBulletinRequest.h>
//#import <SpringBoard/SBBannerContextView.h>
#import <SpringBoard/SBBulletinBannerController.h>
#import <UIKit/_UIBackdropView.h>
#import <UIKit/_UIBackdropViewSettingsAdaptiveLight.h>

struct pixel {
	unsigned char r, g, b, a;
};

static NSUInteger BytesPerPixel = 4;
static NSUInteger BitsPerComponent = 8;

#pragma mark - Get dominant color

UIColor *HBFPGetDominantColor(UIImage *image) {
	NSUInteger red = 0, green = 0, blue = 0;
	NSUInteger numberOfPixels = image.size.width * image.size.height;

	pixel *pixels = (pixel *)calloc(1, image.size.width * image.size.height * sizeof(pixel));

	if (!pixels) {
		return [UIColor whiteColor];
	}

	CGContextRef context = CGBitmapContextCreate(pixels, image.size.width, image.size.height, BitsPerComponent, image.size.width * BytesPerPixel, CGImageGetColorSpace(image.CGImage), kCGImageAlphaPremultipliedLast);

	if (!context) {
		free(pixels);
		return [UIColor whiteColor];
	}

	CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);

	for (NSUInteger i = 0; i < numberOfPixels; i++) {
		red += pixels[i].r;
		green += pixels[i].g;
		blue += pixels[i].b;
	}

	red /= numberOfPixels;
	green /= numberOfPixels;
	blue /= numberOfPixels;

	CGContextRelease(context);
	free(pixels);

	return [UIColor colorWithRed:red / 255.f green:green / 255.f blue:blue / 255.f alpha:1];
}

#pragma mark - The Guts(tm)

static const char *kHBFPBackdropViewSettingsIdentifier;

NSMutableDictionary *cachedTints = [[NSMutableDictionary alloc] init];

%hook SBBannerContextView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		_UIBackdropView *oldBackdropView = MSHookIvar<_UIBackdropView *>(self, "_backdropView");

		_UIBackdropViewSettingsAdaptiveLight *settings = [[%c(_UIBackdropViewSettingsAdaptiveLight) alloc] initWithDefaultValues];
		settings.colorTint = [UIColor blackColor];
		settings.colorTintAlpha = 0.5f;
		settings.grayscaleTintLevel = 0;
		settings.grayscaleTintAlpha = 0.4f;

		objc_setAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier, settings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		_UIBackdropView *backdropView = [[%c(_UIBackdropView) alloc] initWithFrame:frame autosizesToFitSuperview:YES settings:settings];
		[oldBackdropView.superview insertSubview:backdropView belowSubview:oldBackdropView];
		[oldBackdropView removeFromSuperview];
		[oldBackdropView release];

		object_setInstanceVariable(self, "_backdropView", backdropView);
	}

	return self;
}

- (void)setBannerContext:(id)bannerContext withReplaceReason:(NSInteger)replaceReason {
	%orig;

	_UIBackdropViewSettings *settings = objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier);

	UIView *contentView = MSHookIvar<UIView *>(self, "_contentView");
	UIImageView *iconImageView = MSHookIvar<UIImageView *>(contentView, "_iconImageView");

	NSObject *viewSource = MSHookIvar<NSObject *>(contentView, "_viewSource");
	BBBulletin *bulletin = MSHookIvar<BBBulletin *>(viewSource, "_seedBulletin");

	if (!cachedTints[bulletin.sectionID]) {
		cachedTints[bulletin.sectionID] = HBFPGetDominantColor(iconImageView.image);
	}

	settings.colorTint = cachedTints[bulletin.sectionID];
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackdropViewSettingsIdentifier) release];

	%orig;
}

%end

#pragma mark - Preferences

void HBFPLoadPrefs() {
	// ...
}

#pragma mark - Show test banner

NSUInteger testIndex = 0;

void HBFPShowTestBanner() {
	static NSArray *TestApps;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		TestApps = [@[
			@"com.apple.MobileSMS", @"com.apple.mobilecal", @"com.apple.mobileslideshow", @"com.apple.camera",
			@"com.apple.weather", @"com.apple.mobiletimer", @"com.apple.Maps", @"com.apple.videos",
			@"com.apple.mobilenotes", @"com.apple.reminders", @"com.apple.stocks", @"com.apple.gamecenter",
			@"com.apple.Passbook", @"com.apple.MobileStore", @"com.apple.AppStore", @"com.apple.Preferences",
			@"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", @"com.apple.Music",
			@"com.apple.MobileAddressBook", @"com.apple.calculator", @"com.apple.compass", @"com.apple.VoiceMemos",
			@"com.apple.facetime", @"com.apple.nike"
		] retain];

		testIndex = arc4random_uniform(TestApps.count);
	});

	BBBulletinRequest *bulletin = [[[BBBulletinRequest alloc] init] autorelease];
	bulletin.bulletinID = @"ws.hbang.flagpaint7";
	bulletin.title = @"FlagPaint";
	bulletin.message = @"Test notification";
	bulletin.sectionID = TestApps[testIndex];
	bulletin.accessoryStyle = BBBulletinAccessoryStyleVIP;
	[[%c(SBBulletinBannerController) sharedInstance] observer:nil addBulletin:bulletin forFeed:2];

	testIndex = testIndex == TestApps.count - 1 ? 0 : testIndex + 1;
}

#pragma mark - Constructor

%ctor {
	HBFPLoadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPLoadPrefs, CFSTR("ws.hbang.flagpaint/ReloadPrefs"), NULL, 0);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBFPShowTestBanner, CFSTR("ws.hbang.flagpaint/TestBanner"), NULL, 0);
}
