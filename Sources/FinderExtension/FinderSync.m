#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>

@interface FinderSync : FIFinderSync
@end

@implementation FinderSync

static NSInteger QRMenuTagBase = 42000;

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURL *rootURL = [NSURL fileURLWithPath:@"/"];
        [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:rootURL];
    }
    return self;
}

- (NSString *)toolbarItemName {
    return @"QuickRightMenu";
}

- (NSString *)toolbarItemToolTip {
    return @"QuickRightMenu";
}

- (NSImage *)toolbarItemImage {
    return [self menuIconNamed:@"filemenu.and.selection"];
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)whichMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"QuickRightMenu"];

    NSMenuItem *createItem = [[NSMenuItem alloc] initWithTitle:@"新建文件" action:nil keyEquivalent:@""];
    createItem.image = [self menuIconNamed:@"doc.badge.plus"];
    NSMenu *createMenu = [[NSMenu alloc] initWithTitle:@"新建文件"];
    [self addItemWithTitle:@"TXT" key:@"newTxt" action:@"txt" symbol:@"doc.plaintext" toMenu:createMenu];
    [self addItemWithTitle:@"Markdown" key:@"newMarkdown" action:@"md" symbol:@"doc.text" toMenu:createMenu];
    [self addItemWithTitle:@"JSON" key:@"newJson" action:@"json" symbol:@"curlybraces" toMenu:createMenu];
    [self addItemWithTitle:@"CSV" key:@"newCsv" action:@"csv" symbol:@"tablecells" toMenu:createMenu];
    [self addItemWithTitle:@"HTML" key:@"newHtml" action:@"html" symbol:@"chevron.left.forwardslash.chevron.right" toMenu:createMenu];
    [self addItemWithTitle:@"YAML" key:@"newYaml" action:@"yaml" symbol:@"doc.text" toMenu:createMenu];
    [self addItemWithTitle:@"XML" key:@"newXml" action:@"xml" symbol:@"chevron.left.forwardslash.chevron.right" toMenu:createMenu];
    [self addItemWithTitle:@"Shell" key:@"newShell" action:@"sh" symbol:@"terminal" toMenu:createMenu];
    [self addItemWithTitle:@"Python" key:@"newPython" action:@"py" symbol:@"chevron.left.forwardslash.chevron.right" toMenu:createMenu];
    [self addItemWithTitle:@"JavaScript" key:@"newJavaScript" action:@"js" symbol:@"curlybraces" toMenu:createMenu];
    [self addItemWithTitle:@"TypeScript" key:@"newTypeScript" action:@"ts" symbol:@"curlybraces" toMenu:createMenu];
    [self addItemWithTitle:@"CSS" key:@"newCss" action:@"css" symbol:@"paintbrush" toMenu:createMenu];
    [self addItemWithTitle:@"Word" key:@"newWord" action:@"docx" symbol:@"doc.richtext" toMenu:createMenu];
    [self addItemWithTitle:@"Excel" key:@"newExcel" action:@"xlsx" symbol:@"tablecells" toMenu:createMenu];
    [self addItemWithTitle:@"PowerPoint" key:@"newPowerPoint" action:@"pptx" symbol:@"rectangle.on.rectangle" toMenu:createMenu];
    if (createMenu.numberOfItems > 0) {
        createItem.submenu = createMenu;
        [menu addItem:createItem];
    }

    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"复制" action:nil keyEquivalent:@""];
    copyItem.image = [self menuIconNamed:@"doc.on.clipboard"];
    NSMenu *copyMenu = [[NSMenu alloc] initWithTitle:@"复制"];
    [self addItemWithTitle:@"路径" key:@"copyPath" action:@"copy-path" symbol:@"doc.on.clipboard" toMenu:copyMenu];
    [self addItemWithTitle:@"文件名" key:@"copyName" action:@"copy-name" symbol:@"textformat" toMenu:copyMenu];
    [self addItemWithTitle:@"父目录" key:@"copyParent" action:@"copy-parent" symbol:@"folder" toMenu:copyMenu];
    [self addItemWithTitle:@"file URL" key:@"copyFileURL" action:@"copy-file-url" symbol:@"link" toMenu:copyMenu];
    [self addItemWithTitle:@"Markdown 链接" key:@"copyMarkdownLink" action:@"copy-markdown-link" symbol:@"link.badge.plus" toMenu:copyMenu];
    if (copyMenu.numberOfItems > 0) {
        copyItem.submenu = copyMenu;
        [menu addItem:copyItem];
    }

    NSMenuItem *copyToItem = [[NSMenuItem alloc] initWithTitle:@"复制到" action:nil keyEquivalent:@""];
    copyToItem.image = [self menuIconNamed:@"doc.on.doc"];
    NSMenu *copyToMenu = [[NSMenu alloc] initWithTitle:@"复制到"];
    [self addDestinationItemsWithPrefix:@"copy-to" featurePrefix:@"copyTo" toMenu:copyToMenu];
    [self addFavoriteDestinationItemsWithPrefix:@"copy-to" toMenu:copyToMenu];
    [self addItemWithTitle:@"选择文件夹..." key:@"copyToChoose" action:@"copy-to-choose" symbol:@"folder.badge.plus" toMenu:copyToMenu];
    if (copyToMenu.numberOfItems > 0) {
        copyToItem.submenu = copyToMenu;
        [menu addItem:copyToItem];
    }

    NSMenuItem *moveToItem = [[NSMenuItem alloc] initWithTitle:@"移动到" action:nil keyEquivalent:@""];
    moveToItem.image = [self menuIconNamed:@"folder"];
    NSMenu *moveToMenu = [[NSMenu alloc] initWithTitle:@"移动到"];
    [self addDestinationItemsWithPrefix:@"move-to" featurePrefix:@"moveTo" toMenu:moveToMenu];
    [self addFavoriteDestinationItemsWithPrefix:@"move-to" toMenu:moveToMenu];
    [self addItemWithTitle:@"选择文件夹..." key:@"moveToChoose" action:@"move-to-choose" symbol:@"folder.badge.plus" toMenu:moveToMenu];
    if (moveToMenu.numberOfItems > 0) {
        moveToItem.submenu = moveToMenu;
        [menu addItem:moveToItem];
    }

    NSMenuItem *fileOpsItem = [[NSMenuItem alloc] initWithTitle:@"文件操作" action:nil keyEquivalent:@""];
    fileOpsItem.image = [self menuIconNamed:@"folder"];
    NSMenu *fileOpsMenu = [[NSMenu alloc] initWithTitle:@"文件操作"];
    [self addItemWithTitle:@"批量重命名" key:@"batchRename" action:@"batch-rename" symbol:@"text.cursor" toMenu:fileOpsMenu];
    if (fileOpsMenu.numberOfItems > 0) {
        fileOpsItem.submenu = fileOpsMenu;
        [menu addItem:fileOpsItem];
    }

    NSMenuItem *imageToolsItem = [[NSMenuItem alloc] initWithTitle:@"图片工具" action:nil keyEquivalent:@""];
    imageToolsItem.image = [self menuIconNamed:@"photo"];
    NSMenu *imageToolsMenu = [[NSMenu alloc] initWithTitle:@"图片工具"];
    [self addItemWithTitle:@"复制图片尺寸" key:@"copyImageSize" action:@"image-copy-size" symbol:@"ruler" toMenu:imageToolsMenu];
    [self addItemWithTitle:@"压缩图片" key:@"compressImage" action:@"image-compress" symbol:@"arrow.down.right.and.arrow.up.left" toMenu:imageToolsMenu];
    [self addItemWithTitle:@"转换为 PNG" key:@"convertPng" action:@"image-convert-png" symbol:@"photo" toMenu:imageToolsMenu];
    [self addItemWithTitle:@"转换为 JPEG" key:@"convertJpeg" action:@"image-convert-jpeg" symbol:@"photo" toMenu:imageToolsMenu];
    [self addItemWithTitle:@"转换为 WebP" key:@"convertWebp" action:@"image-convert-webp" symbol:@"photo" toMenu:imageToolsMenu];
    if (imageToolsMenu.numberOfItems > 0) {
        imageToolsItem.submenu = imageToolsMenu;
        [menu addItem:imageToolsItem];
    }

    NSMenuItem *textToolsItem = [[NSMenuItem alloc] initWithTitle:@"文本工具" action:nil keyEquivalent:@""];
    textToolsItem.image = [self menuIconNamed:@"doc.text"];
    NSMenu *textToolsMenu = [[NSMenu alloc] initWithTitle:@"文本工具"];
    [self addItemWithTitle:@"统计字数" key:@"textStats" action:@"text-stats" symbol:@"number" toMenu:textToolsMenu];
    [self addItemWithTitle:@"转 UTF-8" key:@"textToUtf8" action:@"text-to-utf8" symbol:@"character.cursor.ibeam" toMenu:textToolsMenu];
    [self addItemWithTitle:@"快速预览纯文本" key:@"textPreview" action:@"text-preview" symbol:@"eye" toMenu:textToolsMenu];
    if (textToolsMenu.numberOfItems > 0) {
        textToolsItem.submenu = textToolsMenu;
        [menu addItem:textToolsItem];
    }

    if ([self isFeatureEnabled:@"terminal"]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"在终端打开" action:@selector(handleMenuItem:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = @"terminal";
        item.tag = [self tagForAction:@"terminal"];
        item.image = [self menuIconNamed:@"terminal"];
        [menu addItem:item];
    }

    return menu;
}

