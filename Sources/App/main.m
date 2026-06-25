#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>

static NSString * const QRProductName = @"QuickRightMenu";
static NSString * const QRProductVersion = @"1.5.7";
static NSString * const QRLatestReleaseAPI = @"https://api.github.com/repos/weaiw/QuickRightMenu/releases/latest";
static NSString * const QRReleasesURL = @"https://github.com/weaiw/QuickRightMenu/releases/latest";

@interface QRAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *commandTimer;
@property(nonatomic, strong) NSMutableSet<NSString *> *processedCommandPaths;
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

    self.processedCommandPaths = [NSMutableSet set];
    self.commandTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                         target:self
                                                       selector:@selector(pollCommandFiles:)
                                                       userInfo:nil
                                                        repeats:YES];

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

- (NSArray<NSDictionary<NSString *, NSString *> *> *)featureRows {
    return @[
        @{@"key": @"newTxt", @"title": @"新建 TXT", @"category": @"新建文件"},
        @{@"key": @"newMarkdown", @"title": @"新建 Markdown", @"category": @"新建文件"},
        @{@"key": @"newJson", @"title": @"新建 JSON", @"category": @"新建文件"},
        @{@"key": @"newCsv", @"title": @"新建 CSV", @"category": @"新建文件"},
        @{@"key": @"newHtml", @"title": @"新建 HTML", @"category": @"新建文件"},
        @{@"key": @"newYaml", @"title": @"新建 YAML", @"category": @"新建文件"},
        @{@"key": @"newXml", @"title": @"新建 XML", @"category": @"新建文件"},
        @{@"key": @"newShell", @"title": @"新建 Shell", @"category": @"新建文件"},
        @{@"key": @"newPython", @"title": @"新建 Python", @"category": @"新建文件"},
        @{@"key": @"newJavaScript", @"title": @"新建 JavaScript", @"category": @"新建文件"},
        @{@"key": @"newTypeScript", @"title": @"新建 TypeScript", @"category": @"新建文件"},
        @{@"key": @"newCss", @"title": @"新建 CSS", @"category": @"新建文件"},
        @{@"key": @"newWord", @"title": @"新建 Word", @"category": @"新建文件"},
        @{@"key": @"newExcel", @"title": @"新建 Excel", @"category": @"新建文件"},
        @{@"key": @"newPowerPoint", @"title": @"新建 PowerPoint", @"category": @"新建文件"},
        @{@"key": @"copyPath", @"title": @"复制路径", @"category": @"基础操作"},
        @{@"key": @"copyName", @"title": @"复制文件名", @"category": @"基础操作"},
        @{@"key": @"copyParent", @"title": @"复制父目录", @"category": @"基础操作"},
        @{@"key": @"copyFileURL", @"title": @"复制 file URL", @"category": @"基础操作"},
        @{@"key": @"copyMarkdownLink", @"title": @"复制 Markdown 链接", @"category": @"基础操作"},
        @{@"key": @"copyToDesktop", @"title": @"复制到桌面", @"category": @"文件操作"},
        @{@"key": @"copyToDocuments", @"title": @"复制到文稿", @"category": @"文件操作"},
        @{@"key": @"copyToDownloads", @"title": @"复制到下载", @"category": @"文件操作"},
        @{@"key": @"copyToPictures", @"title": @"复制到图片", @"category": @"文件操作"},
        @{@"key": @"copyToMovies", @"title": @"复制到影片", @"category": @"文件操作"},
        @{@"key": @"copyToMusic", @"title": @"复制到音乐", @"category": @"文件操作"},
        @{@"key": @"copyToChoose", @"title": @"复制到选择文件夹", @"category": @"文件操作"},
        @{@"key": @"moveToDesktop", @"title": @"移动到桌面", @"category": @"文件操作"},
        @{@"key": @"moveToDocuments", @"title": @"移动到文稿", @"category": @"文件操作"},
        @{@"key": @"moveToDownloads", @"title": @"移动到下载", @"category": @"文件操作"},
        @{@"key": @"moveToPictures", @"title": @"移动到图片", @"category": @"文件操作"},
        @{@"key": @"moveToMovies", @"title": @"移动到影片", @"category": @"文件操作"},
        @{@"key": @"moveToMusic", @"title": @"移动到音乐", @"category": @"文件操作"},
        @{@"key": @"moveToChoose", @"title": @"移动到选择文件夹", @"category": @"文件操作"},
        @{@"key": @"batchRename", @"title": @"批量重命名", @"category": @"文件操作"},
        @{@"key": @"copyImageSize", @"title": @"复制图片尺寸", @"category": @"图片工具"},
        @{@"key": @"compressImage", @"title": @"压缩图片", @"category": @"图片工具"},
        @{@"key": @"convertPng", @"title": @"转换为 PNG", @"category": @"图片工具"},
        @{@"key": @"convertJpeg", @"title": @"转换为 JPEG", @"category": @"图片工具"},
        @{@"key": @"convertWebp", @"title": @"转换为 WebP", @"category": @"图片工具"},
        @{@"key": @"textStats", @"title": @"统计字数", @"category": @"文本工具"},
        @{@"key": @"textToUtf8", @"title": @"转 UTF-8", @"category": @"文本工具"},
        @{@"key": @"textPreview", @"title": @"快速预览纯文本", @"category": @"文本工具"},
        @{@"key": @"terminal", @"title": @"在终端打开", @"category": @"基础操作"}
    ];
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
    defaults[@"terminalPreference"] = @"terminal";
    defaults[@"hasSeenPermissionGuide"] = @NO;
    defaults[@"commandToken"] = [NSUUID UUID].UUIDString;
    for (NSInteger i = 1; i <= 3; i++) {
        defaults[[NSString stringWithFormat:@"favoriteDir%ldName", (long)i]] = @"";
        defaults[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)i]] = @"";
    }
    return defaults;
}

