#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ImageIO/ImageIO.h>
#import "../Shared/QRFeatures.h"
#import "QRFileOperations.h"

static NSString * const QRProductName = @"QuickRightMenu";
static NSString * const QRProductVersion = @"1.6.0";
static NSString * const QRLatestReleaseAPI = @"https://api.github.com/repos/weaiw/QuickRightMenu/releases/latest";
static NSString * const QRReleasesURL = @"https://github.com/weaiw/QuickRightMenu/releases/latest";

@interface QRAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *commandTimer;
@property(nonatomic, assign) BOOL busy;
@property(nonatomic, strong) NSProgress *jobProgress;
@property(nonatomic, strong) NSWindow *jobWindow;
@property(nonatomic, strong) NSTextField *jobStatus;
@property(nonatomic, strong) NSProgressIndicator *jobIndicator;
@property(nonatomic, strong) NSTextView *jobDetails;
@property(nonatomic, strong) NSButton *jobCancelButton;
@property(nonatomic, strong) NSArray<NSURL *> *jobOutputs;
@property(nonatomic, strong) NSArray<NSDictionary *> *undoRecords;
@property(nonatomic, strong) NSScrollView *menuScrollView;
@property(nonatomic, strong) NSPopUpButton *importedTemplatePopup;
@property(nonatomic, strong) NSPopUpButton *presetPopup;
@property(nonatomic, strong) NSPopUpButton *presetFormat;
@property(nonatomic, strong) NSTextField *presetName;
@property(nonatomic, strong) NSTextField *presetMaxSide;
@property(nonatomic, strong) NSTextField *presetTargetMB;
@property(nonatomic, strong) NSTextField *presetWatermark;
@property(nonatomic, strong) NSTextField *presetDirectory;
@property(nonatomic, strong) NSButton *presetStripMetadata;
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSWindow *textPreviewWindow;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *settings;
@property(nonatomic, copy) NSString *settingsPage;
@property(nonatomic, strong) NSPopUpButton *templatePopup;
@property(nonatomic, strong) NSTextView *templateTextView;
@property(nonatomic, strong) NSPopUpButton *terminalPopup;
@property(nonatomic, copy) NSString *latestVersion;
@property(nonatomic, copy) NSString *latestDownloadURL;
@property(nonatomic, assign) BOOL updateAvailable;
@property(nonatomic, assign) BOOL updateCheckFinished;
@end

@implementation QRAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self log:@"applicationDidFinishLaunching"];
    self.settings = [[self loadSettings] mutableCopy];
    [self saveSettings];

    self.undoRecords = @[];
    self.commandTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                         target:self
                                                       selector:@selector(pollCommandFiles:)
                                                       userInfo:nil
                                                        repeats:YES];

    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];

    NSImage *appIcon = [self appIconImage];
    if (appIcon) {
        [NSApp setApplicationIconImage:appIcon];
    }

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    NSImage *statusIcon = [appIcon copy];
    if (statusIcon) {
        statusIcon.size = NSMakeSize(18, 18);
        self.statusItem.button.image = statusIcon;
    } else {
        self.statusItem.button.title = @"Q";
    }
    self.statusItem.button.toolTip = QRProductName;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:QRProductName];
    [menu addItemWithTitle:[NSString stringWithFormat:@"%@ 正在运行", QRProductName] action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *settingsItem = [menu addItemWithTitle:@"设置..." action:@selector(showSettings:) keyEquivalent:@","];
    settingsItem.target = self;
    NSMenuItem *recent = [menu addItemWithTitle:@"最近操作…" action:@selector(showRecentOperation:) keyEquivalent:@""];
    recent.target = self;
    NSMenuItem *undo = [menu addItemWithTitle:@"撤销上次移动或重命名…" action:@selector(undoLastOperation:) keyEquivalent:@""];
    undo.target = self;
    NSMenuItem *quitItem = [menu addItemWithTitle:@"退出" action:@selector(terminate:) keyEquivalent:@"q"];
    quitItem.target = NSApp;
    self.statusItem.menu = menu;

    [self handleFirstLaunchGuideIfNeeded];
    [self checkForUpdatesSilently];
}

- (NSImage *)appIconImage {
    NSImage *image = [NSImage imageNamed:@"AppIcon"];
    if (image) {
        return image;
    }

    NSString *path = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
    if (path.length > 0) {
        return [[NSImage alloc] initWithContentsOfFile:path];
    }
    return nil;
}

- (NSArray<NSDictionary *> *)featureRows {
    return QROrderedFeatures(self.settings ?: @{});
}

- (NSDictionary<NSString *, id> *)defaultSettings {
    NSMutableDictionary<NSString *, id> *defaults = [NSMutableDictionary dictionary];
    for (NSDictionary<NSString *, NSString *> *row in [self featureRows]) {
        defaults[row[@"key"]] = @YES;
    }
    NSDictionary<NSString *, NSString *> *templates = @{
        @"template_txt": @"",
        @"template_md": @"# Untitled\n",
        @"template_json": @"{\n  \n}\n",
        @"template_csv": @"",
        @"template_html": @"<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n  <meta charset=\"utf-8\">\n  <title>Untitled</title>\n</head>\n<body>\n\n</body>\n</html>\n",
        @"template_yaml": @"---\n",
        @"template_xml": @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n\n</root>\n",
        @"template_sh": @"#!/usr/bin/env bash\nset -euo pipefail\n\n",
        @"template_py": @"#!/usr/bin/env python3\n\n",
        @"template_js": @"",
        @"template_ts": @"",
        @"template_css": @":root {\n  color-scheme: light dark;\n}\n"
    };
    [defaults addEntriesFromDictionary:templates];
    defaults[@"contextualMenus"] = @YES;
    defaults[@"pinnedFeatures"] = @[];
    defaults[@"menuOrder"] = @[];
    defaults[@"preferredApplication"] = @"";
    defaults[@"importedTemplates"] = @[];
    defaults[@"imagePresets"] = @[@{@"name": @"准备上传", @"format": @"jpg", @"maxSide": @1920,
                                     @"targetBytes": @1000000, @"stripMetadata": @YES, @"watermark": @"", @"directory": @""}];
    defaults[@"terminalPreference"] = @"terminal";
    defaults[@"hasSeenPermissionGuide"] = @NO;
    for (NSInteger i = 1; i <= 3; i++) {
        defaults[[NSString stringWithFormat:@"favoriteDir%ldName", (long)i]] = @"";
        defaults[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)i]] = @"";
    }
    return defaults;
}

- (NSDictionary<NSString *, id> *)loadSettings {
    NSMutableDictionary *merged = [[self defaultSettings] mutableCopy];
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfURL:[self settingsURL]];
    if (![stored isKindOfClass:NSDictionary.class]) return merged;
    for (NSString *key in merged.allKeys) {
        id value = stored[key], original = merged[key];
        if (([original isKindOfClass:NSNumber.class] && [value isKindOfClass:NSNumber.class]) ||
            ([original isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])) merged[key] = value;
    }
    for (NSString *key in @[@"pinnedFeatures", @"menuOrder"]) {
        if (![stored[key] isKindOfClass:NSArray.class]) continue;
        NSMutableArray *values = [NSMutableArray array];
        for (id value in stored[key]) if ([value isKindOfClass:NSString.class] && ![values containsObject:value]) [values addObject:value];
        merged[key] = values;
    }
    for (NSString *key in @[@"importedTemplates", @"imagePresets"]) {
        if (![stored[key] isKindOfClass:NSArray.class]) continue;
        NSMutableArray *values = [NSMutableArray array];
        for (id value in stored[key]) {
            if (![value isKindOfClass:NSDictionary.class] || ![value[@"name"] isKindOfClass:NSString.class]) continue;
            if ([key isEqualToString:@"importedTemplates"]) {
                if ([value[@"path"] isKindOfClass:NSString.class] && [value[@"path"] isAbsolutePath]) [values addObject:value];
            } else if ([@[@"jpg", @"png"] containsObject:value[@"format"]] &&
                       [value[@"maxSide"] isKindOfClass:NSNumber.class] && [value[@"targetBytes"] isKindOfClass:NSNumber.class] &&
                       [value[@"stripMetadata"] isKindOfClass:NSNumber.class] && [value[@"watermark"] isKindOfClass:NSString.class] &&
                       [value[@"directory"] isKindOfClass:NSString.class] && [value[@"maxSide"] integerValue] >= 0 &&
                       [value[@"maxSide"] integerValue] <= 30000 && [value[@"targetBytes"] longLongValue] >= 0 &&
                       [value[@"targetBytes"] longLongValue] <= 100 * 1024 * 1024) [values addObject:value];
        }
        merged[key] = values;
    }
    return merged;
}

- (void)saveSettings {
    NSURL *url = [self settingsURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    if (![self.settings writeToURL:url atomically:YES]) [self showError:@"设置保存失败，请检查应用的文件访问权限。"];
}

- (NSURL *)settingsURL {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.liaowenbin.QuickRightMenu.Extension/Data/Library/Application Support/QuickRightMenu/settings.plist"];
    return [NSURL fileURLWithPath:path];
}

- (void)showSettings:(id)sender {
    if (!self.settingsPage) {
        self.settingsPage = @"menu";
    }
    if (!self.settingsWindow) {
        self.settingsWindow = [self buildSettingsWindow];
    }
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)handleFirstLaunchGuideIfNeeded {
    if (![self.settings[@"hasSeenPermissionGuide"] boolValue]) {
        self.settingsPage = @"permissions";
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSettings:nil];
        });
    }
}

- (NSWindow *)buildSettingsWindow {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 620)
                                                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = [NSString stringWithFormat:@"%@ 设置", QRProductName];
    window.releasedWhenClosed = NO;
    [window center];

    NSView *root = [[NSView alloc] initWithFrame:window.contentView.bounds];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    window.contentView = root;

    NSView *sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 236, 620)];
    sidebar.autoresizingMask = NSViewHeightSizable;
    sidebar.wantsLayer = YES;
    sidebar.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.075 green:0.091 blue:0.14 alpha:1.0].CGColor;
    [root addSubview:sidebar];

    NSImage *appIcon = [self appIconImage];
    if (appIcon) {
        NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(28, 512, 64, 64)];
        iconView.image = appIcon;
        iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [sidebar addSubview:iconView];
    }

    NSTextField *brand = [self labelWithText:QRProductName size:21 bold:YES color:NSColor.whiteColor];
    brand.frame = NSMakeRect(28, 474, 190, 30);
    [sidebar addSubview:brand];

    NSTextField *version = [self labelWithText:[NSString stringWithFormat:@"版本 %@", QRProductVersion] size:13 bold:NO color:[NSColor colorWithWhite:0.74 alpha:1]];
    version.frame = NSMakeRect(28, 448, 170, 22);
    [sidebar addSubview:version];

    NSArray<NSDictionary<NSString *, NSString *> *> *navItems = @[
        @{@"page": @"permissions", @"title": @"权限指引", @"detail": @"首次安装必看"},
        @{@"page": @"menu", @"title": @"右键菜单", @"detail": @"菜单开关"},
        @{@"page": @"templates", @"title": @"文件模板", @"detail": @"新建内容默认值"},
        @{@"page": @"favorites", @"title": @"常用目录", @"detail": @"复制 / 移动快捷目录"},
        @{@"page": @"terminal", @"title": @"打开方式", @"detail": @"终端与常用应用"},
        @{@"page": @"presets", @"title": @"处理组合", @"detail": @"图片处理与输出目录"},
        @{@"page": @"login", @"title": @"开机启动", @"detail": [self isLoginItemEnabled] ? @"已开启" : @"未开启"},
        @{@"page": @"update", @"title": @"软件更新", @"detail": self.updateAvailable ? @"发现新版本" : @"GitHub Release"}
    ];
    for (NSInteger i = 0; i < navItems.count; i++) {
        NSView *navRow = [[NSView alloc] initWithFrame:NSMakeRect(18, 404 - i * 44, 200, 40)];
        navRow.wantsLayer = YES;
        if ([navItems[i][@"page"] isEqualToString:self.settingsPage]) {
            navRow.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.17 green:0.21 blue:0.31 alpha:1.0].CGColor;
            navRow.layer.cornerRadius = 8;
        }

        NSTextField *navTitle = [self labelWithText:navItems[i][@"title"] size:13 bold:YES color:NSColor.whiteColor];
        navTitle.frame = NSMakeRect(12, 18, 170, 18);
        [navRow addSubview:navTitle];

        NSTextField *navDetail = [self labelWithText:navItems[i][@"detail"] size:10 bold:NO color:[NSColor colorWithWhite:0.70 alpha:1]];
        navDetail.frame = NSMakeRect(12, 5, 170, 14);
        [navRow addSubview:navDetail];

        NSButton *navButton = [[NSButton alloc] initWithFrame:navRow.bounds];
        navButton.title = @"";
        navButton.bordered = NO;
        navButton.transparent = YES;
        navButton.target = self;
        navButton.action = @selector(settingNavigationClicked:);
        navButton.identifier = navItems[i][@"page"];
        [navButton setAccessibilityLabel:navItems[i][@"title"]];
        [navRow addSubview:navButton];
        [sidebar addSubview:navRow];
    }

    [self addSettingsContentToView:root];

    return window;
}