- (void)addItemWithTitle:(NSString *)title key:(NSString *)key action:(NSString *)action symbol:(NSString *)symbol toMenu:(NSMenu *)menu {
    if ([self isFeatureEnabled:key]) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(handleMenuItem:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = action;
        item.tag = [self tagForAction:action];
        item.image = [self menuIconNamed:symbol];
        [menu addItem:item];
    }
}

- (void)addDestinationItemsWithPrefix:(NSString *)commandPrefix featurePrefix:(NSString *)featurePrefix toMenu:(NSMenu *)menu {
    NSArray<NSDictionary<NSString *, NSString *> *> *destinations = @[
        @{@"key": @"Desktop", @"title": @"桌面", @"symbol": @"desktopcomputer"},
        @{@"key": @"Documents", @"title": @"文稿", @"symbol": @"doc.text"},
        @{@"key": @"Downloads", @"title": @"下载", @"symbol": @"arrow.down.circle"},
        @{@"key": @"Pictures", @"title": @"图片", @"symbol": @"photo"},
        @{@"key": @"Movies", @"title": @"影片", @"symbol": @"film"},
        @{@"key": @"Music", @"title": @"音乐", @"symbol": @"music.note"}
    ];
    for (NSDictionary<NSString *, NSString *> *destination in destinations) {
        NSString *featureKey = [featurePrefix stringByAppendingString:destination[@"key"]];
        NSString *action = [NSString stringWithFormat:@"%@-%@", commandPrefix, destination[@"key"].lowercaseString];
        [self addItemWithTitle:destination[@"title"] key:featureKey action:action symbol:destination[@"symbol"] toMenu:menu];
    }
}

