#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Shared by the settings UI and Finder extension. Keep keys stable for existing settings.
static inline NSArray<NSDictionary *> *QRFeatureRows(void) {
    return @[
        @{@"key": @"newTxt", @"title": @"新建 TXT", @"category": @"新建文件", @"action": @"txt", @"symbol": @"doc.plaintext", @"context": @"any", @"tag": @(42001)},
        @{@"key": @"newMarkdown", @"title": @"新建 Markdown", @"category": @"新建文件", @"action": @"md", @"symbol": @"doc.text", @"context": @"any", @"tag": @(42002)},
        @{@"key": @"newJson", @"title": @"新建 JSON", @"category": @"新建文件", @"action": @"json", @"symbol": @"curlybraces", @"context": @"any", @"tag": @(42003)},
        @{@"key": @"newCsv", @"title": @"新建 CSV", @"category": @"新建文件", @"action": @"csv", @"symbol": @"tablecells", @"context": @"any", @"tag": @(42004)},
        @{@"key": @"newHtml", @"title": @"新建 HTML", @"category": @"新建文件", @"action": @"html", @"symbol": @"chevron.left.forwardslash.chevron.right", @"context": @"any", @"tag": @(42005)},
        @{@"key": @"newYaml", @"title": @"新建 YAML", @"category": @"新建文件", @"action": @"yaml", @"symbol": @"doc.text", @"context": @"any", @"tag": @(42006)},
        @{@"key": @"newXml", @"title": @"新建 XML", @"category": @"新建文件", @"action": @"xml", @"symbol": @"chevron.left.forwardslash.chevron.right", @"context": @"any", @"tag": @(42007)},
        @{@"key": @"newShell", @"title": @"新建 Shell", @"category": @"新建文件", @"action": @"sh", @"symbol": @"terminal", @"context": @"any", @"tag": @(42008)},
        @{@"key": @"newPython", @"title": @"新建 Python", @"category": @"新建文件", @"action": @"py", @"symbol": @"chevron.left.forwardslash.chevron.right", @"context": @"any", @"tag": @(42009)},
        @{@"key": @"newJavaScript", @"title": @"新建 JavaScript", @"category": @"新建文件", @"action": @"js", @"symbol": @"curlybraces", @"context": @"any", @"tag": @(42010)},
        @{@"key": @"newTypeScript", @"title": @"新建 TypeScript", @"category": @"新建文件", @"action": @"ts", @"symbol": @"curlybraces", @"context": @"any", @"tag": @(42011)},
        @{@"key": @"newCss", @"title": @"新建 CSS", @"category": @"新建文件", @"action": @"css", @"symbol": @"paintbrush", @"context": @"any", @"tag": @(42012)},
        @{@"key": @"newWord", @"title": @"新建 Word", @"category": @"新建文件", @"action": @"docx", @"symbol": @"doc.richtext", @"context": @"any", @"tag": @(42013)},
        @{@"key": @"newExcel", @"title": @"新建 Excel", @"category": @"新建文件", @"action": @"xlsx", @"symbol": @"tablecells", @"context": @"any", @"tag": @(42014)},
        @{@"key": @"newPowerPoint", @"title": @"新建 PowerPoint", @"category": @"新建文件", @"action": @"pptx", @"symbol": @"rectangle.on.rectangle", @"context": @"any", @"tag": @(42015)},
        @{@"key": @"copyPath", @"title": @"复制路径", @"category": @"复制", @"action": @"copy-path", @"symbol": @"doc.on.clipboard", @"context": @"any", @"tag": @(42016)},
        @{@"key": @"copyName", @"title": @"复制文件名", @"category": @"复制", @"action": @"copy-name", @"symbol": @"textformat", @"context": @"any", @"tag": @(42017)},
        @{@"key": @"copyParent", @"title": @"复制父目录", @"category": @"复制", @"action": @"copy-parent", @"symbol": @"folder", @"context": @"any", @"tag": @(42018)},
        @{@"key": @"copyFileURL", @"title": @"复制 file URL", @"category": @"复制", @"action": @"copy-file-url", @"symbol": @"link", @"context": @"any", @"tag": @(42019)},
        @{@"key": @"copyMarkdownLink", @"title": @"复制 Markdown 链接", @"category": @"复制", @"action": @"copy-markdown-link", @"symbol": @"link.badge.plus", @"context": @"any", @"tag": @(42020)},
        @{@"key": @"copyToDesktop", @"title": @"复制到桌面", @"category": @"复制到", @"action": @"copy-to-desktop", @"symbol": @"folder", @"context": @"selection", @"tag": @(42021)},
        @{@"key": @"copyToDocuments", @"title": @"复制到文稿", @"category": @"复制到", @"action": @"copy-to-documents", @"symbol": @"folder", @"context": @"selection", @"tag": @(42022)},
        @{@"key": @"copyToDownloads", @"title": @"复制到下载", @"category": @"复制到", @"action": @"copy-to-downloads", @"symbol": @"folder", @"context": @"selection", @"tag": @(42023)},
        @{@"key": @"copyToPictures", @"title": @"复制到图片", @"category": @"复制到", @"action": @"copy-to-pictures", @"symbol": @"folder", @"context": @"selection", @"tag": @(42024)},
        @{@"key": @"copyToMovies", @"title": @"复制到影片", @"category": @"复制到", @"action": @"copy-to-movies", @"symbol": @"folder", @"context": @"selection", @"tag": @(42025)},
        @{@"key": @"copyToMusic", @"title": @"复制到音乐", @"category": @"复制到", @"action": @"copy-to-music", @"symbol": @"folder", @"context": @"selection", @"tag": @(42026)},
        @{@"key": @"copyToChoose", @"title": @"复制到选择文件夹", @"category": @"复制到", @"action": @"copy-to-choose", @"symbol": @"folder.badge.plus", @"context": @"selection", @"tag": @(42027)},
        @{@"key": @"moveToDesktop", @"title": @"移动到桌面", @"category": @"移动到", @"action": @"move-to-desktop", @"symbol": @"folder", @"context": @"selection", @"tag": @(42028)},
        @{@"key": @"moveToDocuments", @"title": @"移动到文稿", @"category": @"移动到", @"action": @"move-to-documents", @"symbol": @"folder", @"context": @"selection", @"tag": @(42029)},
        @{@"key": @"moveToDownloads", @"title": @"移动到下载", @"category": @"移动到", @"action": @"move-to-downloads", @"symbol": @"folder", @"context": @"selection", @"tag": @(42030)},
        @{@"key": @"moveToPictures", @"title": @"移动到图片", @"category": @"移动到", @"action": @"move-to-pictures", @"symbol": @"folder", @"context": @"selection", @"tag": @(42031)},
        @{@"key": @"moveToMovies", @"title": @"移动到影片", @"category": @"移动到", @"action": @"move-to-movies", @"symbol": @"folder", @"context": @"selection", @"tag": @(42032)},
        @{@"key": @"moveToMusic", @"title": @"移动到音乐", @"category": @"移动到", @"action": @"move-to-music", @"symbol": @"folder", @"context": @"selection", @"tag": @(42033)},
        @{@"key": @"moveToChoose", @"title": @"移动到选择文件夹", @"category": @"移动到", @"action": @"move-to-choose", @"symbol": @"folder.badge.plus", @"context": @"selection", @"tag": @(42034)},
        @{@"key": @"batchRename", @"title": @"批量重命名", @"category": @"文件操作", @"action": @"batch-rename", @"symbol": @"text.cursor", @"context": @"selection", @"tag": @(42035)},
        @{@"key": @"copyImageSize", @"title": @"复制图片尺寸", @"category": @"图片工具", @"action": @"image-copy-size", @"symbol": @"ruler", @"context": @"image", @"tag": @(42036)},
        @{@"key": @"compressImage", @"title": @"压缩图片", @"category": @"图片工具", @"action": @"image-compress", @"symbol": @"arrow.down.right.and.arrow.up.left", @"context": @"image", @"tag": @(42037)},
        @{@"key": @"convertPng", @"title": @"转换为 PNG", @"category": @"图片工具", @"action": @"image-convert-png", @"symbol": @"photo", @"context": @"image", @"tag": @(42038)},
        @{@"key": @"convertJpeg", @"title": @"转换为 JPEG", @"category": @"图片工具", @"action": @"image-convert-jpeg", @"symbol": @"photo", @"context": @"image", @"tag": @(42039)},
        @{@"key": @"convertWebp", @"title": @"转换为 WebP", @"category": @"图片工具", @"action": @"image-convert-webp", @"symbol": @"photo", @"context": @"image", @"tag": @(42040)},
        @{@"key": @"textStats", @"title": @"统计字数", @"category": @"文本工具", @"action": @"text-stats", @"symbol": @"number", @"context": @"text", @"tag": @(42041)},
        @{@"key": @"textToUtf8", @"title": @"转 UTF-8", @"category": @"文本工具", @"action": @"text-to-utf8", @"symbol": @"character.cursor.ibeam", @"context": @"text", @"tag": @(42042)},
        @{@"key": @"textPreview", @"title": @"快速预览纯文本", @"category": @"文本工具", @"action": @"text-preview", @"symbol": @"eye", @"context": @"text", @"tag": @(42043)},
        @{@"key": @"terminal", @"title": @"在终端打开", @"category": @"打开方式", @"action": @"terminal", @"symbol": @"terminal", @"context": @"any", @"tag": @(42044)},
        @{@"key": @"clipboardTxt", @"title": @"剪贴板保存为 TXT", @"category": @"新建文件", @"action": @"clipboard-txt", @"symbol": @"doc.on.clipboard", @"context": @"any", @"tag": @(42045)},
        @{@"key": @"clipboardMarkdown", @"title": @"剪贴板保存为 Markdown", @"category": @"新建文件", @"action": @"clipboard-md", @"symbol": @"doc.on.clipboard", @"context": @"any", @"tag": @(42046)},
        @{@"key": @"clipboardImage", @"title": @"剪贴板保存为 PNG", @"category": @"新建文件", @"action": @"clipboard-png", @"symbol": @"photo", @"context": @"any", @"tag": @(42047)},
        @{@"key": @"newProject", @"title": @"新建项目文件夹…", @"category": @"新建文件", @"action": @"project-create", @"symbol": @"folder.badge.plus", @"context": @"any", @"tag": @(42048)},
        @{@"key": @"importedTemplate", @"title": @"从导入模板新建…", @"category": @"新建文件", @"action": @"template-create", @"symbol": @"doc.badge.plus", @"context": @"any", @"tag": @(42049)},
        @{@"key": @"openVSCode", @"title": @"用 VS Code 打开", @"category": @"打开方式", @"action": @"open-vscode", @"symbol": @"chevron.left.forwardslash.chevron.right", @"context": @"any", @"tag": @(42050)},
        @{@"key": @"openCursor", @"title": @"用 Cursor 打开", @"category": @"打开方式", @"action": @"open-cursor", @"symbol": @"chevron.left.forwardslash.chevron.right", @"context": @"any", @"tag": @(42051)},
        @{@"key": @"openPreferred", @"title": @"用常用应用打开", @"category": @"打开方式", @"action": @"open-preferred", @"symbol": @"doc", @"context": @"any", @"tag": @(42052)},
        @{@"key": @"openChoose", @"title": @"选择应用打开…", @"category": @"打开方式", @"action": @"open-choose", @"symbol": @"doc", @"context": @"any", @"tag": @(42053)},
        @{@"key": @"resizeImage", @"title": @"最长边 1920 px（另存 PNG）", @"category": @"图片工具", @"action": @"image-resize", @"symbol": @"photo", @"context": @"image", @"tag": @(42054)},
        @{@"key": @"targetImageSize", @"title": @"图片压到 1 MB 以内", @"category": @"图片工具", @"action": @"image-target-size", @"symbol": @"photo", @"context": @"image", @"tag": @(42055)},
        @{@"key": @"stripImageMetadata", @"title": @"去除图片元数据（另存 PNG）", @"category": @"图片工具", @"action": @"image-strip-metadata", @"symbol": @"photo", @"context": @"image", @"tag": @(42056)},
        @{@"key": @"watermarkImage", @"title": @"添加文字水印…", @"category": @"图片工具", @"action": @"image-watermark", @"symbol": @"photo", @"context": @"image", @"tag": @(42057)},
        @{@"key": @"imageWorkflow", @"title": @"运行图片处理组合…", @"category": @"图片工具", @"action": @"workflow-run", @"symbol": @"photo", @"context": @"image", @"tag": @(42058)},
        @{@"key": @"imagesPDF", @"title": @"图片合成 PDF…", @"category": @"PDF 与识别", @"action": @"pdf-images", @"symbol": @"doc.richtext", @"context": @"image", @"tag": @(42059)},
        @{@"key": @"mergePDF", @"title": @"合并 PDF…", @"category": @"PDF 与识别", @"action": @"pdf-merge", @"symbol": @"doc.richtext", @"context": @"pdf", @"tag": @(42060)},
        @{@"key": @"imageOCR", @"title": @"识别图片文字并复制", @"category": @"PDF 与识别", @"action": @"image-ocr", @"symbol": @"textformat", @"context": @"image", @"tag": @(42061)},
        @{@"key": @"copyTree", @"title": @"复制目录树", @"category": @"文件清单", @"action": @"manifest-tree", @"symbol": @"folder", @"context": @"any", @"tag": @(42062)},
        @{@"key": @"manifestMarkdown", @"title": @"导出 Markdown 清单", @"category": @"文件清单", @"action": @"manifest-md", @"symbol": @"doc.text", @"context": @"any", @"tag": @(42063)},
        @{@"key": @"manifestCSV", @"title": @"导出 CSV 清单", @"category": @"文件清单", @"action": @"manifest-csv", @"symbol": @"tablecells", @"context": @"any", @"tag": @(42064)},
        @{@"key": @"undoLast", @"title": @"撤销上次移动或重命名…", @"category": @"文件操作", @"action": @"undo-last", @"symbol": @"arrow.uturn.backward", @"context": @"any", @"tag": @(42065)},
    ];
}