- (void)settingNavigationClicked:(NSButton *)sender {
    self.settingsPage = sender.identifier ?: @"menu";
    [self rebuildSettingsWindow];
}

- (void)rebuildSettingsWindow {
    if (!self.settingsWindow) {
        return;
    }
    [self.settingsWindow close];
    self.settingsWindow = [self buildSettingsWindow];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)addSettingsContentToView:(NSView *)root {
    if ([self.settingsPage isEqualToString:@"permissions"]) {
        [self addPermissionGuidePageToView:root];
    } else if ([self.settingsPage isEqualToString:@"templates"]) {
        [self addTemplatePageToView:root];
    } else if ([self.settingsPage isEqualToString:@"favorites"]) {
        [self addFavoriteDirectoryPageToView:root];
    } else if ([self.settingsPage isEqualToString:@"terminal"]) {
        [self addTerminalPageToView:root];
    } else if ([self.settingsPage isEqualToString:@"presets"]) {
        [self addPresetPageToView:root];
    } else if ([self.settingsPage isEqualToString:@"login"]) {
        [self addLoginPageToView:root];
    } else if ([self.settingsPage isEqualToString:@"update"]) {
        [self addUpdatePageToView:root];
    } else {
        [self addMenuPageToView:root];
    }
}

- (void)addPageTitle:(NSString *)title hint:(NSString *)hint toView:(NSView *)root {
    NSTextField *titleLabel = [self labelWithText:title size:24 bold:YES color:NSColor.labelColor];
    titleLabel.frame = NSMakeRect(276, 552, 300, 34);
    [root addSubview:titleLabel];

    NSTextField *hintLabel = [self labelWithText:hint size:14 bold:NO color:NSColor.secondaryLabelColor];
    hintLabel.frame = NSMakeRect(276, 524, 580, 24);
    [root addSubview:hintLabel];
}

- (void)addPermissionGuidePageToView:(NSView *)root {
    [self addPageTitle:@"权限指引" hint:@"首次安装后按顺序完成下面几步，Finder 右键菜单才能稳定显示并执行文件操作。" toView:root];

    NSArray<NSDictionary<NSString *, NSString *> *> *steps = @[
        @{@"title": @"1. 打开一次 QuickRightMenu", @"detail": @"如果 macOS 提示来自未认证开发者，在“隐私与安全性”底部点“仍要打开”。"},
        @{@"title": @"2. 启用 Finder 扩展", @"detail": @"进入系统设置里的 Finder 扩展，打开 QuickRightMenu Extension。"},
        @{@"title": @"3. 添加完全磁盘访问权限", @"detail": @"进入完全磁盘访问，添加并打开 QuickRightMenu，避免复制、移动、创建文件时被系统拦截。"},
        @{@"title": @"4. 重启 Finder", @"detail": @"完成权限设置后重启 Finder，再在 Finder 空白处或文件上右键测试。"}
    ];

    for (NSInteger i = 0; i < steps.count; i++) {
        CGFloat y = 466 - i * 76;
        NSTextField *title = [self labelWithText:steps[i][@"title"] size:15 bold:YES color:NSColor.labelColor];
        title.frame = NSMakeRect(276, y, 360, 24);
        [root addSubview:title];

        NSTextField *detail = [self labelWithText:steps[i][@"detail"] size:13 bold:NO color:NSColor.secondaryLabelColor];
        detail.frame = NSMakeRect(276, y - 24, i == 0 ? 560 : 360, 22);
        [root addSubview:detail];

        if (i == 1) {
            NSButton *extensions = [NSButton buttonWithTitle:@"打开 Finder 扩展设置" target:self action:@selector(openFinderExtensionSettings:)];
            extensions.frame = NSMakeRect(660, y - 6, 176, 32);
            [root addSubview:extensions];
        } else if (i == 2) {
            NSButton *disk = [NSButton buttonWithTitle:@"打开完全磁盘访问" target:self action:@selector(openFullDiskAccessSettings:)];
            disk.frame = NSMakeRect(672, y - 6, 164, 32);
            [root addSubview:disk];
        } else if (i == 3) {
            NSButton *restart = [NSButton buttonWithTitle:@"重启 Finder" target:self action:@selector(restartFinder:)];
            restart.frame = NSMakeRect(716, y - 6, 120, 32);
            [root addSubview:restart];
        }
    }

    NSButton *done = [NSButton buttonWithTitle:@"已完成，不再自动显示" target:self action:@selector(markPermissionGuideSeen:)];
    done.frame = NSMakeRect(276, 76, 170, 34);
    [root addSubview:done];
}

- (void)addUpdatePageToView:(NSView *)root {
    [self addPageTitle:@"软件更新" hint:@"启动后会自动检查 GitHub Release。发现新版本时会在这里提示下载。" toView:root];

    NSString *statusText = @"正在检查更新...";
    if (self.updateAvailable) {
        statusText = [NSString stringWithFormat:@"发现新版本：%@（当前 %@）", self.latestVersion ?: @"未知版本", QRProductVersion];
    } else if (self.updateCheckFinished) {
        statusText = [NSString stringWithFormat:@"当前已是最新版本：%@", QRProductVersion];
    }

    NSTextField *status = [self labelWithText:statusText size:18 bold:YES color:NSColor.labelColor];
    status.frame = NSMakeRect(276, 454, 500, 30);
    [root addSubview:status];

    NSString *detailText = self.updateAvailable ? @"点击下载会打开 GitHub Release 页面。下载 zip 后替换应用程序里的 QuickRightMenu.app 即可。" : @"也可以手动打开 Release 页面查看历史版本。";
    NSTextField *detail = [self labelWithText:detailText size:14 bold:NO color:NSColor.secondaryLabelColor];
    detail.frame = NSMakeRect(276, 418, 560, 24);
    [root addSubview:detail];

    NSButton *check = [NSButton buttonWithTitle:@"立即检查" target:self action:@selector(checkForUpdatesManually:)];
    check.frame = NSMakeRect(276, 362, 100, 34);
    [root addSubview:check];

    NSButton *download = [NSButton buttonWithTitle:(self.updateAvailable ? @"下载新版本" : @"打开 Release") target:self action:@selector(openReleasePage:)];
    download.frame = NSMakeRect(388, 362, 120, 34);
    [root addSubview:download];
}

- (void)addMenuPageToView:(NSView *)root {
    [self addPageTitle:@"右键菜单" hint:@"勾选显示功能；置顶项直接出现在菜单顶部。上下按钮调整顺序。" toView:root];
    NSButton *context = [NSButton checkboxWithTitle:@"只显示适用于所选文件类型的工具" target:self action:@selector(settingsCheckboxChanged:)];
    context.identifier = @"contextualMenus";
    context.state = [self.settings[@"contextualMenus"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    context.frame = NSMakeRect(276, 481, 520, 28);
    [root addSubview:context];
    self.menuScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(266, 88, 594, 378)];
    self.menuScrollView.hasVerticalScroller = YES;
    self.menuScrollView.borderType = NSBezelBorder;
    [root addSubview:self.menuScrollView];
    NSArray *rows = [self featureRows];
    CGFloat height = MAX(378, rows.count * 44 + 20);
    NSView *list = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 570, height)];
    self.menuScrollView.documentView = list;
    for (NSUInteger i = 0; i < rows.count; i++) {
        NSDictionary *row = rows[i];
        CGFloat y = height - 46 - i * 44;
        NSButton *check = [NSButton checkboxWithTitle:row[@"title"] target:self action:@selector(settingsCheckboxChanged:)];
        check.identifier = row[@"key"];
        check.state = [self.settings[row[@"key"]] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        check.frame = NSMakeRect(14, y + 8, 320, 26);
        [list addSubview:check];
        NSTextField *category = [self labelWithText:row[@"category"] size:10 bold:NO color:NSColor.secondaryLabelColor];
        category.frame = NSMakeRect(34, y - 3, 270, 14);
        [list addSubview:category];
        NSButton *pin = [NSButton checkboxWithTitle:@"置顶" target:self action:@selector(pinFeatureChanged:)];
        pin.identifier = row[@"key"];
        pin.state = [self.settings[@"pinnedFeatures"] containsObject:row[@"key"]] ? NSControlStateValueOn : NSControlStateValueOff;
        pin.frame = NSMakeRect(343, y + 7, 68, 26);
        [pin setAccessibilityLabel:[row[@"title"] stringByAppendingString:@"：置顶"]];
        [list addSubview:pin];
        for (NSInteger delta = -1; delta <= 1; delta += 2) {
            NSButton *move = [NSButton buttonWithTitle:delta < 0 ? @"↑" : @"↓" target:self action:@selector(moveFeature:)];
            move.identifier = row[@"key"]; move.tag = delta;
            move.enabled = delta < 0 ? i > 0 : i + 1 < rows.count;
            move.frame = NSMakeRect(delta < 0 ? 424 : 470, y + 6, 40, 28);
            [move setAccessibilityLabel:[NSString stringWithFormat:@"%@：%@", row[@"title"], delta < 0 ? @"上移" : @"下移"]];
            [list addSubview:move];
        }
    }
    [list scrollPoint:NSMakePoint(0, height - 378)];
    NSButton *all = [NSButton buttonWithTitle:@"全部启用" target:self action:@selector(enableAllSettings:)];
    all.frame = NSMakeRect(266, 34, 100, 34); [root addSubview:all];
    NSButton *reset = [NSButton buttonWithTitle:@"重置菜单" target:self action:@selector(resetSettings:)];
    reset.frame = NSMakeRect(376, 34, 110, 34); [root addSubview:reset];
}

- (void)addTemplatePageToView:(NSView *)root {
    [self addPageTitle:@"文件模板" hint:@"选择文件类型后直接编辑默认内容，新建该类型文件时会套用这里的模板。" toView:root];

    NSTextField *typeLabel = [self labelWithText:@"文件类型" size:13 bold:YES color:NSColor.secondaryLabelColor];
    typeLabel.frame = NSMakeRect(276, 486, 120, 22);
    [root addSubview:typeLabel];

    NSArray<NSString *> *extensions = @[@"txt", @"md", @"json", @"csv", @"html", @"yaml", @"xml", @"sh", @"py", @"js", @"ts", @"css"];
    self.templatePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(276, 452, 190, 30)];
    [self.templatePopup addItemsWithTitles:extensions];
    [self.templatePopup selectItemWithTitle:@"md"];
    self.templatePopup.target = self;
    self.templatePopup.action = @selector(templateExtensionChanged:);
    [root addSubview:self.templatePopup];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(276, 222, 560, 212)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    [root addSubview:scrollView];

    self.templateTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 560, 212)];
    self.templateTextView.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    scrollView.documentView = self.templateTextView;
    [self templateExtensionChanged:self.templatePopup];

    NSButton *save = [NSButton buttonWithTitle:@"保存模板" target:self action:@selector(saveTemplatePage:)];
    save.frame = NSMakeRect(276, 174, 110, 34);
    [root addSubview:save];

    NSButton *reset = [NSButton buttonWithTitle:@"恢复该类型默认" target:self action:@selector(resetSelectedTemplate:)];
    reset.frame = NSMakeRect(396, 174, 130, 34);
    [root addSubview:reset];
    NSTextField *importLabel = [self labelWithText:@"导入文件或文件夹模板（包括 Office 文件）" size:13 bold:YES color:NSColor.labelColor];
    importLabel.frame = NSMakeRect(276, 134, 550, 24); [root addSubview:importLabel];
    self.importedTemplatePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(276, 94, 330, 30)];
    for (NSDictionary *entry in self.settings[@"importedTemplates"]) [self.importedTemplatePopup addItemWithTitle:entry[@"name"]];
    [root addSubview:self.importedTemplatePopup];
    NSButton *import = [NSButton buttonWithTitle:@"导入…" target:self action:@selector(importTemplate:)];
    import.frame = NSMakeRect(620, 94, 94, 30); [root addSubview:import];
    NSButton *remove = [NSButton buttonWithTitle:@"移除" target:self action:@selector(removeImportedTemplate:)];
    remove.frame = NSMakeRect(724, 94, 90, 30); [root addSubview:remove];
    NSTextField *help = [self labelWithText:@"导入时保存副本。右键 → 新建文件 → 从导入模板新建。" size:12 bold:NO color:NSColor.secondaryLabelColor];
    help.frame = NSMakeRect(276, 50, 550, 28); [root addSubview:help];
}

