#import "Global.h"
#import "HBFPGradientView.h"
#import <BulletinBoard/BBBulletin.h>
#import <SpringBoard/SBAwayBulletinListItem.h>
#import <SpringBoard/SBAwayNotificationListCell.h>
#import <SpringBoard/SBLockScreenNotificationCell.h>
#import <SpringBoard/SBLockScreenNotificationListView.h>
#import <SpringBoard/SBLockScreenNotificationModel.h>

static const char *kHBFPBackgroundGradientIdentifier;
static const char *kHBFPBackgroundViewIdentifier;

%hook SBLockScreenNotificationListView

- (id)initWithFrame:(CGRect)frame {
	self = %orig;

	if (self) {
		if (lockFade) {
			UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");

			CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
			gradientLayer.locations = IS_IPAD
				? @[ @0, @0.01f, @0.02f, @0.92f, @1 ]
				: @[ @0, @0.02f, @0.04f, @0.9f,  @1 ];
			gradientLayer.colors = @[
				hasBlurredClock
					? (id)[UIColor whiteColor].CGColor
					: (id)[UIColor colorWithWhite:1 alpha:0.02f].CGColor,
				hasBlurredClock
					? (id)[UIColor whiteColor].CGColor
					: (id)[UIColor colorWithWhite:1 alpha:0.7f].CGColor,
				(id)[UIColor whiteColor].CGColor,
				(id)[UIColor whiteColor].CGColor,
				(id)[UIColor colorWithWhite:1 alpha:0.000001f].CGColor
			];
			containerView.layer.mask = gradientLayer;

			objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if (lockFade) {
		UIView *containerView = MSHookIvar<UIView *>(self, "_containerView");

		CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
		gradientLayer.frame = CGRectMake(0, 0, containerView.frame.size.width, containerView.frame.size.height);
	}
}

- (SBLockScreenNotificationCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBLockScreenNotificationCell *cell = %orig;

	if (tintLockScreen || biggerIcon) {
		SBAwayBulletinListItem *listItem = [self.model listItemAtIndexPath:indexPath];

		if (![listItem respondsToSelector:@selector(activeBulletin)] || !listItem.activeBulletin) {
			return cell;
		}

		BBBulletin *bulletin = listItem.activeBulletin;
		UIImageView *iconImageView = MSHookIvar<UIImageView *>(cell, "_iconImageView");

		BOOL isMusic = HBFPIsMusic(bulletin.sectionID);
		NSString *key = HBFPGetKey(bulletin.sectionID, isMusic);

		if (biggerIcon) {
			HBFPGetIconIfNeeded(key, bulletin, isMusic);
			iconImageView.image = iconCache[key];
		}

		if (isMusic) {
			iconImageView.layer.minificationFilter = kCAFilterTrilinear;
		}

		if (tintLockScreen) {
			if (!iconCache[key]) {
				iconCache[key] = iconImageView.image;
			}

			if (!tintCache[key]) {
				tintCache[key] = HBFPGetDominantColor(iconCache[key]);
			}

			UIView *backgroundView = objc_getAssociatedObject(cell, &kHBFPBackgroundViewIdentifier);
			backgroundView.backgroundColor = tintCache[key];
		}
	}

	return cell;
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	%orig;
}

%end

%hook SBLockScreenBulletinCell

+ (BOOL)wantsUnlockActionText {
	return removeAction ? NO : %orig;
}

+ (CGFloat)rowHeightForTitle:(NSString *)title subtitle:(NSString *)subtitle body:(NSString *)body maxLines:(NSUInteger)maxLines attachmentSize:(CGSize)attachmentSize datesVisible:(BOOL)datesVisible rowWidth:(CGFloat)rowWidth includeUnlockActionText:(BOOL)includeUnlockActionText {
	return %orig(title, subtitle, body, maxLines, attachmentSize, datesVisible, rowWidth, removeAction ? NO : includeUnlockActionText);
}

%end

%hook SBLockScreenNotificationCell

+ (CGFloat)contentWidthWithRowWidth:(CGFloat)rowWidth andAttachmentSize:(CGSize)attachmentSize {
	return %orig(biggerIcon && IS_IPAD ? rowWidth - 16.f : rowWidth, attachmentSize);
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = %orig;

	if (self) {
		if (tintLockScreen) {
			UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
			backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			backgroundView.alpha = lockOpacity;
			[self.realContentView insertSubview:backgroundView atIndex:0];

			objc_setAssociatedObject(self, &kHBFPBackgroundViewIdentifier, backgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

			if (lockGradient) {
				static BOOL isRTL;
				static dispatch_once_t onceToken;
				dispatch_once(&onceToken, ^{
					isRTL = [NSLocale characterDirectionForLanguage:[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode]] == NSLocaleLanguageDirectionRightToLeft;
				});

				NSArray *locations = @[ @0, @0.2f, @0.4f, @1 ];

				CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
				gradientLayer.locations = isRTL ? locations.reverseObjectEnumerator.allObjects : locations;
				gradientLayer.startPoint = CGPointMake(0, 0.5f);
				gradientLayer.endPoint = CGPointMake(1.f, 0.5f);
				gradientLayer.colors = @[
					(id)[UIColor colorWithWhite:1 alpha:1.f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.625f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.25f].CGColor,
					(id)[UIColor colorWithWhite:1 alpha:0.0625f].CGColor
				];
				backgroundView.layer.mask = gradientLayer;

				objc_setAssociatedObject(self, &kHBFPBackgroundGradientIdentifier, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			}
		}
	}

	return self;
}

- (void)layoutSubviews {
	%orig;

	if (tintLockScreen || biggerIcon) {
		if (biggerIcon) {
			UIImageView *iconImageView = MSHookIvar<UIImageView *>(self, "_iconImageView");

			if (IS_IPAD) {
				iconImageView.frame = CGRectMake(9.f, 15.5f, 30.f, 30.f);

				UILabel *primaryLabel = MSHookIvar<UILabel *>(self, "_primaryLabel");
				CGRect primaryFrame = primaryLabel.frame;
				primaryFrame.origin.x += 16.f;
				primaryLabel.frame = primaryFrame;

				UILabel *subtitleLabel = MSHookIvar<UILabel *>(self, "_subtitleLabel");
				CGRect subtitleFrame = subtitleLabel.frame;
				subtitleFrame.origin.x += 16.f;
				subtitleLabel.frame = subtitleFrame;

				UILabel *secondaryLabel = MSHookIvar<UILabel *>(self, "_secondaryLabel");
				CGRect secondaryFrame = secondaryLabel.frame;
				secondaryFrame.origin.x += 16.f;
				secondaryLabel.frame = secondaryFrame;

				UILabel *relevanceDateLabel = MSHookIvar<UILabel *>(self, "_relevanceDateLabel");
				CGRect relevanceDateFrame = relevanceDateLabel.frame;
				relevanceDateFrame.origin.x += 16.f;
				relevanceDateLabel.frame = relevanceDateFrame;

				UILabel *unlockTextLabel = MSHookIvar<UILabel *>(self, "_unlockTextLabel");
				CGRect unlockTextFrame = unlockTextLabel.frame;
				unlockTextFrame.origin.x += 16.f;
				unlockTextLabel.frame = unlockTextFrame;
			} else {
				iconImageView.frame = CGRectMake(9.f, 12.5f, 30.f, 30.f);
			}
		}

		if (tintLockScreen && lockGradient) {
			CAGradientLayer *gradientLayer = objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier);
			gradientLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
		}
	}
}

- (void)setContentAlpha:(CGFloat)contentAlpha {
	%orig(lockDisableDimming ? 1 : contentAlpha);
}

- (void)dealloc {
	[objc_getAssociatedObject(self, &kHBFPBackgroundGradientIdentifier) release];
	[objc_getAssociatedObject(self, &kHBFPBackgroundViewIdentifier) release];
	%orig;
}

%end

%group ClassicLockScreen
%hook CSAwayNotificationController

- (SBAwayNotificationListCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	SBAwayNotificationListCell *cell = %orig;

	if (tintLockScreen) {
		BOOL isMusic = HBFPIsMusic(cell.bulletin.sectionID);
		NSString *key = HBFPGetKey(cell.bulletin.sectionID, isMusic);

		if (!iconCache[key]) {
			iconCache[key] = cell.imageView.image;
		}

		if (!tintCache[key]) {
			tintCache[key] = HBFPGetDominantColor(iconCache[key]);
		}

		cell.backgroundColor = tintCache[key];
	}

	return cell;
}

%end
%end

%ctor {
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib"]) {
		dlopen("/Library/MobileSubstrate/DynamicLibraries/SubtleLock.dylib", RTLD_NOW);
	}

	%init;

	if (%c(CSAwayNotificationController)) {
		%init(ClassicLockScreen);
	}
}