- (NSDictionary<NSString *, id> *)loadSettings {
    NSMutableDictionary<NSString *, id> *merged = [[self defaultSettings] mutableCopy];
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfURL:[self settingsURL]];
    if ([stored isKindOfClass:NSDictionary.class]) {
        for (NSString *key in stored) {
            if (merged[key] && ([stored[key] isKindOfClass:NSNumber.class] || [stored[key] isKindOfClass:NSString.class])) {
                merged[key] = stored[key];
            }
        }
    }
    return merged;
}

- (void)saveSettings {
    NSURL *url = [self settingsURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    [self.settings writeToURL:url atomically:YES];
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

    NSTextField *version = [self labelWithText:[NSString stringWithFormat:@"正式版 %@", QRProductVersion] size:13 bold:NO color:[NSColor colorWithWhite:0.74 alpha:1]];
    version.frame = NSMakeRect(28, 448, 170, 22);
    [sidebar addSubview:version];

    NSArray<NSDictionary<NSString *, NSString *> *> *navItems = @[
        @{@"page": @"permissions", @"title": @"权限指引", @"detail": @"首次安装必看"},
        @{@"page": @"menu", @"title": @"右键菜单", @"detail": @"菜单开关"},
        @{@"page": @"templates", @"title": @"文件模板", @"detail": @"新建内容默认值"},
        @{@"page": @"favorites", @"title": @"常用目录", @"detail": @"复制 / 移动快捷目录"},
        @{@"page": @"terminal", @"title": @"终端偏好", @"detail": @"Terminal / iTerm2 / Warp"},
        @{@"page": @"login", @"title": @"开机启动", @"detail": [self isLoginItemEnabled] ? @"已开启" : @"未开启"},
        @{@"page": @"update", @"title": @"软件更新", @"detail": self.updateAvailable ? @"发现新版本" : @"GitHub Release"}
    ];
    for (NSInteger i = 0; i < navItems.count; i++) {
        NSView *navRow = [[NSView alloc] initWithFrame:NSMakeRect(18, 402 - i * 46, 200, 40)];
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
    [self addPageTitle:@"右键菜单" hint:@"勾选后会显示在 Finder 右键菜单。新建文件、复制到、移动到会按功能折叠到二级菜单。" toView:root];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(266, 86, 594, 420)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:scrollView];

    NSInteger estimatedRows = [self featureRows].count + 3;
    CGFloat listHeight = MAX(420, estimatedRows * 42 + 40);
    NSView *list = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 574, listHeight)];
    scrollView.documentView = list;

    NSInteger row = 0;
    NSString *lastCategory = nil;
    for (NSDictionary<NSString *, NSString *> *item in [self featureRows]) {
        NSString *category = item[@"category"];
        if (![category isEqualToString:lastCategory]) {
            NSTextField *categoryLabel = [self labelWithText:category size:13 bold:YES color:NSColor.secondaryLabelColor];
            categoryLabel.frame = NSMakeRect(24, listHeight - 40 - row * 42, 200, 24);
            [list addSubview:categoryLabel];
            row += 1;
            lastCategory = category;
        }

        NSButton *checkbox = [NSButton checkboxWithTitle:item[@"title"] target:self action:@selector(settingsCheckboxChanged:)];
        checkbox.identifier = item[@"key"];
        checkbox.state = [self.settings[item[@"key"]] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.frame = NSMakeRect(24, listHeight - 40 - row * 42, 360, 26);
        checkbox.font = [NSFont systemFontOfSize:16];
        [list addSubview:checkbox];
        row += 1;
    }

    NSButton *allOn = [NSButton buttonWithTitle:@"全部启用" target:self action:@selector(enableAllSettings:)];
    allOn.frame = NSMakeRect(266, 34, 100, 34);
    [root addSubview:allOn];

    NSButton *defaults = [NSButton buttonWithTitle:@"恢复默认" target:self action:@selector(resetSettings:)];
    defaults.frame = NSMakeRect(376, 34, 100, 34);
    [root addSubview:defaults];
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

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(276, 104, 560, 330)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    [root addSubview:scrollView];

    self.templateTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 560, 330)];
    self.templateTextView.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightRegular];
    scrollView.documentView = self.templateTextView;
    [self templateExtensionChanged:self.templatePopup];

    NSButton *save = [NSButton buttonWithTitle:@"保存模板" target:self action:@selector(saveTemplatePage:)];
    save.frame = NSMakeRect(276, 48, 110, 34);
    [root addSubview:save];

    NSButton *reset = [NSButton buttonWithTitle:@"恢复该类型默认" target:self action:@selector(resetSelectedTemplate:)];
    reset.frame = NSMakeRect(396, 48, 130, 34);
    [root addSubview:reset];
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
    [self addPageTitle:@"终端偏好" hint:@"用于“在终端打开”。选择后保存，Finder 右键菜单会使用对应终端。" toView:root];

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
    self.settings = [[self defaultSettings] mutableCopy];
    [self saveSettings];
    [self.settingsWindow close];
    self.settingsWindow = [self buildSettingsWindow];
    [self.settingsWindow makeKeyAndOrderFront:nil];
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
    NSURL *directory = [self commandDirectoryURL];
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directory
                                                            includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                                               options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                 error:nil];
    for (NSURL *fileURL in files) {
        if (![fileURL.pathExtension isEqualToString:@"cmd"]) {
            continue;
        }
        if ([self.processedCommandPaths containsObject:fileURL.path]) {
            continue;
        }

        [self.processedCommandPaths addObject:fileURL.path];
        NSString *urlString = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:nil];
        [self handleCommandURLString:urlString source:@"command file"];
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    }
}