- (void)addFavoriteDirectoryPageToView:(NSView *)root {
    [self addPageTitle:@"常用目录" hint:@"设置后会出现在“复制到”和“移动到”菜单里，每个槽位可独立修改。" toView:root];

    for (NSInteger i = 1; i <= 3; i++) {
        CGFloat y = 454 - (i - 1) * 92;
        NSString *name = self.settings[[NSString stringWithFormat:@"favoriteDir%ldName", (long)i]] ?: @"未设置";
        NSString *path = self.settings[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)i]] ?: @"";
        NSString *displayPath = path.length > 0 ? path : @"选择一个常用文件夹";

        NSTextField *slot = [self labelWithText:[NSString stringWithFormat:@"目录 %ld", (long)i] size:14 bold:YES color:NSColor.labelColor];
        slot.frame = NSMakeRect(276, y + 38, 80, 22);
        [root addSubview:slot];

        NSTextField *nameLabel = [self labelWithText:name size:14 bold:NO color:NSColor.labelColor];
        nameLabel.frame = NSMakeRect(356, y + 38, 220, 22);
        [root addSubview:nameLabel];

        NSTextField *pathLabel = [self labelWithText:displayPath size:12 bold:NO color:NSColor.secondaryLabelColor];
        pathLabel.frame = NSMakeRect(356, y + 14, 330, 20);
        [root addSubview:pathLabel];

        NSButton *choose = [NSButton buttonWithTitle:@"选择文件夹" target:self action:@selector(chooseFavoriteDirectoryButton:)];
        choose.frame = NSMakeRect(700, y + 24, 110, 30);
        choose.tag = i;
        [root addSubview:choose];
    }

    NSButton *clear = [NSButton buttonWithTitle:@"清空全部" target:self action:@selector(clearFavoriteDirectories:)];
    clear.frame = NSMakeRect(276, 162, 100, 34);
    [root addSubview:clear];
}

- (void)addTerminalPageToView:(NSView *)root {
    [self addPageTitle:@"打开方式" hint:@"选择终端与常用应用，也可以直接使用 VS Code 或 Cursor。" toView:root];

    NSTextField *label = [self labelWithText:@"默认终端" size:13 bold:YES color:NSColor.secondaryLabelColor];
    label.frame = NSMakeRect(276, 486, 120, 22);
    [root addSubview:label];

    self.terminalPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(276, 452, 260, 30)];
    [self.terminalPopup addItemsWithTitles:@[@"Terminal", @"iTerm2", @"Warp"]];
    NSString *preference = self.settings[@"terminalPreference"] ?: @"terminal";
    if ([preference isEqualToString:@"iterm"]) {
        [self.terminalPopup selectItemWithTitle:@"iTerm2"];
    } else if ([preference isEqualToString:@"warp"]) {
        [self.terminalPopup selectItemWithTitle:@"Warp"];
    } else {
        [self.terminalPopup selectItemWithTitle:@"Terminal"];
    }
    [root addSubview:self.terminalPopup];

    NSButton *save = [NSButton buttonWithTitle:@"保存偏好" target:self action:@selector(saveTerminalPage:)];
    save.frame = NSMakeRect(276, 402, 110, 34);
    [root addSubview:save];
    NSString *application = self.settings[@"preferredApplication"];
    NSTextField *app = [self labelWithText:application.length ? application : @"尚未设置常用应用" size:13 bold:NO color:NSColor.secondaryLabelColor];
    app.frame = NSMakeRect(276, 300, 550, 44); app.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [root addSubview:app];
    NSButton *choose = [NSButton buttonWithTitle:@"选择常用应用…" target:self action:@selector(choosePreferredApplication:)];
    choose.frame = NSMakeRect(276, 256, 160, 34); [root addSubview:choose];
}

- (void)addLoginPageToView:(NSView *)root {
    BOOL enabled = [self isLoginItemEnabled];
    [self addPageTitle:@"开机启动" hint:@"控制登录 macOS 后是否自动启动菜单栏 App。" toView:root];

    NSTextField *status = [self labelWithText:(enabled ? @"当前状态：已开启" : @"当前状态：未开启") size:18 bold:YES color:NSColor.labelColor];
    status.frame = NSMakeRect(276, 454, 260, 30);
    [root addSubview:status];

    NSTextField *detail = [self labelWithText:(enabled ? @"下次登录会自动启动 QuickRightMenu。" : @"下次登录不会自动启动 QuickRightMenu。") size:14 bold:NO color:NSColor.secondaryLabelColor];
    detail.frame = NSMakeRect(276, 420, 420, 24);
    [root addSubview:detail];

    NSButton *toggle = [NSButton buttonWithTitle:(enabled ? @"关闭开机启动" : @"开启开机启动") target:self action:@selector(toggleLoginItem:)];
    toggle.frame = NSMakeRect(276, 366, 130, 34);
    [root addSubview:toggle];
}

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size bold:(BOOL)bold color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.textColor = color;
    return label;
}

- (void)settingsCheckboxChanged:(NSButton *)sender {
    self.settings[sender.identifier] = @(sender.state == NSControlStateValueOn);
    [self saveSettings];
}

- (void)markPermissionGuideSeen:(id)sender {
    self.settings[@"hasSeenPermissionGuide"] = @YES;
    [self saveSettings];
    self.settingsPage = @"menu";
    [self rebuildSettingsWindow];
}

- (void)openFinderExtensionSettings:(id)sender {
    [self openSystemSettingsURLString:@"x-apple.systempreferences:com.apple.ExtensionsPreferences"];
}

- (void)openFullDiskAccessSettings:(id)sender {
    [self openSystemSettingsURLString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"];
}

- (void)restartFinder:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/killall";
    task.arguments = @[@"Finder"];
    @try {
        [task launch];
    } @catch (NSException *exception) {
        [self showError:exception.reason ?: @"重启 Finder 失败"];
    }
}

- (void)openSystemSettingsURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)checkForUpdatesManually:(id)sender {
    self.updateCheckFinished = NO;
    self.settingsPage = @"update";
    [self rebuildSettingsWindow];
    [self checkForUpdatesSilently];
}

- (void)openReleasePage:(id)sender {
    NSString *urlString = self.latestDownloadURL.length > 0 ? self.latestDownloadURL : QRReleasesURL;
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
}

- (void)enableAllSettings:(id)sender {
    for (NSDictionary<NSString *, NSString *> *row in [self featureRows]) {
        self.settings[row[@"key"]] = @YES;
    }
    [self saveSettings];
    [self.settingsWindow close];
    self.settingsWindow = [self buildSettingsWindow];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)resetSettings:(id)sender {
    for (NSDictionary *row in QRFeatureRows()) self.settings[row[@"key"]] = @YES;
    self.settings[@"contextualMenus"] = @YES;
    self.settings[@"menuOrder"] = @[];
    self.settings[@"pinnedFeatures"] = @[];
    [self saveSettings];
    [self rebuildSettingsWindow];
}

- (void)checkForUpdatesSilently {
    NSURL *url = [NSURL URLWithString:QRLatestReleaseAPI];
    if (!url) {
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:12];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.updateCheckFinished = YES;
                if ([self.settingsPage isEqualToString:@"update"]) {
                    [self rebuildSettingsWindow];
                }
            });
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:NSDictionary.class]) {
            return;
        }
        NSString *tag = json[@"tag_name"];
        NSString *htmlURL = json[@"html_url"];
        NSString *version = [self normalizedVersionFromTag:tag];
        NSString *downloadURL = [self downloadURLFromReleaseJSON:json fallback:htmlURL];
        BOOL isNewer = [self isVersion:version newerThanVersion:QRProductVersion];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.latestVersion = version;
            self.latestDownloadURL = downloadURL;
            self.updateAvailable = isNewer;
            self.updateCheckFinished = YES;
            if (isNewer) {
                self.settingsPage = @"update";
                [self showSettings:nil];
            } else if ([self.settingsPage isEqualToString:@"update"]) {
                [self rebuildSettingsWindow];
            }
        });
    }] resume];
}

- (NSString *)normalizedVersionFromTag:(NSString *)tag {
    if (![tag isKindOfClass:NSString.class]) {
        return nil;
    }
    if ([tag hasPrefix:@"v"] || [tag hasPrefix:@"V"]) {
        return [tag substringFromIndex:1];
    }
    return tag;
}

- (NSString *)downloadURLFromReleaseJSON:(NSDictionary *)json fallback:(NSString *)fallback {
    NSArray *assets = json[@"assets"];
    if ([assets isKindOfClass:NSArray.class]) {
        for (NSDictionary *asset in assets) {
            if (![asset isKindOfClass:NSDictionary.class]) {
                continue;
            }
            NSString *name = asset[@"name"];
            NSString *url = asset[@"browser_download_url"];
            if ([name containsString:@"macOS.zip"] && [url isKindOfClass:NSString.class]) {
                return url;
            }
        }
    }
    return [fallback isKindOfClass:NSString.class] ? fallback : QRReleasesURL;
}

- (BOOL)isVersion:(NSString *)candidate newerThanVersion:(NSString *)current {
    if (candidate.length == 0 || current.length == 0) {
        return NO;
    }
    NSArray<NSString *> *left = [candidate componentsSeparatedByString:@"."];
    NSArray<NSString *> *right = [current componentsSeparatedByString:@"."];
    NSInteger count = MAX(left.count, right.count);
    for (NSInteger i = 0; i < count; i++) {
        NSInteger a = i < left.count ? left[i].integerValue : 0;
        NSInteger b = i < right.count ? right[i].integerValue : 0;
        if (a > b) {
            return YES;
        }
        if (a < b) {
            return NO;
        }
    }
    return NO;
}

- (void)pollCommandFiles:(NSTimer *)timer {
    if (self.busy || NSApp.modalWindow) return;
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self commandDirectoryURL] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    files = [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) { return [a.lastPathComponent compare:b.lastPathComponent]; }];
    for (NSURL *file in files) {
        if (![file.pathExtension isEqualToString:@"cmd"]) continue;
        NSString *command = [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:NULL];
        if (!command) continue;
        if (![[NSFileManager defaultManager] removeItemAtURL:file error:NULL]) continue;
        [self handleCommandURLString:command source:@"command file"];
        break;
    }
}

- (NSURL *)commandDirectoryURL {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.liaowenbin.QuickRightMenu.Extension/Data/Library/Application Support/QuickRightMenuCommands"];
    return [NSURL fileURLWithPath:path];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    [self handleCommandURLString:urlString source:@"URL event"];
}