- (void)addFavoriteDestinationItemsWithPrefix:(NSString *)commandPrefix toMenu:(NSMenu *)menu {
    NSDictionary *settings = [self settingsDictionary];
    BOOL addedSeparator = NO;
    for (NSInteger i = 1; i <= 3; i++) {
        NSString *path = settings[[NSString stringWithFormat:@"favoriteDir%ldPath", (long)i]];
        NSString *name = settings[[NSString stringWithFormat:@"favoriteDir%ldName", (long)i]];
        if (![path isKindOfClass:NSString.class] || path.length == 0) {
            continue;
        }
        if (!addedSeparator && menu.numberOfItems > 0) {
            [menu addItem:[NSMenuItem separatorItem]];
            addedSeparator = YES;
        }
        NSString *title = name.length > 0 ? name : path.lastPathComponent;
        NSString *action = [NSString stringWithFormat:@"%@-favorite%ld", commandPrefix, (long)i];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(handleMenuItem:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = action;
        item.tag = [self tagForAction:action];
        item.image = [self menuIconNamed:@"folder"];
        [menu addItem:item];
    }
}

- (NSImage *)menuIconNamed:(NSString *)name {
    NSSize canvasSize = NSMakeSize(22, 22);
    NSImage *result = [[NSImage alloc] initWithSize:canvasSize];
    [result lockFocus];

    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.5, 1.5, 19, 19) xRadius:5 yRadius:5];
    [[NSColor colorWithCalibratedWhite:1 alpha:1] setFill];
    [background fill];
    [[NSColor colorWithCalibratedWhite:0.84 alpha:1] setStroke];
    background.lineWidth = 0.7;
    [background stroke];

    NSColor *tint = [self tintColorForSymbol:name];
    [self drawFilledGlyphNamed:name tint:tint inRect:NSMakeRect(4, 4, 14, 14)];

    if ([name containsString:@"badge.plus"]) {
        NSBezierPath *badge = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(11.5, 11.5, 8, 8)];
        [[NSColor colorWithCalibratedRed:0.25 green:0.86 blue:0.45 alpha:1] setFill];
        [badge fill];
        [[NSColor whiteColor] setStroke];
        NSBezierPath *h = [NSBezierPath bezierPath];
        [h moveToPoint:NSMakePoint(14, 15.5)];
        [h lineToPoint:NSMakePoint(17, 15.5)];
        [h moveToPoint:NSMakePoint(15.5, 14)];
        [h lineToPoint:NSMakePoint(15.5, 17)];
        h.lineWidth = 1.3;
        [h stroke];
    }

    [result unlockFocus];
    result.size = canvasSize;
    return result;
}

