#import "QRFileOperations.h"
#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#import <PDFKit/PDFKit.h>
#import <Vision/Vision.h>
#import <CoreText/CoreText.h>
#import <sys/stat.h>

NSError *QRError(NSString *message) {
    return [NSError errorWithDomain:@"QuickRightMenu" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

BOOL QRValidFilename(NSString *name) {
    return [name isKindOfClass:NSString.class] && name.length && ![@[@".", @".."] containsObject:name] &&
        [name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/:"]].location == NSNotFound &&
        [name rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
}

BOOL QRPathExists(NSString *path) {
    struct stat info;
    return lstat(path.fileSystemRepresentation, &info) == 0;
}

NSURL *QRUniqueURL(NSURL *directory, NSString *filename) {
    NSURL *url = [directory URLByAppendingPathComponent:filename];
    NSString *ext = filename.pathExtension, *base = filename.stringByDeletingPathExtension;
    for (NSUInteger i = 2; QRPathExists(url.path); i++) {
        NSString *next = ext.length ? [NSString stringWithFormat:@"%@ %lu.%@", base, (unsigned long)i, ext]
                                   : [NSString stringWithFormat:@"%@ %lu", filename, (unsigned long)i];
        url = [directory URLByAppendingPathComponent:next];
    }
    return url;
}

BOOL QRWriteNewData(NSData *data, NSURL *url, NSError **error) {
    if (!data) { if (error) *error = QRError(@"无法生成文件内容"); return NO; }
    // Exclusive creation also protects against a file appearing after the name was chosen.
    return [data writeToURL:url options:NSDataWritingWithoutOverwriting error:error];
}

NSArray<NSDictionary *> *QRRenamePlan(NSArray<NSString *> *paths, NSDictionary *options, NSError **error) {
    NSMutableArray *plan = [NSMutableArray array];
    NSMutableSet *targets = [NSMutableSet set];
    NSString *mode = options[@"mode"], *text = options[@"text"] ?: @"";
    NSDateFormatter *date = [[NSDateFormatter alloc] init];
    date.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    date.dateFormat = @"yyyy-MM-dd";
    NSUInteger index = MAX(1, [options[@"start"] integerValue]);
    for (NSString *path in [paths sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error];
        if (!attributes) return nil;
        BOOL directory = [attributes[NSFileType] isEqualToString:NSFileTypeDirectory];
        NSString *filename = path.lastPathComponent;
        NSString *ext = directory ? @"" : filename.pathExtension;
        NSString *base = ext.length ? filename.stringByDeletingPathExtension : filename;
        if ([mode isEqualToString:@"prefix"]) base = [text stringByAppendingString:base];
        else if ([mode isEqualToString:@"suffix"]) base = [base stringByAppendingString:text];
        else if ([mode isEqualToString:@"replace"]) {
            if (!text.length) { if (error) *error = QRError(@"查找内容不能为空"); return nil; }
            base = [base stringByReplacingOccurrencesOfString:text withString:options[@"replacement"] ?: @""];
        } else if ([mode isEqualToString:@"date"]) base = [NSString stringWithFormat:@"%@ %@", [date stringFromDate:[NSDate date]], base];
        else if ([mode isEqualToString:@"number"]) base = [NSString stringWithFormat:@"%@ %03lu", text.length ? text : @"文件", (unsigned long)index];
        else { if (error) *error = QRError(@"未知重命名方式"); return nil; }
        NSString *name = ext.length ? [base stringByAppendingPathExtension:ext] : base;
        if (!QRValidFilename(name)) { if (error) *error = QRError(@"名称不能为空，也不能包含斜杠、冒号或控制字符"); return nil; }
        NSString *target = [path.stringByDeletingLastPathComponent stringByAppendingPathComponent:name];
        BOOL unchanged = [path isEqualToString:target];
        // Conservative conflict handling also works on case-insensitive volumes.
        NSString *key = target.precomposedStringWithCanonicalMapping.lowercaseString;
        if ([targets containsObject:key] || (!unchanged && QRPathExists(target))) {
            if (error) *error = QRError([NSString stringWithFormat:@"目标名称冲突：%@。请修改规则后重试。", name]);
            return nil;
        }
        [targets addObject:key];
        [plan addObject:@{@"source": path, @"target": target, @"unchanged": @(unchanged)}];
        index++;
    }
    return plan;
}

static NSDictionary *QRFingerprint(NSString *path) {
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if (!a) return nil;
    return @{ @"inode": a[NSFileSystemFileNumber] ?: @0, @"device": a[NSFileSystemNumber] ?: @0,
              @"size": a[NSFileSize] ?: @0, @"modified": a[NSFileModificationDate] ?: [NSDate distantPast],
              @"type": a[NSFileType] ?: @"" };
}

NSDictionary *QRMoveFile(NSString *source, NSString *target, NSError **error) {
    if ([source isEqualToString:target]) { if (error) *error = QRError(@"源路径与目标路径相同"); return nil; }
    if (QRPathExists(target)) { if (error) *error = QRError(@"目标已存在，未覆盖任何文件"); return nil; }
    if (![[NSFileManager defaultManager] moveItemAtPath:source toPath:target error:error]) return nil;
    return @{@"source": source, @"target": target, @"fingerprint": QRFingerprint(target) ?: @{}};
}

BOOL QRUndoMove(NSDictionary *record, NSError **error) {
    NSString *original = record[@"source"], *current = record[@"target"];
    NSDictionary *fingerprint = QRFingerprint(current);
    if (QRPathExists(original)) { if (error) *error = QRError(@"原位置已有同名文件，未覆盖。请移开该文件后重试撤销。"); return NO; }
    if (!fingerprint || ![fingerprint isEqual:record[@"fingerprint"]]) {
        if (error) *error = QRError(@"文件已被修改、替换或移动，跳过撤销"); return NO;
    }
    return [[NSFileManager defaultManager] moveItemAtPath:current toPath:original error:error];
}

NSURL *QRCopyTemplate(NSURL *source, NSURL *directory, NSString *name, NSError **error) {
    if (!QRValidFilename(name)) { if (error) *error = QRError(@"模板名称无效"); return nil; }
    NSString *from = source.URLByResolvingSymlinksInPath.path;
    NSString *to = directory.URLByResolvingSymlinksInPath.path;
    if ([to isEqualToString:from] || [to hasPrefix:[from stringByAppendingString:@"/"]]) {
        if (error) *error = QRError(@"不能把模板复制到它自身或内部"); return nil;
    }
    NSURL *target = QRUniqueURL(directory, name);
    return [[NSFileManager defaultManager] copyItemAtURL:source toURL:target error:error] ? target : nil;
}

NSURL *QRCreateProject(NSURL *directory, NSString *name, NSError **error) {
    if (!QRValidFilename(name)) { if (error) *error = QRError(@"项目名称无效"); return nil; }
    NSURL *target = QRUniqueURL(directory, name);
    if (mkdir(target.path.fileSystemRepresentation, 0755) != 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSFilePathErrorKey: target.path}];
        return nil;
    }
    for (NSString *child in @[@"文档", @"素材", @"输出"]) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:[target URLByAppendingPathComponent:child] withIntermediateDirectories:NO attributes:nil error:error]) {
            [[NSFileManager defaultManager] removeItemAtURL:target error:NULL]; return nil;
        }
    }
    NSString *readme = [NSString stringWithFormat:@"# %@\n\n- 文档：需求和记录\n- 素材：原始文件\n- 输出：交付文件\n", name];
    if (!QRWriteNewData([readme dataUsingEncoding:NSUTF8StringEncoding], [target URLByAppendingPathComponent:@"README.md"], error)) {
        [[NSFileManager defaultManager] removeItemAtURL:target error:NULL]; return nil;
    }
    return target;
}