- (void)handleCommandURLString:(NSString *)urlString source:(NSString *)source {
    [self log:[NSString stringWithFormat:@"%@ %@", source, urlString ?: @""]];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString ?: @""];
    if (![components.scheme isEqualToString:@"quickrightmenu"]) {
        return;
    }

    NSString *command = components.host;
    NSMutableDictionary<NSString *, NSString *> *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        if (item.name && item.value) {
            params[item.name] = item.value;
        }
    }

    if (self.busy) { [self showError:@"当前操作尚未结束，请稍后再试。"]; return; }
    NSMutableSet *allowed = [NSMutableSet setWithArray:[QRFeatureRows() valueForKey:@"action"]];
    [allowed addObject:@"create"];
    for (NSInteger i = 1; i <= 3; i++) {
        [allowed addObject:[NSString stringWithFormat:@"copy-to-favorite%ld", (long)i]];
        [allowed addObject:[NSString stringWithFormat:@"move-to-favorite%ld", (long)i]];
    }
    if (![allowed containsObject:command]) return;
    NSString *directoryPath = params[@"dir"] ?: NSHomeDirectory();
    BOOL isDirectory = NO;
    if (!directoryPath.isAbsolutePath || ![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:&isDirectory] || !isDirectory) {
        [self showError:@"目标文件夹不存在或无法访问。"]; return;
    }
    NSURL *directory = [NSURL fileURLWithPath:directoryPath];
    NSArray *selected = [self pathListFromString:params[@"paths"] fallback:nil];
    if ([source isEqualToString:@"URL event"]) {
        NSAlert *confirm = [[NSAlert alloc] init]; confirm.messageText = @"执行外部链接请求的文件操作？";
        confirm.informativeText = [NSString stringWithFormat:@"操作：%@\n目录：%@\n所选文件：%lu", command, directory.path, (unsigned long)selected.count];
        [confirm addButtonWithTitle:@"执行"]; [confirm addButtonWithTitle:@"取消"];
        [NSApp activateIgnoringOtherApps:YES]; if ([confirm runModal] != NSAlertFirstButtonReturn) return;
    }
    if ([command hasPrefix:@"clipboard-"]) { [self saveClipboardAtDirectory:directory format:[command substringFromIndex:10]]; return; }
    if ([command hasPrefix:@"open-"]) { [self openPaths:selected directory:directory action:command]; return; }
    if ([command isEqualToString:@"project-create"] || [command isEqualToString:@"template-create"]) { [self createFromTemplateAtDirectory:directory imported:[command isEqualToString:@"template-create"]]; return; }
    if ([command hasPrefix:@"manifest-"]) { [self exportManifest:selected directory:directory format:[command substringFromIndex:9]]; return; }
    if ([command isEqualToString:@"pdf-images"] || [command isEqualToString:@"pdf-merge"]) { [self makePDF:selected directory:directory images:[command isEqualToString:@"pdf-images"]]; return; }
    if ([command isEqualToString:@"image-ocr"]) { [self recognizeImages:selected]; return; }
    if ([command isEqualToString:@"undo-last"]) { [self undoLastOperation:nil]; return; }
    if ([@[@"image-resize", @"image-target-size", @"image-strip-metadata", @"image-watermark", @"workflow-run"] containsObject:command]) { [self processImages:selected action:command]; return; }
    if ([command isEqualToString:@"create"]) {
        NSString *extension = params[@"ext"] ?: @"txt";
        if (![@[@"txt", @"md", @"json", @"csv", @"html", @"yaml", @"xml", @"sh", @"py", @"js", @"ts", @"css", @"docx", @"xlsx", @"pptx"] containsObject:extension]) { [self showError:@"不支持该文件类型。"]; return; }
        NSString *contents = [self templateForExtension:extension];
        [self createFileInDirectory:directory baseName:@"Untitled" extension:extension contents:contents];
    } else if ([command isEqualToString:@"copy-path"]) {
        [self copyValueToPasteboard:[self copyValueForMode:@"path" paths:params[@"paths"] directory:directory] label:@"paths"];
    } else if ([command isEqualToString:@"copy-name"]) {
        [self copyValueToPasteboard:[self copyValueForMode:@"name" paths:params[@"paths"] directory:directory] label:@"names"];
    } else if ([command isEqualToString:@"copy-parent"]) {
        [self copyValueToPasteboard:[self copyValueForMode:@"parent" paths:params[@"paths"] directory:directory] label:@"parents"];
    } else if ([command isEqualToString:@"copy-file-url"]) {
        [self copyValueToPasteboard:[self copyValueForMode:@"file-url" paths:params[@"paths"] directory:directory] label:@"file URLs"];
    } else if ([command isEqualToString:@"copy-markdown-link"]) {
        [self copyValueToPasteboard:[self copyValueForMode:@"markdown-link" paths:params[@"paths"] directory:directory] label:@"markdown links"];
    } else if ([command hasPrefix:@"copy-to-"]) {
        [self transferPaths:params[@"paths"] directory:directory destinationKey:[command substringFromIndex:@"copy-to-".length] move:NO];
    } else if ([command hasPrefix:@"move-to-"]) {
        [self transferPaths:params[@"paths"] directory:directory destinationKey:[command substringFromIndex:@"move-to-".length] move:YES];
    } else if ([command isEqualToString:@"batch-rename"]) {
        [self batchRenamePaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"image-copy-size"]) {
        [self copyImageSizesForPaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"image-compress"]) {
        [self compressImagesForPaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"image-convert-png"]) {
        [self convertImagesForPaths:params[@"paths"] directory:directory format:@"png"];
    } else if ([command isEqualToString:@"image-convert-jpeg"]) {
        [self convertImagesForPaths:params[@"paths"] directory:directory format:@"jpg"];
    } else if ([command isEqualToString:@"image-convert-webp"]) {
        [self convertImagesForPaths:params[@"paths"] directory:directory format:@"webp"];
    } else if ([command isEqualToString:@"text-stats"]) {
        [self showTextStatsForPaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"text-to-utf8"]) {
        [self convertTextFilesToUTF8ForPaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"text-preview"]) {
        [self previewTextForPaths:params[@"paths"] directory:directory];
    } else if ([command isEqualToString:@"terminal"]) {
        [self openTerminalAtDirectory:directory];
    } else {
        [self log:[NSString stringWithFormat:@"unknown command %@", command ?: @""]];
    }
}

- (NSString *)templateForExtension:(NSString *)extension {
    NSString *templateKey = [NSString stringWithFormat:@"template_%@", extension ?: @""];
    NSString *storedTemplate = self.settings[templateKey];
    if ([storedTemplate isKindOfClass:NSString.class]) {
        return storedTemplate;
    }
    if ([extension isEqualToString:@"md"]) {
        return @"# Untitled\n";
    }
    if ([extension isEqualToString:@"json"]) {
        return @"{\n  \n}\n";
    }
    if ([extension isEqualToString:@"html"]) {
        return @"<!doctype html>\n<html lang=\"zh-CN\">\n<head>\n  <meta charset=\"utf-8\">\n  <title>Untitled</title>\n</head>\n<body>\n\n</body>\n</html>\n";
    }
    if ([extension isEqualToString:@"yaml"] || [extension isEqualToString:@"yml"]) {
        return @"---\n";
    }
    if ([extension isEqualToString:@"xml"]) {
        return @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n\n</root>\n";
    }
    if ([extension isEqualToString:@"sh"]) {
        return @"#!/usr/bin/env bash\nset -euo pipefail\n\n";
    }
    if ([extension isEqualToString:@"py"]) {
        return @"#!/usr/bin/env python3\n\n";
    }
    if ([extension isEqualToString:@"js"]) {
        return @"";
    }
    if ([extension isEqualToString:@"ts"]) {
        return @"";
    }
    if ([extension isEqualToString:@"css"]) {
        return @":root {\n  color-scheme: light dark;\n}\n";
    }
    return @"";
}

- (void)createFileInDirectory:(NSURL *)directory baseName:(NSString *)baseName extension:(NSString *)extension contents:(NSString *)contents {
    NSURL *fileURL = [self uniqueFileURLInDirectory:directory baseName:baseName extension:extension];
    if ([self isOfficeExtension:extension]) {
        [self createOfficeFileAtURL:fileURL extension:extension];
        return;
    }

    NSError *error = nil;
    BOOL ok = QRWriteNewData([contents dataUsingEncoding:NSUTF8StringEncoding], fileURL, &error);
    if (ok) {
        [self log:[NSString stringWithFormat:@"created %@", fileURL.path]];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    } else {
        [self log:[NSString stringWithFormat:@"create failed %@", error.localizedDescription ?: @"unknown"]];
        [self showError:[NSString stringWithFormat:@"创建文件失败：%@", error.localizedDescription ?: @"未知错误"]];
        NSLog(@"QuickRightMenu create file failed: %@", error);
    }
}

- (BOOL)isOfficeExtension:(NSString *)extension {
    return [extension isEqualToString:@"docx"] || [extension isEqualToString:@"xlsx"] || [extension isEqualToString:@"pptx"];
}

- (void)createOfficeFileAtURL:(NSURL *)fileURL extension:(NSString *)extension {
    NSString *tempRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"QuickRightMenuOffice-%@-%u", NSUUID.UUID.UUIDString, arc4random_uniform(1000000)]];
    NSURL *tempURL = [NSURL fileURLWithPath:tempRoot];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL prepared = [fileManager createDirectoryAtURL:tempURL withIntermediateDirectories:YES attributes:nil error:&error];
    if (prepared) {
        prepared = [self writeOfficePackageAtURL:tempURL extension:extension error:&error];
    }
    NSURL *zipURL = [NSURL fileURLWithPath:[tempRoot stringByAppendingString:@".zip"]];
    if (prepared) prepared = [self zipDirectoryAtURL:tempURL toURL:zipURL error:&error];
    if (prepared) prepared = [fileManager moveItemAtURL:zipURL toURL:fileURL error:&error];
    [fileManager removeItemAtURL:zipURL error:NULL];
    [fileManager removeItemAtURL:tempURL error:nil];

    if (prepared) {
        [self log:[NSString stringWithFormat:@"created %@", fileURL.path]];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
    } else {
        [self log:[NSString stringWithFormat:@"office create failed %@", error.localizedDescription ?: @"unknown"]];
        [self showError:[NSString stringWithFormat:@"创建 Office 文件失败：%@", error.localizedDescription ?: @"未知错误"]];
    }
}

- (BOOL)writeOfficePackageAtURL:(NSURL *)rootURL extension:(NSString *)extension error:(NSError **)error {
    if ([extension isEqualToString:@"docx"]) {
        return [self writeOfficeFile:@"[Content_Types].xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"_rels/.rels" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"word/document.xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p/><w:sectPr><w:pgSz w:w=\"11906\" w:h=\"16838\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr></w:body></w:document>\n" rootURL:rootURL error:error];
    }
    if ([extension isEqualToString:@"xlsx"]) {
        return [self writeOfficeFile:@"[Content_Types].xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"_rels/.rels" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"xl/workbook.xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"xl/_rels/workbook.xml.rels" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"xl/worksheets/sheet1.xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>\n" rootURL:rootURL error:error];
    }
    if ([extension isEqualToString:@"pptx"]) {
        return [self writeOfficeFile:@"[Content_Types].xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/></Types>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"_rels/.rels" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/></Relationships>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"ppt/presentation.xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst><p:sldSz cx=\"9144000\" cy=\"5143500\" type=\"screen16x9\"/></p:presentation>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"ppt/_rels/presentation.xml.rels" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/></Relationships>\n" rootURL:rootURL error:error] &&
               [self writeOfficeFile:@"ppt/slides/slide1.xml" contents:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:sld xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld></p:sld>\n" rootURL:rootURL error:error];
    }
    return NO;
}

- (BOOL)writeOfficeFile:(NSString *)relativePath contents:(NSString *)contents rootURL:(NSURL *)rootURL error:(NSError **)error {
    NSURL *fileURL = [rootURL URLByAppendingPathComponent:relativePath];
    BOOL ok = [[NSFileManager defaultManager] createDirectoryAtURL:fileURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error];
    if (!ok) {
        return NO;
    }
    return [contents writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (BOOL)zipDirectoryAtURL:(NSURL *)directoryURL toURL:(NSURL *)fileURL error:(NSError **)error {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/zip";
    task.currentDirectoryURL = directoryURL;
    task.arguments = @[@"-qr", fileURL.path, @"."];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"QuickRightMenu" code:20 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"zip 执行失败"}];
        }
        return NO;
    }
    if (task.terminationStatus != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"QuickRightMenu" code:21 userInfo:@{NSLocalizedDescriptionKey: @"zip 打包失败"}];
        }
        return NO;
    }
    return YES;
}

- (NSPasteboard *)pasteboard { return NSPasteboard.generalPasteboard; }

- (void)copyValueToPasteboard:(NSString *)value label:(NSString *)label {
    NSPasteboard *pasteboard = [self pasteboard];
    [pasteboard clearContents];
    [pasteboard setString:value ?: @"" forType:NSPasteboardTypeString];
    [self log:[NSString stringWithFormat:@"copied %@ %@", label, value ?: @""]];
}