- (void)drawFilledGlyphNamed:(NSString *)name tint:(NSColor *)tint inRect:(NSRect)rect {
    [tint setFill];
    [tint setStroke];

    if ([name containsString:@"terminal"]) {
        NSBezierPath *screen = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.size.width, rect.size.height - 2) xRadius:2 yRadius:2];
        [screen fill];
        [[NSColor whiteColor] setStroke];
        NSBezierPath *prompt = [NSBezierPath bezierPath];
        [prompt moveToPoint:NSMakePoint(rect.origin.x + 3, rect.origin.y + 8.5)];
        [prompt lineToPoint:NSMakePoint(rect.origin.x + 5.3, rect.origin.y + 7)];
        [prompt lineToPoint:NSMakePoint(rect.origin.x + 3, rect.origin.y + 5.5)];
        prompt.lineWidth = 1.2;
        [prompt stroke];
        NSBezierPath *cursor = [NSBezierPath bezierPath];
        [cursor moveToPoint:NSMakePoint(rect.origin.x + 7.2, rect.origin.y + 5.8)];
        [cursor lineToPoint:NSMakePoint(rect.origin.x + 10.5, rect.origin.y + 5.8)];
        cursor.lineWidth = 1.2;
        [cursor stroke];
        return;
    }

    if ([name containsString:@"folder"]) {
        NSBezierPath *tab = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 9, 6, 3.5) xRadius:1 yRadius:1];
        [tab fill];
        NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x, rect.origin.y + 2, rect.size.width, 10) xRadius:2 yRadius:2];
        [body fill];
        return;
    }

    if ([name containsString:@"photo"]) {
        NSBezierPath *frame = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x, rect.origin.y + 1, rect.size.width, rect.size.height - 2) xRadius:2 yRadius:2];
        [frame fill];
        [[NSColor colorWithCalibratedWhite:1 alpha:0.95] setFill];
        NSBezierPath *sun = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(rect.origin.x + 9.5, rect.origin.y + 9, 2.8, 2.8)];
        [sun fill];
        NSBezierPath *mountain = [NSBezierPath bezierPath];
        [mountain moveToPoint:NSMakePoint(rect.origin.x + 2.2, rect.origin.y + 3.2)];
        [mountain lineToPoint:NSMakePoint(rect.origin.x + 5.4, rect.origin.y + 7.4)];
        [mountain lineToPoint:NSMakePoint(rect.origin.x + 7.8, rect.origin.y + 4.9)];
        [mountain lineToPoint:NSMakePoint(rect.origin.x + 10.4, rect.origin.y + 8.2)];
        [mountain lineToPoint:NSMakePoint(rect.origin.x + 12.2, rect.origin.y + 3.2)];
        [mountain closePath];
        [mountain fill];
        return;
    }

    if ([name containsString:@"tablecells"]) {
        NSBezierPath *table = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 1, rect.size.width - 2, rect.size.height - 2) xRadius:2 yRadius:2];
        [table fill];
        [[NSColor whiteColor] setStroke];
        NSBezierPath *grid = [NSBezierPath bezierPath];
        for (NSInteger i = 1; i <= 2; i++) {
            CGFloat x = rect.origin.x + 1 + (rect.size.width - 2) * i / 3.0;
            [grid moveToPoint:NSMakePoint(x, rect.origin.y + 2)];
            [grid lineToPoint:NSMakePoint(x, rect.origin.y + rect.size.height - 2)];
            CGFloat y = rect.origin.y + 1 + (rect.size.height - 2) * i / 3.0;
            [grid moveToPoint:NSMakePoint(rect.origin.x + 2, y)];
            [grid lineToPoint:NSMakePoint(rect.origin.x + rect.size.width - 2, y)];
        }
        grid.lineWidth = 0.75;
        [grid stroke];
        return;
    }

    if ([name containsString:@"link"]) {
        NSBezierPath *left = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 4.5, 7, 4.5) xRadius:2.2 yRadius:2.2];
        NSBezierPath *right = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 6, rect.origin.y + 5.5, 7, 4.5) xRadius:2.2 yRadius:2.2];
        left.lineWidth = 2.2;
        right.lineWidth = 2.2;
        [left stroke];
        [right stroke];
        return;
    }

    if ([name containsString:@"ruler"]) {
        [[NSGraphicsContext currentContext] saveGraphicsState];
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:rect.origin.x + 7 yBy:rect.origin.y + 7];
        [transform rotateByDegrees:-30];
        [transform translateXBy:-(rect.origin.x + 7) yBy:-(rect.origin.y + 7)];
        [transform concat];
        NSBezierPath *ruler = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 5, 12, 4) xRadius:1.5 yRadius:1.5];
        [ruler fill];
        [[NSGraphicsContext currentContext] restoreGraphicsState];
        return;
    }

    if ([name containsString:@"arrow.down"] || [name containsString:@"arrow.up"]) {
        NSBezierPath *box = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 1, rect.size.width - 2, rect.size.height - 2) xRadius:3 yRadius:3];
        [box fill];
        [[NSColor whiteColor] setStroke];
        NSBezierPath *arrows = [NSBezierPath bezierPath];
        [arrows moveToPoint:NSMakePoint(rect.origin.x + 4, rect.origin.y + 10)];
        [arrows lineToPoint:NSMakePoint(rect.origin.x + 8, rect.origin.y + 6)];
        [arrows moveToPoint:NSMakePoint(rect.origin.x + 8, rect.origin.y + 6)];
        [arrows lineToPoint:NSMakePoint(rect.origin.x + 8, rect.origin.y + 9.5)];
        arrows.lineWidth = 1.2;
        [arrows stroke];
        return;
    }

    if ([name containsString:@"number"]) {
        NSBezierPath *bubble = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 2, rect.size.width - 2, rect.size.height - 4) xRadius:3 yRadius:3];
        [bubble fill];
        NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:8], NSForegroundColorAttributeName: NSColor.whiteColor};
        [@"#" drawInRect:NSMakeRect(rect.origin.x + 4.5, rect.origin.y + 3.3, 8, 8) withAttributes:attrs];
        return;
    }

    if ([name containsString:@"character"] || [name containsString:@"textformat"]) {
        NSBezierPath *bubble = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 2, rect.size.width - 2, rect.size.height - 4) xRadius:3 yRadius:3];
        [bubble fill];
        NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:9], NSForegroundColorAttributeName: NSColor.whiteColor};
        [@"T" drawInRect:NSMakeRect(rect.origin.x + 4.4, rect.origin.y + 2.5, 8, 9) withAttributes:attrs];
        return;
    }

    if ([name containsString:@"curlybraces"] || [name containsString:@"chevron"]) {
        NSBezierPath *code = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 1, rect.origin.y + 1.5, rect.size.width - 2, rect.size.height - 3) xRadius:3 yRadius:3];
        [code fill];
        NSDictionary *attrs = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:8], NSForegroundColorAttributeName: NSColor.whiteColor};
        [@"<>" drawInRect:NSMakeRect(rect.origin.x + 2.6, rect.origin.y + 3.2, 11, 8) withAttributes:attrs];
        return;
    }

    if ([name containsString:@"paintbrush"]) {
        NSBezierPath *drop = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(rect.origin.x + 2, rect.origin.y + 1.5, 10, 10)];
        [drop fill];
        [[NSColor whiteColor] setFill];
        NSBezierPath *shine = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(rect.origin.x + 5, rect.origin.y + 6.5, 3, 3)];
        [shine fill];
        return;
    }

    if ([name containsString:@"doc"] || [name containsString:@"filemenu"]) {
        NSBezierPath *doc = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 3, rect.origin.y + 1, 8, 12) xRadius:1.6 yRadius:1.6];
        [doc fill];
        NSBezierPath *fold = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:1 alpha:0.72] setFill];
        [fold moveToPoint:NSMakePoint(rect.origin.x + 8.2, rect.origin.y + 13)];
        [fold lineToPoint:NSMakePoint(rect.origin.x + 11, rect.origin.y + 10.2)];
        [fold lineToPoint:NSMakePoint(rect.origin.x + 8.2, rect.origin.y + 10.2)];
        [fold closePath];
        [fold fill];
        return;
    }

    NSBezierPath *fallback = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(rect.origin.x + 2, rect.origin.y + 2, rect.size.width - 4, rect.size.height - 4) xRadius:3 yRadius:3];
    [fallback fill];
}