static CGImageRef QRLoadImage(NSURL *url, NSUInteger maxSide, NSDictionary **metadata, NSError **error) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) { if (error) *error = QRError(@"无法读取图片"); return NULL; }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    NSUInteger side = MAX([properties[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue], [properties[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue]);
    NSDictionary *options = @{(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                              (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                              (id)kCGImageSourceThumbnailMaxPixelSize: @(maxSide ? MIN(maxSide, side) : side)};
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (metadata) *metadata = properties;
    if (!image && error) *error = QRError(@"无法解码图片");
    return image;
}

static CGImageRef QRRenderImage(CGImageRef image, CGFloat scale, BOOL opaque, NSString *watermark) {
    size_t w = MAX(1, (size_t)(CGImageGetWidth(image) * scale)), h = MAX(1, (size_t)(CGImageGetHeight(image) * scale));
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, color, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(color);
    if (!ctx) return NULL;
    if (opaque) { CGContextSetRGBFillColor(ctx, 1, 1, 1, 1); CGContextFillRect(ctx, CGRectMake(0, 0, w, h)); }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);
    if (watermark.length) {
        CGFloat fontSize = MAX(8, MIN(w, h) * 0.045), margin = MAX(4, fontSize * 0.6);
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), fontSize, NULL);
        CGColorRef white = CGColorCreateGenericRGB(1, 1, 1, 0.9);
        NSAttributedString *text = [[NSAttributedString alloc] initWithString:watermark attributes:@{(id)kCTFontAttributeName: (__bridge id)font, (id)kCTForegroundColorAttributeName: (__bridge id)white}];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
        CGFloat width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
        CGFloat fit = MIN(1, (w - 2 * margin) / MAX(1, width));
        CGContextSetRGBFillColor(ctx, 0, 0, 0, 0.45);
        CGContextFillRect(ctx, CGRectMake(0, 0, w, fontSize * fit + margin * 2));
        CGContextTranslateCTM(ctx, margin, margin);
        CGContextScaleCTM(ctx, fit, fit);
        CGContextSetTextPosition(ctx, 0, 0);
        CTLineDraw(line, ctx);
        CFRelease(line); CGColorRelease(white); CFRelease(font);
    }
    CGImageRef result = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return result;
}