- (NSString *)copyValueForMode:(NSString *)mode paths:(NSString *)paths directory:(NSURL *)directory {
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:directory.path];
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    for (NSString *path in items) {
        if ([mode isEqualToString:@"path"]) {
            [values addObject:path];
        } else if ([mode isEqualToString:@"name"]) {
            [values addObject:path.lastPathComponent ?: @""];
        } else if ([mode isEqualToString:@"parent"]) {
            [values addObject:path.stringByDeletingLastPathComponent ?: @""];
        } else if ([mode isEqualToString:@"file-url"]) {
            [values addObject:[NSURL fileURLWithPath:path].absoluteString ?: @""];
        } else if ([mode isEqualToString:@"markdown-link"]) {
            NSString *name = path.lastPathComponent.length > 0 ? path.lastPathComponent : path;
            NSString *url = [NSURL fileURLWithPath:path].absoluteString ?: path;
            [values addObject:[NSString stringWithFormat:@"[%@](%@)", name, url]];
        }
    }
    return [values componentsJoinedByString:@"\n"];
}

- (NSArray<NSString *> *)pathListFromString:(NSString *)paths fallback:(NSString *)fallback {
    NSArray *items = QRPathsFromString(paths);
    return items.count ? items : (paths.length ? @[] : (fallback.length ? @[fallback] : @[]));
}

- (void)transferPaths:(NSString *)paths directory:(NSURL *)directory destinationKey:(NSString *)destinationKey move:(BOOL)move {
    NSURL *destination = [destinationKey isEqualToString:@"choose"] ? [self chooseDestinationDirectoryForMove:move] : [self destinationDirectoryForKey:destinationKey];
    if (!destination) return;
    NSArray *items = [self pathListFromString:paths fallback:nil];
    [self runBatch:move ? @"移动文件" : @"复制文件" items:items operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *from = [NSURL fileURLWithPath:path].URLByResolvingSymlinksInPath.path;
        NSString *to = destination.URLByResolvingSymlinksInPath.path;
        if ([to isEqualToString:from] || [to hasPrefix:[from stringByAppendingString:@"/"]]) { *error = QRError(@"不能复制或移动到自身内部"); return nil; }
        if (move && [path.stringByDeletingLastPathComponent isEqualToString:destination.path]) return @{@"message": @"已在目标文件夹，未移动"};
        if (![fm createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:error]) return nil;
        NSURL *target = QRUniqueURL(destination, path.lastPathComponent);
        if (move) {
            NSDictionary *undo = QRMoveFile(path, target.path, error);
            return undo ? @{@"output": target.path, @"undo": undo} : nil;
        }
        return [fm copyItemAtPath:path toPath:target.path error:error] ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (NSURL *)chooseDestinationDirectoryForMove:(BOOL)move {
    [NSApp activateIgnoringOtherApps:YES];

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = move ? @"选择移动到的文件夹" : @"选择复制到的文件夹";
    panel.prompt = move ? @"移动到这里" : @"复制到这里";
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = YES;

    NSModalResponse response = [panel runModal];
    if (response != NSModalResponseOK) {
        return nil;
    }
    return panel.URL;
}

- (NSURL *)destinationDirectoryForKey:(NSString *)key {
    if ([key.lowercaseString hasPrefix:@"favorite"]) {
        NSString *slot = [key.lowercaseString substringFromIndex:@"favorite".length];
        NSString *path = self.settings[[NSString stringWithFormat:@"favoriteDir%@Path", slot]];
        if ([path isKindOfClass:NSString.class] && path.length > 0) {
            return [NSURL fileURLWithPath:path];
        }
        return nil;
    }

    NSDictionary<NSString *, NSNumber *> *mapping = @{
        @"desktop": @(NSDesktopDirectory),
        @"documents": @(NSDocumentDirectory),
        @"downloads": @(NSDownloadsDirectory),
        @"pictures": @(NSPicturesDirectory),
        @"movies": @(NSMoviesDirectory),
        @"music": @(NSMusicDirectory)
    };
    NSNumber *directoryValue = mapping[key.lowercaseString];
    if (!directoryValue) {
        return nil;
    }

    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:directoryValue.unsignedIntegerValue inDomains:NSUserDomainMask];
    return urls.firstObject;
}

- (NSURL *)uniqueDestinationURLForSourceURL:(NSURL *)sourceURL inDirectory:(NSURL *)directory {
    return QRUniqueURL(directory, sourceURL.lastPathComponent);
}

- (void)batchRenamePaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray *items = [self pathListFromString:paths fallback:nil];
    if (!items.count) { [self showError:@"请先选中需要重命名的文件。"]; return; }
    NSAlert *alert = [[NSAlert alloc] init]; alert.messageText = @"批量重命名";
    alert.informativeText = @"保留文件扩展名。先预览，再执行；名称冲突时不会覆盖文件。";
    [alert addButtonWithTitle:@"预览"]; [alert addButtonWithTitle:@"取消"];
    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 170)];
    NSPopUpButton *mode = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 132, 490, 30)];
    [mode addItemsWithTitles:@[@"前缀＋序号", @"添加前缀", @"添加后缀", @"查找替换", @"添加今天日期"]];
    [mode setAccessibilityLabel:@"重命名方式"]; [form addSubview:mode];
    NSTextField *text = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 90, 490, 28)];
    text.placeholderString = @"前缀、后缀或查找内容"; [text setAccessibilityLabel:@"前缀、后缀或查找内容"]; [form addSubview:text];
    NSTextField *replacement = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 48, 490, 28)];
    replacement.placeholderString = @"替换为（仅查找替换使用，可留空）"; [replacement setAccessibilityLabel:@"替换为"]; [form addSubview:replacement];
    NSTextField *start = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 6, 490, 28)];
    start.stringValue = @"1"; start.placeholderString = @"起始序号"; [start setAccessibilityLabel:@"起始序号"]; [form addSubview:start];
    alert.accessoryView = form; [NSApp activateIgnoringOtherApps:YES];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSInteger number = 0; NSScanner *scan = [NSScanner scannerWithString:start.stringValue];
    if (![scan scanInteger:&number] || !scan.isAtEnd || number < 1 || number > 100000000) { [self showError:@"起始序号须为 1–100000000 的整数。"]; return; }
    NSDictionary *options = @{@"mode": @[@"number", @"prefix", @"suffix", @"replace", @"date"][mode.indexOfSelectedItem], @"text": text.stringValue, @"replacement": replacement.stringValue, @"start": @(number)};
    NSError *error = nil;
    NSArray *plan = QRRenamePlan(items, options, &error);
    if (!plan) { [self showError:error.localizedDescription]; return; }
    NSMutableString *preview = [NSMutableString string];
    NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
    NSMutableArray *changed = [NSMutableArray array];
    for (NSDictionary *entry in plan) {
        [preview appendFormat:@"%@ → %@%@\n", [entry[@"source"] lastPathComponent], [entry[@"target"] lastPathComponent], [entry[@"unchanged"] boolValue] ? @"（不变）" : @""];
        lookup[entry[@"source"]] = entry;
        if (![entry[@"unchanged"] boolValue]) [changed addObject:entry[@"source"]];
    }
    if (!changed.count) { [self showInfo:@"所有名称均未变化" details:@"请调整重命名规则。"]; return; }
    NSAlert *confirm = [[NSAlert alloc] init]; confirm.messageText = [NSString stringWithFormat:@"确认重命名 %lu 项", (unsigned long)changed.count];
    [confirm addButtonWithTitle:@"执行重命名"]; [confirm addButtonWithTitle:@"取消"];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 600, 300)]; scroll.hasVerticalScroller = YES;
    NSTextView *view = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds]; view.editable = NO; view.string = preview;
    view.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]; scroll.documentView = view; confirm.accessoryView = scroll;
    if ([confirm runModal] != NSAlertFirstButtonReturn) return;
    [self runBatch:@"批量重命名" items:changed operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **failure) {
        NSString *target = lookup[path][@"target"];
        NSDictionary *undo = QRMoveFile(path, target, failure);
        return undo ? @{@"output": target, @"undo": undo} : nil;
    } completion:nil];
}

- (void)copyImageSizesForPaths:(NSString *)paths directory:(NSURL *)directory {
    [self runBatch:@"读取图片尺寸" items:[self pathListFromString:paths fallback:nil] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSDictionary *info = [self imageInfoAtPath:path];
        if (!info) { *error = QRError(@"无法读取图片尺寸"); return nil; }
        NSString *text = [NSString stringWithFormat:@"%@: %@ × %@ px", path.lastPathComponent, info[@"width"], info[@"height"]];
        return @{@"text": text, @"message": text};
    } completion:^(NSArray *results) { [self copyBatchText:results title:@"图片尺寸（已复制）"]; }];
}

- (NSDictionary *)imageInfoAtPath:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) {
        return nil;
    }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    NSNumber *width = properties[(NSString *)kCGImagePropertyPixelWidth];
    NSNumber *height = properties[(NSString *)kCGImagePropertyPixelHeight];
    if (!width || !height) {
        return nil;
    }
    return @{@"width": width, @"height": height};
}

- (void)compressImagesForPaths:(NSString *)paths directory:(NSURL *)directory {
    [self convertImagesForPaths:paths directory:directory format:@"jpg-compressed"];
}

- (void)convertImagesForPaths:(NSString *)paths directory:(NSURL *)directory format:(NSString *)format {
    NSDictionary *options = @{@"format": [format isEqualToString:@"jpg-compressed"] ? @"jpg" : format,
                               @"quality": [format isEqualToString:@"jpg-compressed"] ? @0.72 : @0.9};
    [self runImageBatch:[self pathListFromString:paths fallback:nil] options:options title:@"处理图片"];
}

- (void)showTextStatsForPaths:(NSString *)paths directory:(NSURL *)directory {
    [self runBatch:@"统计文本" items:[self pathListFromString:paths fallback:nil] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSString *text = [self textContentsAtPath:path usedEncoding:NULL];
        if (!text) { *error = QRError(@"无法读取文本或识别编码"); return nil; }
        NSString *normalized = [[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
        __block NSUInteger characters = 0;
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange range, NSRange enclosing, BOOL *stop) {
            if ([substring stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) characters++;
            if (progress.cancelled) *stop = YES;
        }];
        if (progress.cancelled) { *error = QRError(@"已取消"); return nil; }
        NSUInteger words = 0;
        for (NSString *word in [text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]) if (word.length) words++;
        NSUInteger lines = normalized.length ? [normalized componentsSeparatedByString:@"\n"].count : 0;
        NSString *result = [NSString stringWithFormat:@"%@: 字符 %lu，空白分隔词 %lu，行 %lu", path.lastPathComponent, (unsigned long)characters, (unsigned long)words, (unsigned long)lines];
        return @{@"text": result, @"message": result};
    } completion:^(NSArray *results) { [self copyBatchText:results title:@"文本统计（已复制）"]; }];
}

- (void)convertTextFilesToUTF8ForPaths:(NSString *)paths directory:(NSURL *)directory {
    [self runBatch:@"转 UTF-8" items:[self pathListFromString:paths fallback:nil] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSString *text = [self textContentsAtPath:path usedEncoding:NULL];
        if (!text) { *error = QRError(@"无法读取文本或识别编码"); return nil; }
        NSURL *target = [self utf8TargetURLForSourceURL:[NSURL fileURLWithPath:path]];
        return QRWriteNewData([text dataUsingEncoding:NSUTF8StringEncoding], target, error) ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (NSURL *)utf8TargetURLForSourceURL:(NSURL *)sourceURL {
    NSString *extension = sourceURL.pathExtension;
    NSString *baseName = sourceURL.lastPathComponent.stringByDeletingPathExtension;
    NSString *filename = extension.length > 0
        ? [NSString stringWithFormat:@"%@-utf8.%@", baseName.length > 0 ? baseName : @"Untitled", extension]
        : [NSString stringWithFormat:@"%@-utf8", baseName.length > 0 ? baseName : @"Untitled"];
    NSURL *targetURL = [sourceURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:filename];
    return [self uniqueDestinationURLForSourceURL:targetURL inDirectory:sourceURL.URLByDeletingLastPathComponent];
}

- (void)previewTextForPaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray *items = [self pathListFromString:paths fallback:nil];
    if (!items.count) { [self showError:@"请选择文本文件。"]; return; }
    [self runBatch:@"读取文本预览" items:@[items.firstObject] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSString *text = [self textContentsAtPath:path usedEncoding:NULL];
        if (!text) { *error = QRError(@"无法读取文本或识别编码"); return nil; }
        return @{@"text": text, @"message": @"文本已读取"};
    } completion:^(NSArray *results) {
        NSString *text = [results.firstObject objectForKey:@"text"];
        if (text) [self showTextPreview:text title:[items.firstObject lastPathComponent]];
    }];
}