- (NSColor *)tintColorForSymbol:(NSString *)name {
    if ([name containsString:@"terminal"]) {
        return [NSColor colorWithCalibratedRed:0.16 green:0.18 blue:0.22 alpha:1];
    }
    if ([name containsString:@"folder"]) {
        return [NSColor colorWithCalibratedRed:0.16 green:0.42 blue:0.92 alpha:1];
    }
    if ([name containsString:@"photo"]) {
        return [NSColor colorWithCalibratedRed:0.22 green:0.76 blue:0.38 alpha:1];
    }
    if ([name containsString:@"tablecells"]) {
        return [NSColor colorWithCalibratedRed:0.12 green:0.68 blue:0.34 alpha:1];
    }
    if ([name containsString:@"link"]) {
        return [NSColor colorWithCalibratedRed:0.18 green:0.75 blue:0.64 alpha:1];
    }
    if ([name containsString:@"ruler"] || [name containsString:@"arrow"]) {
        return [NSColor colorWithCalibratedRed:0.96 green:0.58 blue:0.20 alpha:1];
    }
    if ([name containsString:@"number"] || [name containsString:@"character"]) {
        return [NSColor colorWithCalibratedRed:0.58 green:0.38 blue:0.90 alpha:1];
    }
    if ([name containsString:@"doc"]) {
        return [NSColor colorWithCalibratedRed:0.20 green:0.52 blue:0.92 alpha:1];
    }
    return [NSColor colorWithCalibratedRed:0.24 green:0.56 blue:0.92 alpha:1];
}