static NSData *QREncodeImage(CGImageRef image, NSString *uti, CGFloat quality, NSDictionary *metadata) {
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)uti, 1, NULL);
    if (!dest) return nil;
    NSMutableDictionary *properties = [metadata mutableCopy] ?: [NSMutableDictionary dictionary];
    properties[(id)kCGImagePropertyOrientation] = @1;
    properties[(id)kCGImagePropertyPixelWidth] = @(CGImageGetWidth(image));
    properties[(id)kCGImagePropertyPixelHeight] = @(CGImageGetHeight(image));
    properties[(id)kCGImageDestinationLossyCompressionQuality] = @(quality);
    [properties removeObjectForKey:(id)kCGImagePropertyThumbnailImages];
    CGImageDestinationAddImage(dest, image, (__bridge CFDictionaryRef)properties);
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return ok ? data : nil;
}

NSURL *QRProcessImage(NSURL *source, NSURL *directory, NSDictionary *options, NSProgress *progress, NSError **error) {
    NSString *format = options[@"format"] ?: @"jpg";
    NSString *uti = @{@"jpg": @"public.jpeg", @"png": @"public.png", @"webp": @"org.webmproject.webp"}[format];
    NSUInteger targetBytes = [options[@"targetBytes"] unsignedIntegerValue];
    if (!uti || (targetBytes && ![format isEqualToString:@"jpg"])) { if (error) *error = QRError(@"目标体积仅支持 JPEG"); return nil; }
    if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
    NSDictionary *metadata = nil;
    CGImageRef original = QRLoadImage(source, [options[@"maxSide"] unsignedIntegerValue], &metadata, error);
    if (!original) return nil;
    if ([options[@"stripMetadata"] boolValue]) metadata = nil;
    CGFloat quality = options[@"quality"] ? [options[@"quality"] doubleValue] : 0.9;
    NSString *watermark = [options[@"watermark"] isKindOfClass:NSString.class] ? options[@"watermark"] : @"";
    NSData *data = nil;
    // ponytail: bounded quality/size search; add a configurable quality floor if professional export needs it.
    for (NSInteger resize = 0; resize < (targetBytes ? 12 : 1); resize++) {
        if (progress.cancelled) break;
        CGImageRef rendered = QRRenderImage(original, pow(0.8, resize), [format isEqualToString:@"jpg"], watermark);
        if (!rendered) break;
        data = QREncodeImage(rendered, uti, quality, metadata);
        if (data && targetBytes && data.length > targetBytes) {
            NSData *smallest = QREncodeImage(rendered, uti, 0.15, metadata);
            if (smallest.length && smallest.length <= targetBytes) {
                data = smallest;
                CGFloat low = 0.15, high = quality;
                for (NSInteger step = 0; step < 7 && !progress.cancelled; step++) {
                    CGFloat q = (low + high) / 2;
                    NSData *candidate = QREncodeImage(rendered, uti, q, metadata);
                    if (candidate.length && candidate.length <= targetBytes) { data = candidate; low = q; }
                    else high = q;
                }
            }
        }
        CGImageRelease(rendered);
        if (!data || !targetBytes || data.length <= targetBytes) break;
    }
    CGImageRelease(original);
    if (progress.cancelled || !data || (targetBytes && data.length > targetBytes)) {
        if (error) *error = QRError(progress.cancelled ? @"已取消" : (!data ? @"当前系统不支持该格式写入，或图片编码失败" : @"未能达到目标体积，未生成文件"));
        return nil;
    }
    NSString *name = [[source.lastPathComponent.stringByDeletingPathExtension stringByAppendingString:@"-processed"] stringByAppendingPathExtension:format];
    NSURL *target = QRUniqueURL(directory, name);
    return QRWriteNewData(data, target, error) ? target : nil;
}

