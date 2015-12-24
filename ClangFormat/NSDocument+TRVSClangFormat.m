//
//  NSDocument+TRVSClangFormat.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/11/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "NSDocument+TRVSClangFormat.h"
#import <objc/runtime.h>
#import "TRVSFormatter.h"
#import "TRVSXcode.h"

static BOOL trvs_formatOnSave;

@implementation NSDocument (TRVSClangFormat)

- (void)trvs_saveDocumentWithDelegate:(id)delegate
                      didSaveSelector:(SEL)didSaveSelector
                          contextInfo:(void *)contextInfo {
  if ([self trvs_shouldFormatBeforeSaving])
    [[TRVSFormatter sharedFormatter]
        formatDocument:(IDESourceCodeDocument *)self];

  [self trvs_saveDocumentWithDelegate:delegate
                      didSaveSelector:didSaveSelector
                          contextInfo:contextInfo];
}

- (void)trvs_saveToURL:(NSURL *)url
                ofType:(NSString *)typeName
      forSaveOperation:(NSSaveOperationType)saveOperation
     completionHandler:(void (^)(NSError *))completionHandler {
  // only format on build if format on save is also enabled and the save
  // operation is NSSaveOperation an explict save.
  if ([NSDocument trvs_formatOnSave] && [self trvs_shouldFormatBeforeSaving] &&
      saveOperation == NSSaveOperation) {
    [[TRVSFormatter sharedFormatter]
        formatDocument:(IDESourceCodeDocument *)self];
  }

  [self trvs_saveToURL:url
                 ofType:typeName
       forSaveOperation:saveOperation
      completionHandler:completionHandler];
}

+ (void)load {
  Method original, swizzle;

  original = class_getInstanceMethod(
      self, NSSelectorFromString(
                @"saveDocumentWithDelegate:didSaveSelector:contextInfo:"));
  swizzle = class_getInstanceMethod(
      self, NSSelectorFromString(
                @"trvs_saveDocumentWithDelegate:didSaveSelector:contextInfo:"));

  method_exchangeImplementations(original, swizzle);

  original = class_getInstanceMethod(
      self, NSSelectorFromString(
                @"saveToURL:ofType:forSaveOperation:completionHandler:"));
  swizzle = class_getInstanceMethod(
      self, NSSelectorFromString(
                @"trvs_saveToURL:ofType:forSaveOperation:completionHandler:"));

  method_exchangeImplementations(original, swizzle);
}

+ (void)settrvs_formatOnSave:(BOOL)formatOnSave {
  trvs_formatOnSave = formatOnSave;
}

+ (BOOL)trvs_formatOnSave {
  return trvs_formatOnSave;
}

- (BOOL)trvs_shouldFormatBeforeSaving {
  return [[self class] trvs_formatOnSave] && [self trvs_shouldFormat] &&
         [TRVSXcode sourceCodeDocument] == self && [self qn_shouldFormat] &&
         [self qn_hasProjectFormatConfigFile];
}

- (BOOL)trvs_shouldFormat {
  NSURL *fileURL = [self fileURL];
  BOOL isSourceCode = [
      [NSSet setWithObjects:@"c", @"h", @"cpp", @"cc", @"hpp", @"m", @"mm", nil]
      containsObject:[[fileURL pathExtension] lowercaseString]];
  return isSourceCode;
}

- (BOOL)qn_shouldFormat {
  NSURL *fileURL = [self fileURL];
  NSArray *components = [fileURL pathComponents];
  static NSArray *blacklist;
  if (!blacklist)
    blacklist = @[ @"3rd-party", @"3rd", @"gen", @"generated" ];

  BOOL foundBlacklist = NO;

  for (NSString *name in blacklist) {
    if ([components containsObject:name]) {
      foundBlacklist = YES;
      break;
    }
  }

  return !foundBlacklist;
}

- (BOOL)qn_hasProjectFormatConfigFile {
  NSString *workspace = [[
      [TRVSXcode currentWorkspace]
          .representingFilePath pathString] stringByDeletingLastPathComponent];

  return [[NSFileManager defaultManager]
      fileExistsAtPath:[workspace
                           stringByAppendingPathComponent:@".clang-format"]];
}

@end