static inline NSArray<NSDictionary *> *QROrderedFeatures(NSDictionary *settings) {
    NSArray *order = [settings[@"menuOrder"] isKindOfClass:NSArray.class] ? settings[@"menuOrder"] : @[];
    return [QRFeatureRows() sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSUInteger x = [order indexOfObject:a[@"key"]], y = [order indexOfObject:b[@"key"]];
        if (x == y) return [a[@"tag"] compare:b[@"tag"]];
        return x < y ? NSOrderedAscending : NSOrderedDescending;
    }];
}

static inline BOOL QRFeatureMatches(NSDictionary *row, NSArray<NSURL *> *urls, BOOL contextual) {
    NSString *context = row[@"context"];
    if ([context isEqualToString:@"any"]) return YES;
    if (urls.count == 0) return NO;
    if ([context isEqualToString:@"selection"] || !contextual) return YES;
    for (NSURL *url in urls) {
        NSNumber *directory = nil;
        [url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:NULL];
        if (directory.boolValue) return NO;
        UTType *type = [UTType typeWithFilenameExtension:url.pathExtension];
        if ([context isEqualToString:@"image"] && ![type conformsToType:UTTypeImage]) return NO;
        if ([context isEqualToString:@"pdf"] && ![type conformsToType:UTTypePDF]) return NO;
        if ([context isEqualToString:@"text"]) {
            NSArray *extra = @[@"md", @"json", @"csv", @"yaml", @"yml", @"xml", @"sh", @"py", @"js", @"ts", @"css", @"log", @"gitignore", @"env"];
            if (![type conformsToType:UTTypeText] && ![extra containsObject:url.pathExtension.lowercaseString] &&
                ![extra containsObject:[url.lastPathComponent stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]]]) return NO;
        }
    }
    return YES;
}

static inline NSArray<NSString *> *QRPathsFromString(NSString *value) {
    if (![value isKindOfClass:NSString.class] || !value.length) return @[];
    id decoded = [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    NSArray *items = [decoded isKindOfClass:NSArray.class] ? decoded : [value componentsSeparatedByString:@"\n"];
    NSMutableOrderedSet *paths = [NSMutableOrderedSet orderedSet];
    for (id path in items) {
        if (![path isKindOfClass:NSString.class] || ![path isAbsolutePath] || [path rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound) return @[];
        [paths addObject:[path stringByStandardizingPath]];
    }
    return paths.array;
}