NSURL *QRCreatePDF(NSArray<NSString *> *paths, NSURL *directory, NSString *name, BOOL images, NSProgress *progress, NSError **error) {
    if (!paths.count || !QRValidFilename(name)) { if (error) *error = QRError(@"请选择文件并输入有效名称"); return nil; }
    PDFDocument *result = [[PDFDocument alloc] init];
    for (NSString *path in paths) {
        if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
        if (images) {
            CGImageRef image = QRLoadImage([NSURL fileURLWithPath:path], 0, NULL, error);
            if (!image) return nil;
            NSImage *native = [[NSImage alloc] initWithCGImage:image size:NSZeroSize];
            CGImageRelease(image);
            PDFPage *page = [[PDFPage alloc] initWithImage:native];
            if (!page) { if (error) *error = QRError(@"无法将图片写入 PDF"); return nil; }
            [result insertPage:page atIndex:result.pageCount];
        } else {
            PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
            if (!document || document.isLocked || !document.pageCount) {
                if (error) *error = QRError([NSString stringWithFormat:@"PDF 无法读取、已加密或没有页面：%@", path.lastPathComponent]); return nil;
            }
            for (NSUInteger i = 0; i < document.pageCount; i++) {
                if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
                [result insertPage:[[document pageAtIndex:i] copy] atIndex:result.pageCount];
            }
        }
    }
    if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
    NSURL *target = QRUniqueURL(directory, [name.pathExtension.lowercaseString isEqualToString:@"pdf"] ? name : [name stringByAppendingPathExtension:@"pdf"]);
    return QRWriteNewData(result.dataRepresentation, target, error) ? target : nil;
}

NSString *QRRecognizeText(NSURL *source, NSError **error) {
    VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] init];
    request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
    request.usesLanguageCorrection = YES;
    request.automaticallyDetectsLanguage = YES;
    NSArray *supported = [request supportedRecognitionLanguagesAndReturnError:error];
    if (!supported) return nil;
    NSMutableArray *languages = [NSMutableArray array];
    for (NSString *language in @[@"zh-Hans", @"en-US"]) if ([supported containsObject:language]) [languages addObject:language];
    if (languages.count) request.recognitionLanguages = languages;
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithURL:source options:@{}];
    if (![handler performRequests:@[request] error:error]) return nil;
    NSMutableArray *lines = [NSMutableArray array];
    for (VNRecognizedTextObservation *observation in request.results) {
        NSString *text = [observation topCandidates:1].firstObject.string;
        if (text.length) [lines addObject:text];
    }
    return [lines componentsJoinedByString:@"\n"];
}