- (void)showTemplateSettings:(id)sender {
    self.settingsPage = @"templates";
    [self rebuildSettingsWindow];
}

- (void)templateExtensionChanged:(id)sender {
    NSString *extension = self.templatePopup.titleOfSelectedItem ?: @"txt";
    NSString *key = [NSString stringWithFormat:@"template_%@", extension];
    self.templateTextView.string = self.settings[key] ?: @"";
}

- (void)saveTemplatePage:(id)sender {
    NSString *extension = self.templatePopup.titleOfSelectedItem ?: @"txt";
    NSString *key = [NSString stringWithFormat:@"template_%@", extension];
    self.settings[key] = self.templateTextView.string ?: @"";
    [self saveSettings];
}

- (void)resetSelectedTemplate:(id)sender {
    NSString *extension = self.templatePopup.titleOfSelectedItem ?: @"txt";
    NSString *key = [NSString stringWithFormat:@"template_%@", extension];
    self.settings[key] = [self defaultSettings][key] ?: @"";
    [self saveSettings];
    [self templateExtensionChanged:self.templatePopup];
}

- (void)showFavoriteDirectorySettings:(id)sender {
    self.settingsPage = @"favorites";
    [self rebuildSettingsWindow];
}

- (void)chooseFavoriteDirectoryButton:(NSButton *)sender {
    [self chooseFavoriteDirectoryForSlot:sender.tag];
}

- (void)clearFavoriteDirectories:(id)sender {
    for (NSInteger i = 1; i <= 3; i++) {
        self.settings[[NSString stringWithFormat:@"favoriteDir%ldName", (long)i]] = @"";
        self.settings[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)i]] = @"";
    }
    [self saveSettings];
    self.settingsPage = @"favorites";
    [self rebuildSettingsWindow];
}

- (void)chooseFavoriteDirectoryForSlot:(NSInteger)slot {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [NSString stringWithFormat:@"设置常用目录 %ld", (long)slot];
    panel.prompt = @"使用这个目录";
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;
    panel.canCreateDirectories = YES;
    [NSApp activateIgnoringOtherApps:YES];
    if ([panel runModal] != NSModalResponseOK || !panel.URL.path) {
        return;
    }
    NSString *name = panel.URL.lastPathComponent.length > 0 ? panel.URL.lastPathComponent : panel.URL.path;
    self.settings[[NSString stringWithFormat:@"favoriteDir%ldName", (long)slot]] = name;
    self.settings[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)slot]] = panel.URL.path;
    [self saveSettings];
    self.settingsPage = @"favorites";
    [self rebuildSettingsWindow];
}

- (void)showTerminalSettings:(id)sender {
    self.settingsPage = @"terminal";
    [self rebuildSettingsWindow];
}

- (void)saveTerminalPage:(id)sender {
    NSString *selected = self.terminalPopup.titleOfSelectedItem ?: @"Terminal";
    if ([selected isEqualToString:@"iTerm2"]) {
        self.settings[@"terminalPreference"] = @"iterm";
    } else if ([selected isEqualToString:@"Warp"]) {
        self.settings[@"terminalPreference"] = @"warp";
    } else {
        self.settings[@"terminalPreference"] = @"terminal";
    }
    [self saveSettings];
}

- (void)toggleLoginItem:(id)sender {
    if ([self isLoginItemEnabled]) {
        [[NSFileManager defaultManager] removeItemAtURL:[self loginAgentURL] error:nil];
    } else {
        [self enableLoginItem];
    }
    self.settingsPage = @"login";
    [self rebuildSettingsWindow];
}

- (NSURL *)loginAgentURL {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/com.liaowenbin.QuickRightMenu.plist"];
    return [NSURL fileURLWithPath:path];
}

- (BOOL)isLoginItemEnabled {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self loginAgentURL].path];
}

- (void)enableLoginItem {
    NSURL *url = [self loginAgentURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *appPath = [NSBundle mainBundle].bundlePath;
    NSString *plist = [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
         "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
         "<plist version=\"1.0\">\n"
         "<dict>\n"
         "  <key>Label</key>\n"
         "  <string>com.liaowenbin.QuickRightMenu</string>\n"
         "  <key>ProgramArguments</key>\n"
         "  <array>\n"
         "    <string>/usr/bin/open</string>\n"
         "    <string>%@</string>\n"
         "  </array>\n"
         "  <key>RunAtLoad</key>\n"
         "  <true/>\n"
         "</dict>\n"
         "</plist>\n", [self xmlEscapedString:appPath]];
    NSError *error = nil;
    BOOL ok = [plist writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!ok) {
        [self showError:[NSString stringWithFormat:@"开启开机启动失败：%@", error.localizedDescription ?: @"未知错误"]];
    }
}

- (NSString *)xmlEscapedString:(NSString *)value {
    NSMutableString *result = [value mutableCopy];
    [result replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, result.length)];
    return result;
}

- (NSString *)textContentsAtPath:(NSString *)path usedEncoding:(NSStringEncoding *)usedEncoding {
    NSError *error = nil;
    NSStringEncoding encoding = 0;
    NSString *text = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error];
    if (!text) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }
    if (usedEncoding) {
        *usedEncoding = encoding;
    }
    return text;
}

- (void)showTextPreview:(NSString *)text title:(NSString *)title {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 560)
                                                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = title;
    window.releasedWhenClosed = NO;
    [window center];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:window.contentView.bounds];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;

    NSTextView *textView = [[NSTextView alloc] initWithFrame:scrollView.contentView.bounds];
    textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    textView.editable = NO;
    textView.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    textView.string = text ?: @"";
    scrollView.documentView = textView;
    window.contentView = scrollView;

    self.textPreviewWindow = window;
    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:nil];
}

- (NSURL *)uniqueFileURLInDirectory:(NSURL *)directory baseName:(NSString *)baseName extension:(NSString *)extension {
    return QRUniqueURL(directory, [baseName stringByAppendingPathExtension:extension]);
}

- (void)openTerminalAtDirectory:(NSURL *)directory {
    NSString *preference = self.settings[@"terminalPreference"] ?: @"terminal";
    NSString *bundleIdentifier = @"com.apple.Terminal";
    NSString *displayName = @"Terminal.app";
    if ([preference isEqualToString:@"iterm"]) {
        bundleIdentifier = @"com.googlecode.iterm2";
        displayName = @"iTerm2.app";
    } else if ([preference isEqualToString:@"warp"]) {
        bundleIdentifier = @"dev.warp.Warp-Stable";
        displayName = @"Warp.app";
    }

    NSURL *terminalURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleIdentifier];
    if (!terminalURL) {
        [self showError:[NSString stringWithFormat:@"找不到 %@", displayName]];
        return;
    }

    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
    configuration.activates = YES;
    [[NSWorkspace sharedWorkspace] openURLs:@[directory]
                       withApplicationAtURL:terminalURL
                               configuration:configuration
                           completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if (error) {
            [self log:[NSString stringWithFormat:@"open terminal failed %@", error.localizedDescription ?: @"unknown"]];
            [self showError:[NSString stringWithFormat:@"打开终端失败：%@", error.localizedDescription ?: @"未知错误"]];
            NSLog(@"QuickRightMenu open terminal failed: %@", error);
        }
    }];
}

- (void)log:(NSString *)message {
    NSLog(@"QuickRightMenu App: %@", message);
    NSString *line = [NSString stringWithFormat:@"%@ App: %@\n", [NSDate date], message];
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/QuickRightMenu.log"];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:url error:nil];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToURL:url atomically:YES];
    }
}

- (void)showInfo:(NSString *)message details:(NSString *)details {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = message;
        alert.informativeText = details ?: @"";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    });
}

- (void)showError:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = QRProductName;
        alert.informativeText = message;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    });
}

- (void)pinFeatureChanged:(NSButton *)sender {
    NSMutableArray *pins = [self.settings[@"pinnedFeatures"] mutableCopy];
    [pins removeObject:sender.identifier];
    if (sender.state == NSControlStateValueOn) [pins addObject:sender.identifier];
    self.settings[@"pinnedFeatures"] = pins;
    [self saveSettings];
}

- (void)moveFeature:(NSButton *)sender {
    NSPoint origin = self.menuScrollView.contentView.bounds.origin;
    NSMutableArray *order = [[[self featureRows] valueForKey:@"key"] mutableCopy];
    NSInteger index = [order indexOfObject:sender.identifier], other = index + sender.tag;
    if (index == NSNotFound || other < 0 || other >= order.count) return;
    [order exchangeObjectAtIndex:index withObjectAtIndex:other];
    self.settings[@"menuOrder"] = order;
    [self saveSettings];
    [self rebuildSettingsWindow];
    [self.menuScrollView.documentView scrollPoint:origin];
}

- (NSTextField *)inputWithValue:(NSString *)value label:(NSString *)label y:(CGFloat)y inView:(NSView *)root {
    NSTextField *caption = [self labelWithText:label size:13 bold:NO color:NSColor.labelColor];
    caption.frame = NSMakeRect(276, y, 170, 26); [root addSubview:caption];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(448, y, 388, 26)];
    input.stringValue = value ?: @"";
    [input setAccessibilityLabel:label];
    [root addSubview:input];
    return input;
}

- (void)addPresetPageToView:(NSView *)root {
    [self addPageTitle:@"图片处理组合" hint:@"保存常用设置，再从图片右键菜单一次执行。原图始终保留。" toView:root];
    self.presetPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(276, 476, 330, 30)];
    for (NSDictionary *preset in self.settings[@"imagePresets"]) [self.presetPopup addItemWithTitle:preset[@"name"]];
    self.presetPopup.target = self; self.presetPopup.action = @selector(presetSelectionChanged:);
    [self.presetPopup setAccessibilityLabel:@"已保存的处理组合"];
    [root addSubview:self.presetPopup];
    NSButton *add = [NSButton buttonWithTitle:@"新建" target:self action:@selector(newPreset:)];
    add.frame = NSMakeRect(620, 476, 88, 30); [root addSubview:add];
    NSButton *remove = [NSButton buttonWithTitle:@"删除" target:self action:@selector(deletePreset:)];
    remove.frame = NSMakeRect(720, 476, 88, 30); [root addSubview:remove];
    self.presetName = [self inputWithValue:@"" label:@"组合名称" y:427 inView:root];
    self.presetMaxSide = [self inputWithValue:@"1920" label:@"最长边 px（0 不缩放）" y:383 inView:root];
    self.presetTargetMB = [self inputWithValue:@"1" label:@"目标 MB（0 不限）" y:339 inView:root];
    NSTextField *format = [self labelWithText:@"输出格式" size:13 bold:NO color:NSColor.labelColor];
    format.frame = NSMakeRect(276, 295, 170, 26); [root addSubview:format];
    self.presetFormat = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(448, 295, 160, 28)];
    [self.presetFormat addItemsWithTitles:@[@"JPEG", @"PNG"]];
    [self.presetFormat setAccessibilityLabel:@"输出格式"]; [root addSubview:self.presetFormat];
    self.presetStripMetadata = [NSButton checkboxWithTitle:@"去除定位、相机等元数据" target:nil action:nil];
    self.presetStripMetadata.frame = NSMakeRect(448, 251, 385, 28); [root addSubview:self.presetStripMetadata];
    self.presetWatermark = [self inputWithValue:@"" label:@"水印文字（可留空）" y:207 inView:root];
    self.presetDirectory = [self inputWithValue:@"" label:@"输出文件夹" y:163 inView:root];
    self.presetDirectory.editable = NO; self.presetDirectory.selectable = YES;
    self.presetDirectory.placeholderString = @"原文件旁的“已处理”文件夹";
    NSButton *choose = [NSButton buttonWithTitle:@"选择输出目录…" target:self action:@selector(choosePresetDirectory:)];
    choose.frame = NSMakeRect(448, 117, 155, 30); [root addSubview:choose];
    NSButton *clear = [NSButton buttonWithTitle:@"恢复原文件旁" target:self action:@selector(clearPresetDirectory:)];
    clear.frame = NSMakeRect(615, 117, 150, 30); [root addSubview:clear];
    NSButton *save = [NSButton buttonWithTitle:@"保存组合" target:self action:@selector(savePreset:)];
    save.frame = NSMakeRect(276, 56, 115, 34); [root addSubview:save];
    NSTextField *hint = [self labelWithText:@"目标体积仅用于 JPEG；必要时会继续降低尺寸和画质。" size:11 bold:NO color:NSColor.secondaryLabelColor];
    hint.frame = NSMakeRect(408, 57, 440, 34); [root addSubview:hint];
    [self presetSelectionChanged:nil];
}