- (NSImage *)symbolImageNamed:(NSString *)name {
    if (@available(macOS 11.0, *)) {
        NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
        image.size = NSMakeSize(16, 16);
        return image;
    }
    return nil;
}

- (void)handleMenuItem:(NSMenuItem *)sender {
    NSString *action = [self actionForMenuItem:sender];
    NSURL *directory = [self targetDirectory];
    [self log:[NSString stringWithFormat:@"menu title=%@ parent=%@ action=%@ directory=%@ selected=%@",
               sender.title ?: @"",
               sender.menu.title ?: @"",
               action ?: @"",
               directory.path ?: @"",
               [self selectedPathsString]]];

    if ([action isEqualToString:@"txt"]) {
        [self sendCommand:@"create" directory:directory extension:@"txt"];
    } else if ([action isEqualToString:@"md"]) {
        [self sendCommand:@"create" directory:directory extension:@"md"];
    } else if ([action isEqualToString:@"json"]) {
        [self sendCommand:@"create" directory:directory extension:@"json"];
    } else if ([action isEqualToString:@"csv"]) {
        [self sendCommand:@"create" directory:directory extension:@"csv"];
    } else if ([action isEqualToString:@"html"]) {
        [self sendCommand:@"create" directory:directory extension:@"html"];
    } else if ([action isEqualToString:@"yaml"]) {
        [self sendCommand:@"create" directory:directory extension:@"yaml"];
    } else if ([action isEqualToString:@"xml"]) {
        [self sendCommand:@"create" directory:directory extension:@"xml"];
    } else if ([action isEqualToString:@"sh"]) {
        [self sendCommand:@"create" directory:directory extension:@"sh"];
    } else if ([action isEqualToString:@"py"]) {
        [self sendCommand:@"create" directory:directory extension:@"py"];
    } else if ([action isEqualToString:@"js"]) {
        [self sendCommand:@"create" directory:directory extension:@"js"];
    } else if ([action isEqualToString:@"ts"]) {
        [self sendCommand:@"create" directory:directory extension:@"ts"];
    } else if ([action isEqualToString:@"css"]) {
        [self sendCommand:@"create" directory:directory extension:@"css"];
    } else if ([action isEqualToString:@"docx"]) {
        [self sendCommand:@"create" directory:directory extension:@"docx"];
    } else if ([action isEqualToString:@"xlsx"]) {
        [self sendCommand:@"create" directory:directory extension:@"xlsx"];
    } else if ([action isEqualToString:@"pptx"]) {
        [self sendCommand:@"create" directory:directory extension:@"pptx"];
    } else if ([action hasPrefix:@"copy-"]) {
        [self sendCommand:action directory:directory extension:nil];
    } else if ([action hasPrefix:@"move-to-"]) {
        [self sendCommand:action directory:directory extension:nil];
    } else if ([action isEqualToString:@"batch-rename"] ||
               [action hasPrefix:@"image-"] ||
               [action hasPrefix:@"text-"]) {
        [self sendCommand:action directory:directory extension:nil];
    } else if ([action isEqualToString:@"terminal"]) {
        [self sendCommand:@"terminal" directory:directory extension:nil];
    } else {
        [self log:[NSString stringWithFormat:@"unknown menu item %@", sender.title ?: @""]];
    }
}

- (NSString *)actionForMenuItem:(NSMenuItem *)item {
    NSString *taggedAction = [self actionForTag:item.tag];
    if (taggedAction.length > 0) {
        return taggedAction;
    }

    NSString *representedAction = (NSString *)item.representedObject;
    if (representedAction.length > 0) {
        return representedAction;
    }

    NSString *title = item.title ?: @"";
    NSString *menuTitle = item.menu.title ?: @"";

    if ([menuTitle isEqualToString:@"复制到"] || [menuTitle isEqualToString:@"移动到"]) {
        NSString *prefix = [menuTitle isEqualToString:@"复制到"] ? @"copy-to" : @"move-to";
        NSString *destination = [self destinationActionKeyForTitle:title];
        if (destination.length > 0) {
            return [NSString stringWithFormat:@"%@-%@", prefix, destination];
        }
    }

    if ([menuTitle isEqualToString:@"复制"]) {
        if ([title containsString:@"Markdown 链接"]) {
            return @"copy-markdown-link";
        }
        if ([title containsString:@"file URL"]) {
            return @"copy-file-url";
        }
        if ([title containsString:@"文件名"]) {
            return @"copy-name";
        }
        if ([title containsString:@"父目录"]) {
            return @"copy-parent";
        }
        if ([title containsString:@"路径"]) {
            return @"copy-path";
        }
    }

    if ([title containsString:@"Markdown 链接"]) {
        return @"copy-markdown-link";
    }
    if ([title containsString:@"file URL"]) {
        return @"copy-file-url";
    }
    if ([title containsString:@"文件名"]) {
        return @"copy-name";
    }
    if ([title containsString:@"父目录"]) {
        return @"copy-parent";
    }
    if ([title containsString:@"路径"]) {
        return @"copy-path";
    }
    if ([title containsString:@"TXT"]) {
        return @"txt";
    }
    if ([title containsString:@"Markdown"]) {
        return @"md";
    }
    if ([title containsString:@"JSON"]) {
        return @"json";
    }
    if ([title containsString:@"CSV"]) {
        return @"csv";
    }
    if ([title containsString:@"HTML"]) {
        return @"html";
    }
    if ([title containsString:@"YAML"]) {
        return @"yaml";
    }
    if ([title containsString:@"XML"]) {
        return @"xml";
    }
    if ([title containsString:@"Shell"]) {
        return @"sh";
    }
    if ([title containsString:@"Python"]) {
        return @"py";
    }
    if ([title containsString:@"JavaScript"]) {
        return @"js";
    }
    if ([title containsString:@"TypeScript"]) {
        return @"ts";
    }
    if ([title containsString:@"CSS"]) {
        return @"css";
    }
    if ([title containsString:@"Word"]) {
        return @"docx";
    }
    if ([title containsString:@"Excel"]) {
        return @"xlsx";
    }
    if ([title containsString:@"PowerPoint"]) {
        return @"pptx";
    }
    if ([title containsString:@"终端"]) {
        return @"terminal";
    }
    return nil;
}