- (NSURL *)commandDirectoryURL {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Containers/com.liaowenbin.QuickRightMenu.Extension/Data/Library/Application Support/QuickRightMenuCommands"];
    return [NSURL fileURLWithPath:path];
}

- (void)handleCommandURLString:(NSString *)urlString source:(NSString *)source {
    [self log:source ?: @"command"];
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
    if (![self isValidCommandToken:params[@"token"]]) {
        [self log:@"rejected command with invalid token"];
        return;
    }

    NSURL *directory = [NSURL fileURLWithPath:params[@"dir"] ?: NSHomeDirectory()];
    if ([command isEqualToString:@"create"]) {
        NSString *extension = params[@"ext"] ?: @"txt";
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

- (BOOL)isValidCommandToken:(NSString *)token {
    NSString *expected = self.settings[@"commandToken"];
    return [token isKindOfClass:NSString.class] &&
           [expected isKindOfClass:NSString.class] &&
           token.length > 0 &&
           [token isEqualToString:expected];
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
    BOOL ok = [contents writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
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
    if (prepared && [fileManager fileExistsAtPath:fileURL.path]) {
        [fileManager removeItemAtURL:fileURL error:nil];
    }
    if (prepared) {
        prepared = [self zipDirectoryAtURL:tempURL toURL:fileURL error:&error];
    }
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

- (void)copyValueToPasteboard:(NSString *)value label:(NSString *)label {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
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
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    NSArray<NSString *> *rawItems = paths.length > 0 ? [paths componentsSeparatedByString:@"\n"] : @[];
    for (NSString *path in rawItems) {
        if (path.length > 0) {
            [items addObject:path];
        }
    }
    if (items.count == 0 && fallback.length > 0) {
        [items addObject:fallback];
    }
    return items;
}

- (void)transferPaths:(NSString *)paths directory:(NSURL *)directory destinationKey:(NSString *)destinationKey move:(BOOL)move {
    [self log:[NSString stringWithFormat:@"transfer move=%@ destination=%@ paths=%@ directory=%@",
               move ? @"YES" : @"NO",
               destinationKey ?: @"",
               paths ?: @"",
               directory.path ?: @""]];

    NSURL *destinationDirectory = [destinationKey.lowercaseString isEqualToString:@"choose"]
        ? [self chooseDestinationDirectoryForMove:move]
        : [self destinationDirectoryForKey:destinationKey];
    if (!destinationDirectory) {
        return;
    }

    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self log:@"transfer failed: empty selected paths"];
        [self showError:@"没有拿到选中的文件。请先选中文件后再用“复制到/移动到”。"];
        return;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *directoryError = nil;
    [fileManager createDirectoryAtURL:destinationDirectory withIntermediateDirectories:YES attributes:nil error:&directoryError];
    if (directoryError) {
        [self showError:[NSString stringWithFormat:@"创建目标目录失败：%@", directoryError.localizedDescription]];
        return;
    }

    NSMutableArray<NSURL *> *completedURLs = [NSMutableArray array];
    for (NSString *path in items) {
        NSURL *sourceURL = [NSURL fileURLWithPath:path];
        NSURL *targetURL = [self uniqueDestinationURLForSourceURL:sourceURL inDirectory:destinationDirectory];
        NSError *error = nil;
        BOOL ok = move ? [fileManager moveItemAtURL:sourceURL toURL:targetURL error:&error] : [fileManager copyItemAtURL:sourceURL toURL:targetURL error:&error];
        if (!ok || error) {
            NSString *verb = move ? @"移动" : @"复制";
            [self log:[NSString stringWithFormat:@"transfer failed %@ -> %@ %@", sourceURL.path, targetURL.path, error.localizedDescription ?: @"unknown"]];
            [self showError:[NSString stringWithFormat:@"%@失败：%@\n%@", verb, sourceURL.path, error.localizedDescription ?: @"未知错误"]];
            return;
        }
        [self log:[NSString stringWithFormat:@"transfer ok %@ -> %@", sourceURL.path, targetURL.path]];
        [completedURLs addObject:targetURL];
    }

    if (completedURLs.count > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:completedURLs];
    }
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
    NSString *filename = sourceURL.lastPathComponent.length > 0 ? sourceURL.lastPathComponent : @"Untitled";
    NSURL *candidate = [directory URLByAppendingPathComponent:filename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        return candidate;
    }

    NSString *extension = filename.pathExtension;
    NSString *baseName = extension.length > 0 ? filename.stringByDeletingPathExtension : filename;
    NSInteger index = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        NSString *nextName = extension.length > 0
            ? [NSString stringWithFormat:@"%@ %ld.%@", baseName, (long)index, extension]
            : [NSString stringWithFormat:@"%@ %ld", baseName, (long)index];
        candidate = [directory URLByAppendingPathComponent:nextName];
        index += 1;
    }
    return candidate;
}

- (void)batchRenamePaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray<NSString *> *items = [[self pathListFromString:paths fallback:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的文件。请先选中文件后再批量重命名。"];
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"批量重命名";
    alert.informativeText = @"输入新文件名前缀。会保留原扩展名，并自动添加 001、002、003。";
    [alert addButtonWithTitle:@"重命名"];
    [alert addButtonWithTitle:@"取消"];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 28)];
    input.stringValue = @"文件";
    alert.accessoryView = input;
    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response = [alert runModal];
    if (response != NSAlertFirstButtonReturn) {
        return;
    }

    NSString *prefix = [input.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (prefix.length == 0) {
        [self showError:@"文件名前缀不能为空"];
        return;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray<NSURL *> *renamedURLs = [NSMutableArray array];
    NSInteger index = 1;
    NSString *countString = [NSString stringWithFormat:@"%lu", (unsigned long)items.count];
    NSInteger width = MAX(3, (NSInteger)countString.length);
    for (NSString *path in items) {
        NSURL *sourceURL = [NSURL fileURLWithPath:path];
        NSString *extension = sourceURL.pathExtension;
        NSString *number = [NSString stringWithFormat:@"%0*ld", (int)width, (long)index];
        NSString *filename = extension.length > 0
            ? [NSString stringWithFormat:@"%@ %@.%@", prefix, number, extension]
            : [NSString stringWithFormat:@"%@ %@", prefix, number];
        NSURL *targetURL = [sourceURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:filename];
        targetURL = [self uniqueDestinationURLForSourceURL:targetURL inDirectory:sourceURL.URLByDeletingLastPathComponent];
        NSError *error = nil;
        BOOL ok = [fileManager moveItemAtURL:sourceURL toURL:targetURL error:&error];
        if (!ok || error) {
            [self showError:[NSString stringWithFormat:@"重命名失败：%@\n%@", sourceURL.path, error.localizedDescription ?: @"未知错误"]];
            return;
        }
        [renamedURLs addObject:targetURL];
        index += 1;
    }

    if (renamedURLs.count > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:renamedURLs];
    }
}

- (void)copyImageSizesForPaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的图片文件"];
        return;
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *path in items) {
        NSDictionary *info = [self imageInfoAtPath:path];
        if (!info) {
            continue;
        }
        [lines addObject:[NSString stringWithFormat:@"%@: %@ x %@ px", path.lastPathComponent, info[@"width"], info[@"height"]]];
    }
    if (lines.count == 0) {
        [self showError:@"没有识别到可读取尺寸的图片"];
        return;
    }

    NSString *result = [lines componentsJoinedByString:@"\n"];
    [self copyValueToPasteboard:result label:@"image sizes"];
    [self showInfo:@"图片尺寸已复制" details:result];
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
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的图片文件"];
        return;
    }

    NSMutableArray<NSURL *> *createdURLs = [NSMutableArray array];
    for (NSString *path in items) {
        NSURL *sourceURL = [NSURL fileURLWithPath:path];
        NSURL *targetURL = [self imageTargetURLForSourceURL:sourceURL format:format];
        NSString *uti = [self imageUTIForFormat:format];
        CGFloat quality = [format isEqualToString:@"jpg-compressed"] ? 0.72 : 0.9;
        NSError *error = nil;
        BOOL ok = [self writeImageAtURL:sourceURL toURL:targetURL uti:uti quality:quality error:&error];
        if (!ok || error) {
            [self showError:[NSString stringWithFormat:@"图片处理失败：%@\n%@", sourceURL.path, error.localizedDescription ?: @"当前系统可能不支持该格式写入"]];
            return;
        }
        [createdURLs addObject:targetURL];
    }

    if (createdURLs.count > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:createdURLs];
    }
}

