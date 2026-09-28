#import <Foundation/Foundation.h>

NSError *QRError(NSString *message);
BOOL QRValidFilename(NSString *name);
BOOL QRPathExists(NSString *path);
NSURL *QRUniqueURL(NSURL *directory, NSString *filename);
BOOL QRWriteNewData(NSData *data, NSURL *url, NSError **error);
NSArray<NSDictionary *> *QRRenamePlan(NSArray<NSString *> *paths, NSDictionary *options, NSError **error);
NSDictionary *QRMoveFile(NSString *source, NSString *target, NSError **error);
BOOL QRUndoMove(NSDictionary *record, NSError **error);
NSURL *QRCreateProject(NSURL *directory, NSString *name, NSError **error);
NSURL *QRCopyTemplate(NSURL *source, NSURL *directory, NSString *name, NSError **error);
NSURL *QRProcessImage(NSURL *source, NSURL *directory, NSDictionary *options, NSProgress *progress, NSError **error);
NSURL *QRCreatePDF(NSArray<NSString *> *paths, NSURL *directory, NSString *name, BOOL images, NSProgress *progress, NSError **error);
NSString *QRRecognizeText(NSURL *source, NSError **error);
NSString *QRFileManifest(NSArray<NSString *> *paths, NSString *format, NSProgress *progress, NSError **error);