- (NSDictionary<NSString *, NSNumber *> *)actionTags {
    return @{
        @"txt": @(QRMenuTagBase + 1),
        @"md": @(QRMenuTagBase + 2),
        @"json": @(QRMenuTagBase + 3),
        @"csv": @(QRMenuTagBase + 4),
        @"html": @(QRMenuTagBase + 5),
        @"yaml": @(QRMenuTagBase + 6),
        @"xml": @(QRMenuTagBase + 7),
        @"sh": @(QRMenuTagBase + 8),
        @"py": @(QRMenuTagBase + 9),
        @"js": @(QRMenuTagBase + 10),
        @"ts": @(QRMenuTagBase + 11),
        @"css": @(QRMenuTagBase + 12),
        @"docx": @(QRMenuTagBase + 13),
        @"xlsx": @(QRMenuTagBase + 14),
        @"pptx": @(QRMenuTagBase + 15),
        @"copy-path": @(QRMenuTagBase + 20),
        @"copy-name": @(QRMenuTagBase + 21),
        @"copy-parent": @(QRMenuTagBase + 22),
        @"copy-file-url": @(QRMenuTagBase + 23),
        @"copy-markdown-link": @(QRMenuTagBase + 24),
        @"copy-to-desktop": @(QRMenuTagBase + 30),
        @"copy-to-documents": @(QRMenuTagBase + 31),
        @"copy-to-downloads": @(QRMenuTagBase + 32),
        @"copy-to-pictures": @(QRMenuTagBase + 33),
        @"copy-to-movies": @(QRMenuTagBase + 34),
        @"copy-to-music": @(QRMenuTagBase + 35),
        @"copy-to-choose": @(QRMenuTagBase + 36),
        @"copy-to-favorite1": @(QRMenuTagBase + 37),
        @"copy-to-favorite2": @(QRMenuTagBase + 38),
        @"copy-to-favorite3": @(QRMenuTagBase + 39),
        @"move-to-desktop": @(QRMenuTagBase + 40),
        @"move-to-documents": @(QRMenuTagBase + 41),
        @"move-to-downloads": @(QRMenuTagBase + 42),
        @"move-to-pictures": @(QRMenuTagBase + 43),
        @"move-to-movies": @(QRMenuTagBase + 44),
        @"move-to-music": @(QRMenuTagBase + 45),
        @"move-to-choose": @(QRMenuTagBase + 46),
        @"move-to-favorite1": @(QRMenuTagBase + 47),
        @"move-to-favorite2": @(QRMenuTagBase + 48),
        @"move-to-favorite3": @(QRMenuTagBase + 49),
        @"batch-rename": @(QRMenuTagBase + 60),
        @"image-copy-size": @(QRMenuTagBase + 70),
        @"image-compress": @(QRMenuTagBase + 71),
        @"image-convert-png": @(QRMenuTagBase + 72),
        @"image-convert-jpeg": @(QRMenuTagBase + 73),
        @"image-convert-webp": @(QRMenuTagBase + 74),
        @"text-stats": @(QRMenuTagBase + 80),
        @"text-to-utf8": @(QRMenuTagBase + 81),
        @"text-preview": @(QRMenuTagBase + 82),
        @"terminal": @(QRMenuTagBase + 90)
    };
}