- (NSString *)imageUTIForFormat:(NSString *)format {
    if ([format isEqualToString:@"png"]) {
        return @"public.png";
    }
    if ([format isEqualToString:@"webp"]) {
        return @"org.webmproject.webp";
    }
    return @"public.jpeg";
}

- (NSURL *)imageTargetURLForSourceURL:(NSURL *)sourceURL format:(NSString *)format {
    NSString *extension = @"jpg";
    NSString *suffix = @"";
    if ([format isEqualToString:@"png"]) {
        extension = @"png";
    } else if ([format isEqualToString:@"webp"]) {
        extension = @"webp";
    } else if ([format isEqualToString:@"jpg-compressed"]) {
        extension = @"jpg";
        suffix = @"-compressed";
    }
    NSString *baseName = sourceURL.lastPathComponent.stringByDeletingPathExtension;
    NSString *filename = [NSString stringWithFormat:@"%@%@.%@", baseName.length > 0 ? baseName : @"Untitled", suffix, extension];
    NSURL *targetURL = [sourceURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:filename];
    return [self uniqueDestinationURLForSourceURL:targetURL inDirectory:sourceURL.URLByDeletingLastPathComponent];
}

- (BOOL)writeImageAtURL:(NSURL *)sourceURL toURL:(NSURL *)targetURL uti:(NSString *)uti quality:(CGFloat)quality error:(NSError **)error {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)sourceURL, NULL);
    if (!source) {
        if (error) {
            *error = [NSError errorWithDomain:@"QuickRightMenu" code:1 userInfo:@{NSLocalizedDescriptionKey: @"无法读取图片"}];
        }
        return NO;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image) {
        if (error) {
            *error = [NSError errorWithDomain:@"QuickRightMenu" code:2 userInfo:@{NSLocalizedDescriptionKey: @"无法解码图片"}];
        }
        return NO;
    }

    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)targetURL, (__bridge CFStringRef)uti, 1, NULL);
    if (!destination) {
        CGImageRelease(image);
        if (error) {
            *error = [NSError errorWithDomain:@"QuickRightMenu" code:3 userInfo:@{NSLocalizedDescriptionKey: @"当前系统不支持写入该图片格式"}];
        }
        return NO;
    }

    NSDictionary *options = @{(NSString *)kCGImageDestinationLossyCompressionQuality: @(quality)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    if (!ok && error) {
        *error = [NSError errorWithDomain:@"QuickRightMenu" code:4 userInfo:@{NSLocalizedDescriptionKey: @"图片写入失败"}];
    }
    return ok;
}

