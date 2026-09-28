#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>
#import "../Shared/QRFeatures.h"

@interface FinderSync : FIFinderSync
@end

@implementation FinderSync



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
    NSDictionary *settings = [self settingsDictionary];
    NSArray *selected = [self selectedURLs];
    BOOL contextual = settings[@"contextualMenus"] ? [settings[@"contextualMenus"] boolValue] : YES;
    NSArray *pins = [settings[@"pinnedFeatures"] isKindOfClass:NSArray.class] ? settings[@"pinnedFeatures"] : @[];
    NSMutableDictionary<NSString *, NSMenu *> *groups = [NSMutableDictionary dictionary];
    NSArray *rows = QROrderedFeatures(settings);
    for (NSInteger pinnedPass = 1; pinnedPass >= 0; pinnedPass--) {
        for (NSDictionary *row in rows) {
            NSString *key = row[@"key"];
            if ([pins containsObject:key] != (pinnedPass == 1)) continue;
            if (settings[key] && ![settings[key] boolValue]) continue;
            if (!QRFeatureMatches(row, selected, contextual)) continue;
            NSString *title = row[@"title"];
            if ([key isEqualToString:@"openPreferred"] && [settings[@"preferredApplication"] length]) {
                title = [NSString stringWithFormat:@"用 %@ 打开", [settings[@"preferredApplication"] lastPathComponent].stringByDeletingPathExtension];
            }
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(handleMenuItem:) keyEquivalent:@""];
            item.target = self;
            item.tag = [row[@"tag"] integerValue];
            item.representedObject = row[@"action"];
            item.image = [self menuIconNamed:row[@"symbol"]];
            NSMenu *destination = menu;
            if (!pinnedPass) {
                NSString *category = row[@"category"];
                if (!groups[category]) {
                    NSMenuItem *group = [[NSMenuItem alloc] initWithTitle:category action:nil keyEquivalent:@""];
                    group.image = [self menuIconNamed:row[@"symbol"]];
                    groups[category] = [[NSMenu alloc] initWithTitle:category];
                    group.submenu = groups[category];
                    [menu addItem:group];
                }
                destination = groups[category];
            }
            [destination addItem:item];
        }
        if (pinnedPass && menu.numberOfItems) [menu addItem:NSMenuItem.separatorItem];
    }
    if (selected.count) {
        for (NSString *category in @[@"复制到", @"移动到"]) {
            NSMenu *destinations = groups[category] ?: [[NSMenu alloc] initWithTitle:category];
            [self addFavoriteDestinationItemsWithPrefix:[category isEqualToString:@"复制到"] ? @"copy-to" : @"move-to" toMenu:destinations];
            if (!groups[category] && destinations.numberOfItems) {
                NSMenuItem *parent = [[NSMenuItem alloc] initWithTitle:category action:nil keyEquivalent:@""];
                parent.submenu = destinations;
                [menu addItem:parent];
            }
        }
    }
    if (menu.itemArray.lastObject.isSeparatorItem) [menu removeItemAtIndex:menu.numberOfItems - 1];
    return menu;
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
        item.tag = ([commandPrefix isEqualToString:@"copy-to"] ? 48000 : 49000) + i;
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
    NSString *action = nil;
    for (NSDictionary *row in QRFeatureRows()) {
        if ([row[@"tag"] integerValue] == sender.tag) { action = row[@"action"]; break; }
    }
    if (!action) {
        for (NSInteger i = 1; i <= 3; i++) {
            if (sender.tag == 48000 + i) action = [NSString stringWithFormat:@"copy-to-favorite%ld", (long)i];
            if (sender.tag == 49000 + i) action = [NSString stringWithFormat:@"move-to-favorite%ld", (long)i];
        }
    }
    if (!action) return;
    NSArray *extensions = @[@"txt", @"md", @"json", @"csv", @"html", @"yaml", @"xml", @"sh", @"py", @"js", @"ts", @"css", @"docx", @"xlsx", @"pptx"];
    BOOL create = [extensions containsObject:action];
    [self sendCommand:create ? @"create" : action directory:[self targetDirectory] extension:create ? action : nil];
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
    NSArray<NSURL *> *selectedURLs = [self selectedURLs];
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
                                               attributes:nil
                                                    error:&directoryError];
    if (directoryError) {
        [self log:[NSString stringWithFormat:@"command directory create failed %@", directoryError.localizedDescription]];
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"command-%lld-%u.cmd",
                          (long long)([[NSDate date] timeIntervalSince1970] * 1000),
                          arc4random_uniform(1000000)];
    NSURL *fileURL = [NSURL fileURLWithPath:[directoryPath stringByAppendingPathComponent:filename]];
    NSError *writeError = nil;
    BOOL ok = [urlString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (!ok || writeError) {
        [self log:[NSString stringWithFormat:@"write command file failed %@", writeError.localizedDescription]];
    } else {
        [self log:[NSString stringWithFormat:@"write command file %@ %@", fileURL.path, urlString]];
    }
}

- (NSArray<NSURL *> *)selectedURLs {
    return [FIFinderSyncController defaultController].selectedItemURLs ?: @[];
}

- (NSString *)selectedPathsString {
    NSArray<NSURL *> *selectedURLs = [self selectedURLs];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *url in selectedURLs) {
        if (url.path.length > 0) {
            [paths addObject:url.path];
        }
    }
    NSData *json = [NSJSONSerialization dataWithJSONObject:paths options:0 error:NULL];
    return [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
}

- (void)log:(NSString *)message {
    NSLog(@"QuickRightMenu Extension: %@", message);
    NSString *line = [NSString stringWithFormat:@"%@ Extension: %@\n", [NSDate date], message];
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

@end
