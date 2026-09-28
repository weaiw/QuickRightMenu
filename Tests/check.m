#define main QRApplicationMain
#import "../Sources/App/main.m"
#undef main
#import "../Sources/FinderExtension/FinderSync.m"
#import <PDFKit/PDFKit.h>
#import <CoreText/CoreText.h>

#define CHECK(condition, message) do { if (!(condition)) { NSLog(@"FAIL: %@ (%s:%d)", (message), __FILE__, __LINE__); exit(1); } } while (0)

@interface QRTestDelegate : QRAppDelegate
@property(nonatomic, strong) NSURL *testDirectory;
@property(nonatomic, copy) NSString *lastError;
@property(nonatomic, strong) NSPasteboard *testPasteboard;
@end
@implementation QRTestDelegate
- (NSURL *)settingsURL { return [self.testDirectory URLByAppendingPathComponent:@"settings.plist"]; }
- (void)showError:(NSString *)message { self.lastError = message; }
- (void)applicationDidFinishLaunching:(NSNotification *)notification {}
- (void)log:(NSString *)message {}
- (NSPasteboard *)pasteboard { return self.testPasteboard; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return [NSProcessInfo.processInfo.arguments containsObject:@"--ui"]; }
- (void)applicationWillTerminate:(NSNotification *)notification { [[NSFileManager defaultManager] removeItemAtURL:self.testDirectory error:NULL]; }
@end

@interface QRTestFinder : FinderSync
@property(nonatomic, strong) NSDictionary *testSettings;
@property(nonatomic, strong) NSArray *testSelection;
@property(nonatomic, strong) NSURL *testDirectory;
@property(nonatomic, copy) NSString *lastCommand;
@end
@implementation QRTestFinder
- (NSDictionary *)settingsDictionary { return self.testSettings; }
- (NSArray *)selectedURLs { return self.testSelection; }
- (NSURL *)targetDirectory { return self.testDirectory; }
- (void)writeCommandFile:(NSString *)command { self.lastCommand = command; }
@end

static NSURL *FixtureImage(NSURL *directory, NSString *name, BOOL text) {
    NSUInteger w = text ? 1400 : 2400, h = text ? 500 : 1600;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CHECK(ctx, @"create fixture canvas");
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1); CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
    if (text) {
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 100, NULL);
        CGColorRef black = CGColorCreateGenericRGB(0, 0, 0, 1);
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:@"QuickRightMenu 2026" attributes:@{(id)kCTFontAttributeName: (__bridge id)font, (id)kCTForegroundColorAttributeName: (__bridge id)black}];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        CGContextSetTextPosition(ctx, 50, 200); CTLineDraw(line, ctx);
        CFRelease(line);
        NSAttributedString *chinese = [[NSAttributedString alloc] initWithString:@"中文测试" attributes:@{(id)kCTFontAttributeName: (__bridge id)font, (id)kCTForegroundColorAttributeName: (__bridge id)black}];
        line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)chinese);
        CGContextSetTextPosition(ctx, 50, 65); CTLineDraw(line, ctx);
        CFRelease(line); CFRelease(font); CGColorRelease(black);
    } else {
        uint8_t *pixels = CGBitmapContextGetData(ctx);
        uint32_t seed = 12345;
        for (NSUInteger i = 0; i < w * h; i++) {
            seed = seed * 1664525 + 1013904223;
            pixels[i * 4] = (seed >> 24); pixels[i * 4 + 1] = (seed >> 16); pixels[i * 4 + 2] = (seed >> 8); pixels[i * 4 + 3] = 255;
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(ctx); CGContextRelease(ctx);
    NSURL *url = [directory URLByAppendingPathComponent:name];
    CGImageDestinationRef out = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, text ? CFSTR("public.png") : CFSTR("public.jpeg"), 1, NULL);
    NSDictionary *metadata = text ? @{} : @{(id)kCGImagePropertyOrientation: @6, (id)kCGImagePropertyGPSDictionary: @{(id)kCGImagePropertyGPSLatitude: @31.2, (id)kCGImagePropertyGPSLatitudeRef: @"N"}};
    CGImageDestinationAddImage(out, image, (__bridge CFDictionaryRef)metadata);
    CHECK(CGImageDestinationFinalize(out), @"write fixture image");
    CFRelease(out); CGImageRelease(image);
    return url;
}