- (void)showTextStatsForPaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的文本文件"];
        return;
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *path in items) {
        NSString *text = [self textContentsAtPath:path usedEncoding:nil];
        if (!text) {
            continue;
        }
        NSUInteger chars = [[text stringByReplacingOccurrencesOfString:@"\\s" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, text.length)] length];
        NSArray<NSString *> *words = [text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSUInteger wordCount = 0;
        for (NSString *word in words) {
            if (word.length > 0) {
                wordCount += 1;
            }
        }
        NSUInteger linesCount = [[text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] count];
        [lines addObject:[NSString stringWithFormat:@"%@: 字符 %lu，词 %lu，行 %lu", path.lastPathComponent, (unsigned long)chars, (unsigned long)wordCount, (unsigned long)linesCount]];
    }
    if (lines.count == 0) {
        [self showError:@"没有可读取的文本文件"];
        return;
    }

    NSString *result = [lines componentsJoinedByString:@"\n"];
    [self copyValueToPasteboard:result label:@"text stats"];
    [self showInfo:@"字数统计已复制" details:result];
}

- (void)convertTextFilesToUTF8ForPaths:(NSString *)paths directory:(NSURL *)directory {
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的文本文件"];
        return;
    }

    NSMutableArray<NSURL *> *createdURLs = [NSMutableArray array];
    for (NSString *path in items) {
        NSStringEncoding encoding = 0;
        NSString *text = [self textContentsAtPath:path usedEncoding:&encoding];
        if (!text) {
            [self showError:[NSString stringWithFormat:@"无法读取文本：%@", path]];
            return;
        }
        NSURL *sourceURL = [NSURL fileURLWithPath:path];
        NSURL *targetURL = [self utf8TargetURLForSourceURL:sourceURL];
        NSError *error = nil;
        BOOL ok = [text writeToURL:targetURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (!ok || error) {
            [self showError:[NSString stringWithFormat:@"转 UTF-8 失败：%@\n%@", path, error.localizedDescription ?: @"未知错误"]];
            return;
        }
        [createdURLs addObject:targetURL];
    }

    if (createdURLs.count > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:createdURLs];
    }
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
    NSArray<NSString *> *items = [self pathListFromString:paths fallback:nil];
    if (items.count == 0) {
        [self showError:@"没有拿到选中的文本文件"];
        return;
    }

    NSString *path = items.firstObject;
    NSString *text = [self textContentsAtPath:path usedEncoding:nil];
    if (!text) {
        [self showError:[NSString stringWithFormat:@"无法读取文本：%@", path]];
        return;
    }

    [self showTextPreview:text title:path.lastPathComponent ?: @"文本预览"];
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
    NSURL *candidate = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", baseName, extension]];
    NSInteger index = 2;
    while ([[NSFileManager defaultManager] fileExistsAtPath:candidate.path]) {
        candidate = [directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@ %ld.%@", baseName, (long)index, extension]];
        index += 1;
    }
    return candidate;
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