- (void)populatePreset:(NSDictionary *)preset {
    self.presetName.stringValue = preset[@"name"] ?: @"新组合";
    self.presetMaxSide.stringValue = [preset[@"maxSide"] stringValue] ?: @"1920";
    self.presetTargetMB.stringValue = [NSString stringWithFormat:@"%g", [preset[@"targetBytes"] doubleValue] / 1000000.0];
    [self.presetFormat selectItemAtIndex:[preset[@"format"] isEqualToString:@"png"] ? 1 : 0];
    self.presetStripMetadata.state = [preset[@"stripMetadata"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    self.presetWatermark.stringValue = preset[@"watermark"] ?: @"";
    self.presetDirectory.stringValue = preset[@"directory"] ?: @"";
}

- (void)presetSelectionChanged:(id)sender {
    NSInteger index = self.presetPopup.indexOfSelectedItem;
    NSArray *presets = self.settings[@"imagePresets"];
    [self populatePreset:index >= 0 && index < presets.count ? presets[index] : @{@"stripMetadata": @YES}];
}

- (void)newPreset:(id)sender {
    [self.presetPopup selectItem:nil];
    [self populatePreset:@{@"name": @"新组合", @"maxSide": @1920, @"targetBytes": @1000000, @"stripMetadata": @YES}];
}

- (void)deletePreset:(id)sender {
    NSInteger index = self.presetPopup.indexOfSelectedItem;
    NSMutableArray *presets = [self.settings[@"imagePresets"] mutableCopy];
    if (index < 0 || index >= presets.count) return;
    [presets removeObjectAtIndex:index]; self.settings[@"imagePresets"] = presets;
    [self saveSettings]; [self rebuildSettingsWindow];
}

- (void)choosePresetDirectory:(id)sender {
    NSURL *directory = [self chooseDestinationDirectoryForMove:NO];
    if (directory) self.presetDirectory.stringValue = directory.path;
}

- (void)clearPresetDirectory:(id)sender { self.presetDirectory.stringValue = @""; }

- (void)savePreset:(id)sender {
    NSScanner *sideScanner = [NSScanner scannerWithString:self.presetMaxSide.stringValue];
    NSScanner *mbScanner = [NSScanner scannerWithString:self.presetTargetMB.stringValue];
    NSInteger side = 0; double megabytes = 0;
    NSString *name = [self.presetName.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!name.length || ![sideScanner scanInteger:&side] || !sideScanner.isAtEnd || side < 0 || side > 30000 ||
        ![mbScanner scanDouble:&megabytes] || !mbScanner.isAtEnd || !isfinite(megabytes) || megabytes < 0 || megabytes > 100 ||
        (megabytes > 0 && megabytes < 0.01) || self.presetWatermark.stringValue.length > 120) {
        [self showError:@"请输入组合名称、0–30000 的整数尺寸和 0 或 0.01–100 MB 的目标体积；水印最多 120 字。"]; return;
    }
    NSString *format = self.presetFormat.indexOfSelectedItem == 1 ? @"png" : @"jpg";
    if (megabytes > 0 && [format isEqualToString:@"png"]) { [self showError:@"PNG 请把目标 MB 设为 0，或改为 JPEG。"]; return; }
    NSDictionary *preset = @{@"name": name, @"format": format, @"maxSide": @(side), @"targetBytes": @((long long)(megabytes * 1000000)),
                              @"stripMetadata": @(self.presetStripMetadata.state == NSControlStateValueOn),
                              @"watermark": self.presetWatermark.stringValue, @"directory": self.presetDirectory.stringValue};
    NSMutableArray *presets = [self.settings[@"imagePresets"] mutableCopy];
    NSInteger index = self.presetPopup.indexOfSelectedItem;
    for (NSUInteger i = 0; i < presets.count; i++) if (i != index && [presets[i][@"name"] isEqualToString:name]) { [self showError:@"已有同名组合，请使用不同名称。"]; return; }
    if (index >= 0 && index < presets.count) presets[index] = preset; else [presets addObject:preset];
    self.settings[@"imagePresets"] = presets;
    [self saveSettings]; [self rebuildSettingsWindow];
    [self.presetPopup selectItemWithTitle:name]; [self presetSelectionChanged:nil];
}

- (NSString *)askForText:(NSString *)title hint:(NSString *)hint value:(NSString *)value {
    NSAlert *alert = [[NSAlert alloc] init]; alert.messageText = title; alert.informativeText = hint;
    [alert addButtonWithTitle:@"继续"]; [alert addButtonWithTitle:@"取消"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 420, 28)];
    field.stringValue = value ?: @""; [field setAccessibilityLabel:title];
    alert.accessoryView = field; [NSApp activateIgnoringOtherApps:YES];
    [alert.window setInitialFirstResponder:field];
    return [alert runModal] == NSAlertFirstButtonReturn ? field.stringValue : nil;
}

- (NSInteger)chooseEntry:(NSArray<NSDictionary *> *)entries title:(NSString *)title {
    if (!entries.count) { [self showError:@"还没有可用项目，请先在设置中添加。"]; return -1; }
    NSAlert *alert = [[NSAlert alloc] init]; alert.messageText = title;
    [alert addButtonWithTitle:@"继续"]; [alert addButtonWithTitle:@"取消"];
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 420, 30)];
    for (NSDictionary *entry in entries) [popup addItemWithTitle:entry[@"name"]];
    [popup setAccessibilityLabel:title]; alert.accessoryView = popup;
    [NSApp activateIgnoringOtherApps:YES];
    return [alert runModal] == NSAlertFirstButtonReturn ? popup.indexOfSelectedItem : -1;
}

- (void)runBatch:(NSString *)title items:(NSArray<NSString *> *)items operation:(NSDictionary *(^)(NSString *, NSProgress *, NSError **))operation completion:(void (^)(NSArray<NSDictionary *> *))completion {
    if (self.busy) { [self showError:@"当前操作尚未结束，请等待完成或取消后再试。"]; return; }
    if (!items.count) { [self showError:@"请先在 Finder 中选择文件。"]; return; }
    self.busy = YES;
    self.jobProgress = [NSProgress progressWithTotalUnitCount:items.count];
    self.jobOutputs = @[];
    [self.jobWindow close];
    self.jobWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 450) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.jobWindow.releasedWhenClosed = NO; self.jobWindow.title = title; [self.jobWindow center];
    NSView *root = self.jobWindow.contentView;
    self.jobStatus = [self labelWithText:@"准备执行…" size:15 bold:YES color:NSColor.labelColor];
    self.jobStatus.frame = NSMakeRect(24, 402, 650, 26); [root addSubview:self.jobStatus];
    self.jobIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(24, 374, 650, 16)];
    self.jobIndicator.indeterminate = NO; self.jobIndicator.maxValue = items.count; [root addSubview:self.jobIndicator];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 650, 285)]; scroll.hasVerticalScroller = YES;
    self.jobDetails = [[NSTextView alloc] initWithFrame:scroll.contentView.bounds];
    self.jobDetails.editable = NO; self.jobDetails.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    scroll.documentView = self.jobDetails; [root addSubview:scroll];
    self.jobCancelButton = [NSButton buttonWithTitle:@"取消后续项目" target:self action:@selector(cancelCurrentOperation:)];
    self.jobCancelButton.frame = NSMakeRect(24, 22, 150, 32); [root addSubview:self.jobCancelButton];
    NSButton *reveal = [NSButton buttonWithTitle:@"在 Finder 查看结果" target:self action:@selector(revealJobOutputs:)];
    reveal.frame = NSMakeRect(184, 22, 170, 32); [root addSubview:reveal];
    NSButton *undo = [NSButton buttonWithTitle:@"撤销上次移动/重命名" target:self action:@selector(undoLastOperation:)];
    undo.frame = NSMakeRect(370, 22, 195, 32); [root addSubview:undo];
    [NSApp activateIgnoringOtherApps:YES]; [self.jobWindow makeKeyAndOrderFront:nil];
    NSProgress *progress = self.jobProgress;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        NSUInteger failures = 0;
        for (NSString *item in items) {
            if (progress.cancelled) break;
            @autoreleasepool {
                dispatch_async(dispatch_get_main_queue(), ^{ self.jobStatus.stringValue = [NSString stringWithFormat:@"正在处理：%@", item.lastPathComponent]; });
                NSError *error = nil;
                NSDictionary *result = nil;
                @try { result = operation(item, progress, &error); }
                @catch (NSException *exception) { error = QRError(exception.reason ?: @"处理文件时发生异常"); }
                if (!result && !error) error = QRError(@"操作未返回结果");
                if (error) failures++;
                NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:result ?: @{}];
                entry[@"source"] = item;
                if (error) entry[@"error"] = error.localizedDescription;
                [results addObject:entry];
                progress.completedUnitCount++;
                NSString *line = [NSString stringWithFormat:@"%@ %@\n%@\n\n", error ? @"失败" : @"完成", item, error.localizedDescription ?: result[@"message"] ?: result[@"output"] ?: @""];
                double count = progress.completedUnitCount;
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.jobIndicator.doubleValue = count;
                    [self.jobDetails.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:line]];
                    [self.jobDetails scrollRangeToVisible:NSMakeRange(self.jobDetails.string.length, 0)];
                });
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO; self.jobCancelButton.enabled = NO;
            NSMutableArray *outputs = [NSMutableArray array], *undo = [NSMutableArray array];
            for (NSDictionary *result in results) {
                if (result[@"output"]) [outputs addObject:[NSURL fileURLWithPath:result[@"output"]]];
                if (result[@"undo"]) [undo addObject:result[@"undo"]];
            }
            self.jobOutputs = outputs;
            if (undo.count) self.undoRecords = undo;
            self.jobStatus.stringValue = [NSString stringWithFormat:@"%@：成功 %lu，失败 %lu，未执行 %lu", progress.cancelled ? @"已取消" : @"已完成", (unsigned long)(results.count - failures), (unsigned long)failures, (unsigned long)(items.count - results.count)];
            if (completion) completion(results);
        });
    });
}

- (void)cancelCurrentOperation:(id)sender {
    [self.jobProgress cancel];
    self.jobCancelButton.enabled = NO;
    self.jobStatus.stringValue = @"正在取消；正在进行的文件复制或识别会先结束。";
}

- (void)showRecentOperation:(id)sender {
    if (!self.jobWindow) { [self showInfo:@"暂无操作记录" details:@"批量处理结果会显示在这里。"]; return; }
    [NSApp activateIgnoringOtherApps:YES]; [self.jobWindow makeKeyAndOrderFront:nil];
}

- (void)revealJobOutputs:(id)sender {
    NSMutableArray *existing = [NSMutableArray array];
    for (NSURL *url in self.jobOutputs) if (QRPathExists(url.path)) [existing addObject:url];
    if (existing.count) [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:existing];
}

- (void)undoLastOperation:(id)sender {
    if (self.busy) { [self showError:@"请等待当前操作结束。"]; return; }
    if (!self.undoRecords.count) { [self showInfo:@"暂无可撤销操作" details:@"保留本次运行中最近一批移动或重命名记录。"]; return; }
    NSAlert *alert = [[NSAlert alloc] init]; alert.messageText = @"撤销上次移动或重命名？";
    alert.informativeText = [NSString stringWithFormat:@"共 %lu 项。文件被修改或原位置已被占用时会跳过，失败项保留以便重试。", (unsigned long)self.undoRecords.count];
    [alert addButtonWithTitle:@"撤销"]; [alert addButtonWithTitle:@"取消"];
    [NSApp activateIgnoringOtherApps:YES]; if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSArray *records = [[self.undoRecords reverseObjectEnumerator] allObjects];
    NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
    for (NSDictionary *record in records) lookup[record[@"target"]] = record;
    NSMutableSet *done = [NSMutableSet set];
    [self runBatch:@"撤销文件操作" items:[records valueForKey:@"target"] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSDictionary *record = lookup[path];
        if (!QRUndoMove(record, error)) return nil;
        [done addObject:path];
        return @{@"output": record[@"source"]};
    } completion:^(NSArray *results) {
        NSMutableArray *remaining = [NSMutableArray array];
        for (NSDictionary *record in records) if (![done containsObject:record[@"target"]]) [remaining addObject:record];
        self.undoRecords = remaining;
    }];
}