static NSDictionary *ImageProperties(NSURL *url) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    CHECK(source, @"read output image");
    NSDictionary *p = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)); CFRelease(source); return p;
}

static void WaitForBatch(QRTestDelegate *delegate) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (delegate.busy && deadline.timeIntervalSinceNow > 0) [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    CHECK(!delegate.busy, @"background batch completed");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        QRTestDelegate *delegate = [[QRTestDelegate alloc] init]; application.delegate = delegate;
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"QuickRightMenu-check-" stringByAppendingString:NSUUID.UUID.UUIDString]]];
        NSFileManager *fm = NSFileManager.defaultManager;
        CHECK([fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:NULL], @"create isolated test directory");
        delegate.testDirectory = root; delegate.testPasteboard = [NSPasteboard pasteboardWithUniqueName]; delegate.settings = [[delegate defaultSettings] mutableCopy]; delegate.undoRecords = @[];
        [application finishLaunching];
        if (argc > 1 && strcmp(argv[1], "--ui") == 0) {
            [application setActivationPolicy:NSApplicationActivationPolicyRegular];
            delegate.settingsPage = @"presets";
            [delegate showSettings:nil];
            NSLog(@"UI preview uses only %@", root.path);
            [application run];
            return 0;
        }
        NSError *error = nil;
        NSURL *a = [root URLByAppendingPathComponent:@"报告 1.txt"];
        NSData *content = [@"Hello 世界\n" dataUsingEncoding:NSUTF8StringEncoding];
        CHECK(QRWriteNewData(content, a, &error), @"create file");
        CHECK(!QRWriteNewData([NSData data], a, &error), @"exclusive writes refuse overwrite");
        CHECK([[NSData dataWithContentsOfURL:a] isEqual:content], @"existing content preserved");
        CHECK(!QRValidFilename(@"../escape") && !QRValidFilename(@"x:y") && QRValidFilename(@"新文件.txt"), @"validate names");
        NSString *weird = [root.path stringByAppendingPathComponent:@"two\nlines.txt"];
        NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:@[weird, a.path] options:0 error:NULL] encoding:NSUTF8StringEncoding];
        CHECK(([QRPathsFromString(json) isEqualToArray:@[weird, a.path]]), @"JSON bridge preserves newline filenames");
        CHECK(QRPathsFromString(@"[\"relative\"]").count == 0 && QRPathsFromString(@"[12]").count == 0, @"reject malformed path arrays");
        CHECK([QRPathsFromString(a.path).firstObject isEqual:a.path], @"legacy command compatibility");
        NSMutableSet *keys = [NSMutableSet set], *tags = [NSMutableSet set], *actions = [NSMutableSet set];
        for (NSDictionary *row in QRFeatureRows()) { [keys addObject:row[@"key"]]; [tags addObject:row[@"tag"]]; [actions addObject:row[@"action"]]; }
        CHECK(keys.count == QRFeatureRows().count && tags.count == keys.count && actions.count == keys.count, @"feature identities unique");
        CHECK([QROrderedFeatures(@{@"menuOrder": @[@"imageOCR", @"newTxt"]}).firstObject[@"key"] isEqual:@"imageOCR"], @"saved menu ordering");
        NSDictionary *imageRow = @{ @"context": @"image" }, *textRow = @{ @"context": @"text" };
        CHECK(!QRFeatureMatches(imageRow, @[a], YES) && QRFeatureMatches(textRow, @[a], YES), @"context menu filters text and image");
        CHECK(!QRFeatureMatches(imageRow, @[], NO), @"selection tools absent in background menu");
        NSArray *plan = QRRenamePlan(@[a.path], @{@"mode": @"prefix", @"text": @"已审-"}, &error);
        CHECK(plan.count == 1 && [plan[0][@"target"] hasSuffix:@"已审-报告 1.txt"], @"rename prefix preview");
        NSDictionary *record = QRMoveFile(a.path, plan[0][@"target"], &error);
        CHECK(record && !QRPathExists(a.path), @"rename runs");
        CHECK(QRUndoMove(record, &error) && QRPathExists(a.path), @"rename undo restores original");
        CHECK(QRRenamePlan(@[a.path], @{@"mode": @"replace", @"text": @"报告", @"replacement": @"合同"}, &error).count == 1, @"find replace plan");
        CHECK(QRRenamePlan(@[a.path], @{@"mode": @"replace", @"text": @""}, &error) == nil, @"empty find rejected");
        CHECK(QRRenamePlan(@[a.path], @{@"mode": @"prefix", @"text": @"../"}, &error) == nil, @"rename traversal rejected");
        NSURL *conflict = [root URLByAppendingPathComponent:@"已审-报告 1.txt"];
        CHECK(QRWriteNewData(content, conflict, &error), @"create collision");
        CHECK(QRRenamePlan(@[a.path], @{@"mode": @"prefix", @"text": @"已审-"}, &error) == nil, @"rename conflict rejects before mutation");
        CHECK(!QRMoveFile(a.path, conflict.path, &error), @"move refuses overwrite");
        [fm removeItemAtURL:conflict error:NULL];
        record = QRMoveFile(a.path, conflict.path, &error);
        CHECK(QRWriteNewData(content, a, &error), @"occupy original location");
        CHECK(!QRUndoMove(record, &error) && QRPathExists(conflict.path), @"undo preserves occupied path");
        [fm removeItemAtURL:a error:NULL];
        CHECK(QRUndoMove(record, &error), @"failed undo can retry");
        record = QRMoveFile(a.path, conflict.path, &error);
        [@"changed content" writeToURL:conflict atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        CHECK(!QRUndoMove(record, &error), @"undo refuses changed output");
        CHECK(QRWriteNewData(content, a, &error), @"restore test input");
        NSString *link = [root.path stringByAppendingPathComponent:@"dangling.txt"];
        CHECK([fm createSymbolicLinkAtPath:link withDestinationPath:@"missing" error:&error], @"create dangling symlink");
        CHECK(QRPathExists(link) && ![QRUniqueURL(root, @"dangling.txt").path isEqual:link], @"unique names account for dangling symlinks");
        NSURL *project = QRCreateProject(root, @"项目", &error);
        CHECK(project && QRPathExists([project.path stringByAppendingPathComponent:@"素材"]) && QRPathExists([project.path stringByAppendingPathComponent:@"README.md"]), @"project template contents");
        CHECK(QRCopyTemplate(project, root, @"副本", &error) != nil, @"copy folder template");
        CHECK(QRCopyTemplate(project, project, @"recursive", &error) == nil, @"template recursion prevented");
        CHECK(QRCopyTemplate(a, root, @"合同模板.docx", &error) != nil, @"binary file templates preserve bytes");
        NSString *manifest = QRFileManifest(@[project.path], @"tree", nil, &error);
        CHECK([manifest containsString:@"项目/"] && [manifest containsString:@"  README.md"], @"recursive directory tree");
        NSURL *formula = [root URLByAppendingPathComponent:@"=SUM(1,2).txt"];
        CHECK(QRWriteNewData(content, formula, &error), @"formula-like filename fixture");
        NSString *csv = QRFileManifest(@[formula.path], @"csv", nil, &error);
        CHECK([csv containsString:@"\"'=SUM(1,2).txt\""] && [csv containsString:@"路径,类型"], @"CSV quoting and spreadsheet formula protection");
        CHECK(QRWriteNewData(content, [NSURL fileURLWithPath:weird], &error), @"newline path fixture");
        CHECK([QRFileManifest(@[weird], @"md", nil, &error) containsString:@"two\\\\nlines.txt"], @"Markdown filename escaping");
        NSProgress *cancelled = [NSProgress progressWithTotalUnitCount:1]; [cancelled cancel];
        CHECK(QRFileManifest(@[root.path], @"tree", cancelled, &error) == nil, @"manifest cancellation");
        NSURL *image = FixtureImage(root, @"noise.jpg", NO);
        CHECK(QRFeatureMatches(imageRow, @[image], YES) && !QRFeatureMatches(imageRow, @[image, a], YES), @"mixed selections hide incompatible actions");
        NSURL *resized = QRProcessImage(image, root, @{@"format": @"jpg", @"maxSide": @800, @"stripMetadata": @YES}, nil, &error);
        CHECK(resized, error.localizedDescription ?: @"resize");
        CHECK(ImageProperties(image)[(id)kCGImagePropertyGPSDictionary] != nil, @"source fixture contains GPS metadata");
        NSURL *preserved = QRProcessImage(image, root, @{@"format": @"jpg", @"maxSide": @800, @"stripMetadata": @NO}, nil, &error);
        CHECK(ImageProperties(preserved)[(id)kCGImagePropertyGPSDictionary] != nil, @"metadata preserved when removal is disabled");
        CHECK([ImageProperties(preserved)[(id)kCGImagePropertyOrientation] integerValue] == 1, @"preserved metadata has normalized orientation");
        NSDictionary *properties = ImageProperties(resized);
        CHECK(MAX([properties[(id)kCGImagePropertyPixelWidth] integerValue], [properties[(id)kCGImagePropertyPixelHeight] integerValue]) == 800, @"image longest side");
        CHECK([properties[(id)kCGImagePropertyPixelHeight] integerValue] >= [properties[(id)kCGImagePropertyPixelWidth] integerValue], @"EXIF rotation normalized");
        CHECK(!properties[(id)kCGImagePropertyGPSDictionary], @"GPS metadata stripped");
        NSURL *small = QRProcessImage(image, root, @{@"format": @"jpg", @"targetBytes": @102400, @"stripMetadata": @YES}, nil, &error);
        CHECK(small && [[fm attributesOfItemAtPath:small.path error:NULL][NSFileSize] unsignedIntegerValue] <= 102400, @"target file size respected");
        NSURL *watermark = QRProcessImage(image, root, @{@"format": @"png", @"maxSide": @500, @"watermark": @"QuickRightMenu 测试", @"stripMetadata": @YES}, nil, &error);
        CHECK(watermark && QRPathExists(watermark.path), @"watermark export");
        CHECK(!QRProcessImage(image, root, @{@"format": @"png", @"targetBytes": @100}, nil, &error), @"invalid image target rejected");
        CHECK(!QRProcessImage(image, root, @{@"format": @"jpg"}, cancelled, &error), @"image cancellation");
        CHECK(QRPathExists(image.path), @"image originals preserved");
        NSURL *pdf = QRCreatePDF(@[resized.path, small.path], root, @"images", YES, nil, &error);
        CHECK(pdf && [[[PDFDocument alloc] initWithURL:pdf] pageCount] == 2, @"images to PDF pages");
        NSURL *merged = QRCreatePDF(@[pdf.path, pdf.path], root, @"merged.pdf", NO, nil, &error);
        CHECK(merged && [[[PDFDocument alloc] initWithURL:merged] pageCount] == 4, @"PDF merge page order/count");
        CHECK(!QRCreatePDF(@[pdf.path], root, @"cancel", NO, cancelled, &error), @"PDF cancellation");
        NSURL *textImage = FixtureImage(root, @"text.png", YES);
        NSString *ocr = QRRecognizeText(textImage, &error);
        CHECK([ocr containsString:@"2026"] && [ocr containsString:@"中文"], error.localizedDescription ?: @"OCR recognizes fixture text");
        delegate.settings[@"pinnedFeatures"] = @[@"copyPath"];
        delegate.settings[@"menuOrder"] = @[@"imageOCR", @"newTxt"];
        [delegate saveSettings]; delegate.settings = [[delegate loadSettings] mutableCopy];
        CHECK([delegate.settings[@"pinnedFeatures"] containsObject:@"copyPath"] && [delegate.settings[@"imagePresets"] count] == 1, @"settings persist new data and preserve defaults");
        __block NSArray *results = nil;
        [delegate runBatch:@"Batch check" items:@[a.path, @"/missing"] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **failure) {
            if (!QRPathExists(path)) { *failure = QRError(@"expected failure"); return nil; }
            return @{@"message": @"ok"};
        } completion:^(NSArray *entries) { results = entries; }];
        CHECK(delegate.busy, @"batch begins asynchronously"); WaitForBatch(delegate);
        CHECK(results.count == 2 && [results[1][@"error"] isEqual:@"expected failure"] && [delegate.jobStatus.stringValue containsString:@"成功 1，失败 1"], @"per-file results report partial failure");
        [delegate runBatch:@"Cancel check" items:@[@"one", @"two"] operation:^NSDictionary *(NSString *path, NSProgress *progress, NSError **failure) {
            [progress cancel]; return @{@"message": @"first completed"};
        } completion:^(NSArray *entries) { results = entries; }];
        WaitForBatch(delegate); CHECK(results.count == 1 && [delegate.jobStatus.stringValue containsString:@"未执行 1"], @"cancellation leaves later items untouched");
        [delegate.testPasteboard clearContents];
        [delegate.testPasteboard setString:@"Clipboard 测试" forType:NSPasteboardTypeString];
        [delegate saveClipboardAtDirectory:root format:@"md"]; WaitForBatch(delegate);
        CHECK([[NSString stringWithContentsOfURL:delegate.jobOutputs.firstObject encoding:NSUTF8StringEncoding error:NULL] isEqual:@"Clipboard 测试"], @"clipboard text to actual Markdown file");
        [delegate.testPasteboard clearContents];
        [delegate.testPasteboard setData:[NSData dataWithContentsOfURL:textImage] forType:NSPasteboardTypePNG];
        [delegate saveClipboardAtDirectory:root format:@"png"]; WaitForBatch(delegate);
        CHECK([ImageProperties(delegate.jobOutputs.firstObject)[(id)kCGImagePropertyPixelWidth] integerValue] == 1400, @"clipboard image to actual PNG");
        QRTestFinder *finder = [[QRTestFinder alloc] init];
        finder.testDirectory = root; finder.testSelection = @[image];
        finder.testSettings = @{@"pinnedFeatures": @[@"resizeImage"], @"menuOrder": @[@"resizeImage", @"imageOCR"], @"textStats": @NO};
        NSMenu *menu = [finder menuForMenuKind:FIMenuKindContextualMenuForItems];
        CHECK([menu.itemArray.firstObject.title containsString:@"1920"], @"Finder menu puts pinned action first");
        CHECK([menu itemWithTitle:@"文本工具"] == nil, @"Finder image menu excludes text group");
        [finder handleMenuItem:menu.itemArray.firstObject];
        CHECK([finder.lastCommand hasPrefix:@"quickrightmenu://image-resize?"], @"Finder action encodes correct command");
        [delegate handleCommandURLString:finder.lastCommand source:@"command file"]; WaitForBatch(delegate);
        CHECK([ImageProperties(delegate.jobOutputs.firstObject)[(id)kCGImagePropertyPixelHeight] integerValue] == 1920, @"Finder-to-app image action end to end");
        finder.testSelection = @[a]; menu = [finder menuForMenuKind:FIMenuKindContextualMenuForItems];
        CHECK([menu itemWithTitle:@"图片工具"] == nil && [menu itemWithTitle:@"文本工具"] != nil, @"Finder text selection menu");
        finder.testSelection = @[]; menu = [finder menuForMenuKind:FIMenuKindContextualMenuForContainer];
        CHECK([menu itemWithTitle:@"复制到"] == nil && [menu itemWithTitle:@"新建文件"] != nil, @"Finder background menu");
        finder.testSelection = @[[NSURL fileURLWithPath:weird]];
        CHECK([QRPathsFromString([finder selectedPathsString]).firstObject isEqual:weird], @"Finder bridge carries newline filename unchanged");
        [delegate showTextStatsForPaths:a.path directory:root]; WaitForBatch(delegate);
        CHECK([[delegate.testPasteboard stringForType:NSPasteboardTypeString] containsString:@"字符"], @"background text statistics copies result");
        [delegate.textPreviewWindow close];
        [delegate.testPasteboard releaseGlobally];
        delegate.settingsPage = @"menu"; [delegate showSettings:nil];
        CHECK(delegate.menuScrollView.documentView.frame.size.height > 378, @"menu settings contains all items in scroll area");
        for (NSString *page in @[@"templates", @"presets", @"terminal", @"favorites", @"permissions", @"login", @"update"]) { delegate.settingsPage = page; [delegate rebuildSettingsWindow]; }
        [delegate.settingsWindow close]; [delegate.jobWindow close];
        CHECK([fm removeItemAtURL:root error:&error], @"remove test fixture directory");
        NSLog(@"PASS: menu/settings, paths, collision-safe writes, rename/undo, templates, manifests, images, PDF, OCR, background batches and cancellation");
    }
    return 0;
}