static NSString *QREscapeCell(NSString *value, NSString *format) {
    if ([format isEqualToString:@"csv"]) {
        if (value.length && [@"=+-@\t\r\n" containsString:[value substringToIndex:1]]) value = [@"'" stringByAppendingString:value];
        return [NSString stringWithFormat:@"\"%@\"", [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
    }
    NSString *text = [[value stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    if ([format isEqualToString:@"md"]) {
        text = [text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        text = [text stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        for (NSString *character in @[@"\\", @"|", @"`", @"*", @"_", @"[", @"]"]) text = [text stringByReplacingOccurrencesOfString:character withString:[@"\\" stringByAppendingString:character]];
    }
    return text;
}

NSString *QRFileManifest(NSArray<NSString *> *paths, NSString *format, NSProgress *progress, NSError **error) {
    NSMutableString *output = [NSMutableString string];
    if ([format isEqualToString:@"csv"]) [output appendString:@"\uFEFF路径,类型,大小（字节）,修改时间\r\n"];
    if ([format isEqualToString:@"md"]) [output appendString:@"| 路径 | 类型 | 大小（字节） | 修改时间 |\n| --- | --- | ---: | --- |\n"];
    NSISO8601DateFormatter *date = [[NSISO8601DateFormatter alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    // ponytail: collect paths to sort deterministically; use streaming export for million-file inventories.
    NSMutableSet *seen = [NSMutableSet set];
    for (NSString *root in [paths sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        NSMutableArray *all = [NSMutableArray arrayWithObject:root];
        NSDictionary *rootAttributes = [fm attributesOfItemAtPath:root error:error];
        if (!rootAttributes) return nil;
        if ([rootAttributes[NSFileType] isEqualToString:NSFileTypeDirectory]) {
            __block NSError *walkError = nil;
            NSDirectoryEnumerator *walk = [fm enumeratorAtURL:[NSURL fileURLWithPath:root] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL *url, NSError *failure) { walkError = failure; return NO; }];
            for (NSURL *url in walk) {
                if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
                [all addObject:url.path];
            }
            if (walkError) { if (error) *error = walkError; return nil; }
        }
        [all sortUsingSelector:@selector(localizedStandardCompare:)];
        for (NSString *path in all) {
            if (progress.cancelled) { if (error) *error = QRError(@"已取消"); return nil; }
            if ([seen containsObject:path]) continue;
            [seen addObject:path];
            NSDictionary *a = [fm attributesOfItemAtPath:path error:error];
            if (!a) return nil;
            BOOL directory = [a[NSFileType] isEqualToString:NSFileTypeDirectory];
            NSString *kind = directory ? @"文件夹" : ([a[NSFileType] isEqualToString:NSFileTypeSymbolicLink] ? @"符号链接" : @"文件");
            NSString *relative = [path substringFromIndex:root.stringByDeletingLastPathComponent.length + ([root.stringByDeletingLastPathComponent isEqualToString:@"/"] ? 0 : 1)];
            if ([format isEqualToString:@"tree"]) {
                NSUInteger depth = path.pathComponents.count - root.pathComponents.count;
                [output appendFormat:@"%@%@%@\n", [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0], QREscapeCell(path.lastPathComponent, format), directory ? @"/" : @""];
            } else {
                NSArray *cells = @[relative, kind, directory ? @"" : [a[NSFileSize] stringValue] ?: @"", a[NSFileModificationDate] ? [date stringFromDate:a[NSFileModificationDate]] : @""];
                NSMutableArray *escaped = [NSMutableArray array];
                for (NSString *cell in cells) [escaped addObject:QREscapeCell(cell, format)];
                [output appendFormat:[format isEqualToString:@"csv"] ? @"%@\r\n" : @"| %@ |\n", [escaped componentsJoinedByString:[format isEqualToString:@"csv"] ? @"," : @" | "]];
            }
        }
    }
    return output;
}