- (void)saveClipboardAtDirectory:(NSURL *)directory format:(NSString *)format {
    NSPasteboard *pasteboard = [self pasteboard];
    NSData *data = nil;
    if ([format isEqualToString:@"png"]) {
        NSArray<NSImage *> *images = [pasteboard readObjectsForClasses:@[NSImage.class] options:@{}];
        NSImage *image = images.firstObject;
        if (!image) { [self showError:@"剪贴板中没有可保存的图片。"]; return; }
        CGImageRef cg = [image CGImageForProposedRect:NULL context:nil hints:nil];
        if (cg) data = [[[NSBitmapImageRep alloc] initWithCGImage:cg] representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    } else {
        NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
        if (!text) { [self showError:@"剪贴板中没有文字。"]; return; }
        data = [text dataUsingEncoding:NSUTF8StringEncoding];
    }
    if (!data) { [self showError:@"无法读取剪贴板内容。"]; return; }
    NSData *snapshot = [data copy];
    [self runBatch:@"保存剪贴板" items:@[directory.path] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSURL *target = QRUniqueURL(directory, [@"Clipboard" stringByAppendingPathExtension:format]);
        return QRWriteNewData(snapshot, target, error) ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (NSURL *)chooseApplication {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"选择应用"; panel.prompt = @"使用这个应用";
    panel.canChooseDirectories = NO; panel.canChooseFiles = YES; panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[UTTypeApplicationBundle]; panel.directoryURL = [NSURL fileURLWithPath:@"/Applications"];
    [NSApp activateIgnoringOtherApps:YES];
    return [panel runModal] == NSModalResponseOK ? panel.URL : nil;
}

- (void)choosePreferredApplication:(id)sender {
    NSURL *url = [self chooseApplication];
    if (!url) return;
    self.settings[@"preferredApplication"] = url.path; [self saveSettings]; [self rebuildSettingsWindow];
}

- (void)openPaths:(NSArray<NSString *> *)paths directory:(NSURL *)directory action:(NSString *)action {
    NSURL *application = nil;
    if ([action isEqualToString:@"open-choose"]) application = [self chooseApplication];
    else if ([action isEqualToString:@"open-preferred"]) {
        NSString *path = self.settings[@"preferredApplication"];
        if (path.length) application = [NSURL fileURLWithPath:path];
        else { application = [self chooseApplication]; if (application) { self.settings[@"preferredApplication"] = application.path; [self saveSettings]; } }
    } else application = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:[action isEqualToString:@"open-vscode"] ? @"com.microsoft.VSCode" : @"com.todesktop.230313mzl4w4u92"];
    if (!application) { if (![action isEqualToString:@"open-choose"]) [self showError:@"未找到所选应用。可以在设置 → 打开方式中选择已安装的应用。"]; return; }
    NSMutableArray *urls = [NSMutableArray array];
    for (NSString *path in paths) [urls addObject:[NSURL fileURLWithPath:path]];
    if (!urls.count) [urls addObject:directory];
    NSWorkspaceOpenConfiguration *config = [NSWorkspaceOpenConfiguration configuration]; config.activates = YES;
    [[NSWorkspace sharedWorkspace] openURLs:urls withApplicationAtURL:application configuration:config completionHandler:^(NSRunningApplication *app, NSError *error) {
        if (error) [self showError:error.localizedDescription];
    }];
}

- (void)importTemplate:(id)sender {
    if (self.busy) { [self showError:@"请等待当前操作完成。"]; return; }
    NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.title = @"导入文件或文件夹模板";
    panel.canChooseFiles = YES; panel.canChooseDirectories = YES; panel.allowsMultipleSelection = NO;
    if ([panel runModal] != NSModalResponseOK) return;
    NSURL *source = panel.URL;
    NSURL *templates = [[self settingsURL].URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Templates" isDirectory:YES];
    NSString *displayName = source.lastPathComponent;
    [self runBatch:@"导入模板" items:@[source.path] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:templates withIntermediateDirectories:YES attributes:nil error:error]) return nil;
        NSURL *copy = QRCopyTemplate(source, templates, [NSString stringWithFormat:@"%@-%@", NSUUID.UUID.UUIDString, displayName], error);
        return copy ? @{@"output": copy.path} : nil;
    } completion:^(NSArray *results) {
        NSString *path = [results.firstObject objectForKey:@"output"];
        if (!path) return;
        NSMutableArray *templates = [self.settings[@"importedTemplates"] mutableCopy];
        NSString *name = displayName;
        NSArray *names = [templates valueForKey:@"name"];
        for (NSUInteger suffix = 2; [names containsObject:name]; suffix++) {
            NSString *base = displayName.stringByDeletingPathExtension;
            name = [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)suffix];
            if (displayName.pathExtension.length) name = [name stringByAppendingPathExtension:displayName.pathExtension];
        }
        [templates addObject:@{@"name": name, @"path": path}]; self.settings[@"importedTemplates"] = templates;
        [self saveSettings]; if ([self.settingsPage isEqualToString:@"templates"]) [self rebuildSettingsWindow];
    }];
}

- (void)removeImportedTemplate:(id)sender {
    NSInteger index = self.importedTemplatePopup.indexOfSelectedItem;
    NSMutableArray *entries = [self.settings[@"importedTemplates"] mutableCopy];
    if (index < 0 || index >= entries.count || self.busy) return;
    NSString *path = entries[index][@"path"];
    NSString *managed = [[[self settingsURL].URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Templates"].path stringByAppendingString:@"/"];
    if ([path.stringByStandardizingPath hasPrefix:managed] && QRPathExists(path)) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] trashItemAtURL:[NSURL fileURLWithPath:path] resultingItemURL:NULL error:&error]) { [self showError:error.localizedDescription]; return; }
    }
    [entries removeObjectAtIndex:index]; self.settings[@"importedTemplates"] = entries;
    [self saveSettings]; [self rebuildSettingsWindow];
}

- (void)createFromTemplateAtDirectory:(NSURL *)directory imported:(BOOL)imported {
    NSDictionary *entry = nil;
    if (imported) {
        NSArray *entries = self.settings[@"importedTemplates"];
        NSInteger index = [self chooseEntry:entries title:@"选择模板"];
        if (index < 0) return;
        entry = entries[index];
    }
    NSString *name = [self askForText:imported ? @"新建模板副本" : @"新建项目文件夹" hint:imported ? @"输入完整名称；文件模板请保留扩展名。原模板不变。" : @"将创建文档、素材、输出文件夹和 README.md。" value:entry ? entry[@"name"] : @"新项目"];
    if (!name) return;
    if (!QRValidFilename(name)) { [self showError:@"请输入有效名称，不要包含斜杠、冒号或控制字符。"]; return; }
    [self runBatch:@"从模板新建" items:@[directory.path] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSURL *target = entry ? QRCopyTemplate([NSURL fileURLWithPath:entry[@"path"]], directory, name, error) : QRCreateProject(directory, name, error);
        return target ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (void)runImageBatch:(NSArray<NSString *> *)paths options:(NSDictionary *)options title:(NSString *)title {
    NSDictionary *snapshot = [options copy];
    [self runBatch:title items:paths operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSURL *source = [NSURL fileURLWithPath:path];
        NSURL *destination = source.URLByDeletingLastPathComponent;
        NSString *output = snapshot[@"directory"];
        if (output.length) destination = [NSURL fileURLWithPath:output];
        else if ([snapshot[@"subfolder"] boolValue]) destination = [destination URLByAppendingPathComponent:@"已处理" isDirectory:YES];
        if (![[NSFileManager defaultManager] createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:error]) return nil;
        NSURL *target = QRProcessImage(source, destination, snapshot, progress, error);
        return target ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (void)processImages:(NSArray<NSString *> *)paths action:(NSString *)action {
    NSMutableDictionary *options = [@{@"format": @"jpg", @"stripMetadata": @NO} mutableCopy];
    NSString *title = @"处理图片";
    if ([action isEqualToString:@"workflow-run"]) {
        NSArray *presets = self.settings[@"imagePresets"];
        NSInteger index = [self chooseEntry:presets title:@"运行图片处理组合"];
        if (index < 0) return;
        options = [presets[index] mutableCopy]; options[@"subfolder"] = @YES; title = options[@"name"];
    } else if ([action isEqualToString:@"image-resize"]) { options[@"maxSide"] = @1920; options[@"format"] = @"png"; }
    else if ([action isEqualToString:@"image-target-size"]) options[@"targetBytes"] = @1000000;
    else if ([action isEqualToString:@"image-strip-metadata"]) { options[@"stripMetadata"] = @YES; options[@"format"] = @"png"; }
    else if ([action isEqualToString:@"image-watermark"]) {
        NSString *text = [self askForText:@"水印文字" hint:@"在图片底部添加文字水印并另存为 PNG，最多 120 字。" value:@""];
        if (!text) return;
        if (!text.length || text.length > 120) { [self showError:@"水印请输入 1–120 个字符。"]; return; }
        options[@"watermark"] = text; options[@"format"] = @"png";
    }
    [self runImageBatch:paths options:options title:title];
}

- (void)exportManifest:(NSArray<NSString *> *)paths directory:(NSURL *)directory format:(NSString *)format {
    NSArray *selected = paths.count ? paths : @[directory.path];
    BOOL tree = [format isEqualToString:@"tree"];
    [self runBatch:tree ? @"复制目录树" : @"导出文件清单" items:@[directory.path] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSString *manifest = QRFileManifest(selected, format, progress, error);
        if (!manifest) return nil;
        if (tree) return @{@"text": manifest, @"message": @"目录树已生成"};
        NSURL *target = QRUniqueURL(directory, [@"文件清单" stringByAppendingPathExtension:format]);
        return QRWriteNewData([manifest dataUsingEncoding:NSUTF8StringEncoding], target, error) ? @{@"output": target.path} : nil;
    } completion:^(NSArray *results) {
        NSString *text = [results.firstObject objectForKey:@"text"];
        if (text) { [self copyValueToPasteboard:text label:@"目录树"]; [self showTextPreview:text title:@"目录树（已复制）"]; }
    }];
}

- (void)makePDF:(NSArray<NSString *> *)paths directory:(NSURL *)directory images:(BOOL)images {
    if (!paths.count) { [self showError:@"请选择图片或 PDF 文件。"]; return; }
    NSArray *sorted = [paths sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    NSString *name = [self askForText:images ? @"图片合成 PDF" : @"合并 PDF" hint:@"按文件名自然顺序合并。请输入输出名称，原文件保留。" value:images ? @"图片合集.pdf" : @"合并.pdf"];
    if (!name) return;
    if (!QRValidFilename(name)) { [self showError:@"请输入有效文件名。"]; return; }
    [self runBatch:@"生成 PDF" items:@[directory.path] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSURL *target = QRCreatePDF(sorted, directory, name, images, progress, error);
        return target ? @{@"output": target.path} : nil;
    } completion:nil];
}

- (void)recognizeImages:(NSArray<NSString *> *)paths {
    [self runBatch:@"识别图片文字" items:paths operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **error) {
        NSString *text = QRRecognizeText([NSURL fileURLWithPath:path], error);
        return text ? @{@"text": text, @"message": text.length ? text : @"未识别到文字"} : nil;
    } completion:^(NSArray *results) {
        NSMutableArray *texts = [NSMutableArray array];
        for (NSDictionary *entry in results) if ([entry[@"text"] length]) [texts addObject:results.count == 1 ? entry[@"text"] : [NSString stringWithFormat:@"%@\n%@", [entry[@"source"] lastPathComponent], entry[@"text"]]];
        if (texts.count) {
            NSString *text = [texts componentsJoinedByString:@"\n\n"];
            [self copyValueToPasteboard:text label:@"识别结果"]; [self showTextPreview:text title:@"识别结果（已复制）"];
        }
    }];
}

- (void)copyBatchText:(NSArray<NSDictionary *> *)results title:(NSString *)title {
    NSMutableArray *texts = [NSMutableArray array];
    for (NSDictionary *entry in results) if ([entry[@"text"] length]) [texts addObject:entry[@"text"]];
    if (!texts.count) return;
    NSString *text = [texts componentsJoinedByString:@"\n"];
    [self copyValueToPasteboard:text label:title];
    [self showTextPreview:text title:title];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        QRAppDelegate *delegate = [[QRAppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