- (NSInteger)tagForAction:(NSString *)action {
    NSNumber *tag = [self actionTags][action ?: @""];
    return tag ? tag.integerValue : 0;
}

- (NSString *)actionForTag:(NSInteger)tag {
    if (tag == 0) {
        return nil;
    }
    NSDictionary<NSString *, NSNumber *> *tags = [self actionTags];
    for (NSString *action in tags) {
        if (tags[action].integerValue == tag) {
            return action;
        }
    }
    return nil;
}

- (NSString *)destinationActionKeyForTitle:(NSString *)title {
    if ([title containsString:@"选择文件夹"]) {
        return @"choose";
    }
    if ([title containsString:@"桌面"]) {
        return @"desktop";
    }
    if ([title containsString:@"文稿"]) {
        return @"documents";
    }
    if ([title containsString:@"下载"]) {
        return @"downloads";
    }
    if ([title containsString:@"图片"]) {
        return @"pictures";
    }
    if ([title containsString:@"影片"]) {
        return @"movies";
    }
    if ([title containsString:@"音乐"]) {
        return @"music";
    }
    return nil;
}

- (BOOL)isFeatureEnabled:(NSString *)key {
    NSDictionary *settings = [self settingsDictionary];
    NSNumber *value = settings[key];
    return value ? value.boolValue : YES;
}

- (NSDictionary *)settingsDictionary {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfURL:[self settingsURL]];
    return [settings isKindOfClass:NSDictionary.class] ? settings : @{};
}

- (NSURL *)settingsURL {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/QuickRightMenu/settings.plist"];
    return [NSURL fileURLWithPath:path];
}

- (NSURL *)targetDirectory {
    FIFinderSyncController *controller = [FIFinderSyncController defaultController];
    NSArray<NSURL *> *selectedURLs = controller.selectedItemURLs;
    if (selectedURLs.count == 1) {
        NSURL *selectedURL = selectedURLs.firstObject;
        NSNumber *isDirectory = nil;
        [selectedURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        if (isDirectory.boolValue) {
            return selectedURL;
        }
        return selectedURL.URLByDeletingLastPathComponent;
    }

    NSURL *targetedURL = controller.targetedURL;
    if (targetedURL) {
        return targetedURL;
    }

    return [NSURL fileURLWithPath:NSHomeDirectory()];
}

- (void)sendCommand:(NSString *)command directory:(NSURL *)directory extension:(NSString *)extension {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"quickrightmenu";
    components.host = command;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    [items addObject:[NSURLQueryItem queryItemWithName:@"dir" value:directory.path]];
    NSString *token = [self commandToken];
    if (token.length == 0) {
        [self log:@"missing command token"];
        return;
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"token" value:token]];
    NSString *selectedPaths = [self selectedPathsString];
    if (selectedPaths.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"paths" value:selectedPaths]];
    }
    if (extension) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"ext" value:extension]];
    }
    components.queryItems = items;

    NSURL *url = components.URL;
    if (!url) {
        [self log:@"command URL build failed"];
        return;
    }

    [self writeCommandFile:url.absoluteString];
}

- (void)writeCommandFile:(NSString *)urlString {
    NSString *directoryPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/QuickRightMenuCommands"];
    NSError *directoryError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                              withIntermediateDirectories:YES
                                               attributes:@{NSFilePosixPermissions: @0700}
                                                    error:&directoryError];
    if (directoryError) {
        [self log:[NSString stringWithFormat:@"command directory create failed %@", directoryError.localizedDescription]];
        return;
    }
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0700}
                                     ofItemAtPath:directoryPath
                                            error:nil];

    NSString *filename = [NSString stringWithFormat:@"command-%lld-%u.cmd",
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000),
                          arc4random_uniform(1000000)];
    NSURL *fileURL = [NSURL fileURLWithPath:[directoryPath stringByAppendingPathComponent:filename]];
    NSError *writeError = nil;
    BOOL ok = [urlString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (ok) {
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0600}
                                         ofItemAtPath:fileURL.path
                                                error:nil];
    }
    if (!ok || writeError) {
        [self log:[NSString stringWithFormat:@"write command file failed %@", writeError.localizedDescription]];
    } else {
        [self log:@"write command file"];
    }
}

- (NSString *)commandToken {
    NSString *token = [self settingsDictionary][@"commandToken"];
    return [token isKindOfClass:NSString.class] ? token : nil;
}

- (NSString *)selectedPathsString {
    NSArray<NSURL *> *selectedURLs = [FIFinderSyncController defaultController].selectedItemURLs;
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *url in selectedURLs) {
        if (url.path.length > 0) {
            [paths addObject:url.path];
        }
    }
    return [paths componentsJoinedByString:@"\n"];
}

- (void)log:(NSString *)message {
    NSLog(@"QuickRightMenu Extension: %@", message);
}

@end
