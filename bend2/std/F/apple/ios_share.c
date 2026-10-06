#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#define BEND_SHARE_FILE_LIMIT (20u << 20)

@interface BendShareController : UIViewController
@property(strong) UILabel* status;
@property(strong) UIButton* close;
@property(strong) NSURL* staging;
@property(strong) NSMutableArray<NSDictionary*>* files;
@property(strong) NSArray<NSItemProvider*>* providers;
@property BOOL finished;
@end

@implementation BendShareController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.status = [UILabel new]; self.status.numberOfLines = 0;
  self.status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  self.status.adjustsFontForContentSizeCategory = YES;
  self.status.text = NSLocalizedString(@"Saving attachment…", nil);
  self.close = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.close setTitle:NSLocalizedString(@"Cancel", nil) forState:UIControlStateNormal];
  [self.close addTarget:self action:@selector(closeShare) forControlEvents:UIControlEventTouchUpInside];
  UIStackView* content = [[UIStackView alloc] initWithArrangedSubviews:@[self.status, self.close]];
  content.axis = UILayoutConstraintAxisVertical; content.spacing = 24;
  content.translatesAutoresizingMaskIntoConstraints = NO; [self.view addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
    [content.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
    [content.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
    [self.close.heightAnchor constraintGreaterThanOrEqualToConstant:44]]];
  NSString* group = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendShareGroup"];
  NSURL* root = group.length ? [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group] : nil;
  if (!root) { [self fail:NSLocalizedString(@"Shared storage is unavailable. Open the app and try again.", nil)]; return; }
  root = [root URLByAppendingPathComponent:@"BendShareInbox" isDirectory:YES];
  self.staging = [root URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".loading"] isDirectory:YES];
  if (![NSFileManager.defaultManager createDirectoryAtURL:self.staging withIntermediateDirectories:YES attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:NULL]) {
    [self fail:NSLocalizedString(@"Could not save these attachments.", nil)]; return;
  }
  NSMutableArray* providers = [NSMutableArray array];
  for (NSExtensionItem* item in self.extensionContext.inputItems) {
    if (item.attachments.count) [providers addObjectsFromArray:item.attachments];
    else if (item.attributedContentText.length) [providers addObject:[[NSItemProvider alloc] initWithObject:item.attributedContentText.string]];
  }
  if (!providers.count || providers.count > 1) { [self fail:NSLocalizedString(@"Share one attachment at a time.", nil)]; return; }
  self.providers = providers; self.files = [NSMutableArray array];
  [self loadNext];
}
- (void)closeShare {
  if (!self.finished) {
    self.finished = YES;
    if (self.staging) [NSFileManager.defaultManager removeItemAtURL:self.staging error:NULL];
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
  } else [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}
- (void)fail:(NSString*)message {
  self.finished = YES;
  if (self.staging) [NSFileManager.defaultManager removeItemAtURL:self.staging error:NULL];
  self.staging = nil; self.status.text = message;
  [self.close setTitle:NSLocalizedString(@"Close", nil) forState:UIControlStateNormal];
}
- (NSString*)typeForProvider:(NSItemProvider*)provider {
  for (UTType* preferred in @[UTTypeFileURL, UTTypeImage, UTTypeMovie, UTTypeAudio, UTTypeVCard, UTTypePDF])
    for (NSString* identifier in provider.registeredTypeIdentifiers)
      if ([[UTType typeWithIdentifier:identifier] conformsToType:preferred]) return identifier;
  for (UTType* preferred in @[UTTypeURL, UTTypePlainText, UTTypeData])
    for (NSString* identifier in provider.registeredTypeIdentifiers)
      if ([[UTType typeWithIdentifier:identifier] conformsToType:preferred]) return identifier;
  return provider.registeredTypeIdentifiers.firstObject;
}
- (NSString*)name:(NSString*)suggested type:(NSString*)identifier {
  NSString* name = suggested.lastPathComponent;
  NSCharacterSet* invalid = [NSCharacterSet controlCharacterSet];
  if (!name.length || name.length > 220 || [name rangeOfCharacterFromSet:invalid].location != NSNotFound || [@[@".", @".."] containsObject:name]) name = @"Attachment";
  NSString* extension = [UTType typeWithIdentifier:identifier].preferredFilenameExtension;
  return name.pathExtension.length || !extension.length ? name : [name stringByAppendingPathExtension:extension];
}
- (void)retainData:(NSData*)data name:(NSString*)name type:(NSString*)type {
  if (self.finished) return;
  if (!data || data.length > BEND_SHARE_FILE_LIMIT) {
    [self fail:NSLocalizedString(@"Attachments must be at most 20 MiB.", nil)]; return;
  }
  NSString* fileID = NSUUID.UUID.UUIDString;
  NSURL* destination = [self.staging URLByAppendingPathComponent:fileID];
  if (![data writeToURL:destination options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL]) {
    [self fail:NSLocalizedString(@"Could not save these attachments.", nil)]; return;
  }
  [self.files addObject:@{@"fileId":fileID, @"name":name, @"mimeType":[UTType typeWithIdentifier:type].preferredMIMEType ?: @"application/octet-stream", @"size":@(data.length)}];
  [self loadNext];
}
- (NSData*)readFile:(NSURL*)url {
  NSNumber *size = nil, *regular = nil;
  [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
  [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:NULL];
  if (!regular.boolValue || !size || size.unsignedLongLongValue > BEND_SHARE_FILE_LIMIT) return nil;
  NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL:url error:NULL];
  NSError* error = nil; NSData* bytes = [handle readDataUpToLength:BEND_SHARE_FILE_LIMIT + 1 error:&error];
  [handle closeAndReturnError:NULL];
  return !error && bytes.length == size.unsignedLongLongValue ? bytes : nil;
}
- (void)loadNext {
  if (self.finished) return;
  if (self.files.count == self.providers.count) {
    NSData* manifest = [NSJSONSerialization dataWithJSONObject:@{@"version":@1, @"files":self.files} options:0 error:NULL];
    NSURL* ready = [[self.staging URLByDeletingPathExtension] URLByAppendingPathExtension:@"ready"];
    if (![manifest writeToURL:[self.staging URLByAppendingPathComponent:@"manifest.json"] options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL] ||
        ![NSFileManager.defaultManager moveItemAtURL:self.staging toURL:ready error:NULL]) {
      [self fail:NSLocalizedString(@"Could not save these attachments.", nil)]; return;
    }
    self.finished = YES; self.staging = nil;
    NSString* name = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendContainingAppName"] ?: @"the app";
    self.status.text = [NSString stringWithFormat:NSLocalizedString(@"Saved to %@. Open it to add text or a voice note, then send.", nil), name];
    [self.close setTitle:NSLocalizedString(@"Done", nil) forState:UIControlStateNormal]; return;
  }
  NSItemProvider* provider = self.providers[self.files.count];
  NSString* type = [self typeForProvider:provider];
  if (!type.length) { [self fail:NSLocalizedString(@"This item has no shareable representation.", nil)]; return; }
  UTType* contentType = [UTType typeWithIdentifier:type];
  if ([contentType conformsToType:UTTypeURL] || [contentType conformsToType:UTTypePlainText]) {
    [provider loadItemForTypeIdentifier:type options:nil completionHandler:^(id item, NSError* error) {
      NSData* bytes = nil; NSString* name = nil; NSString* retainedType = type;
      if ([item isKindOfClass:NSURL.class] && [item isFileURL]) {
        BOOL scoped = [item startAccessingSecurityScopedResource];
        bytes = [self readFile:item]; name = [item lastPathComponent];
        retainedType = [UTType typeWithFilenameExtension:name.pathExtension].identifier ?: UTTypeData.identifier;
        if (scoped) [item stopAccessingSecurityScopedResource];
      } else {
        NSString* text = [item isKindOfClass:NSURL.class] ? [item absoluteString] : [item isKindOfClass:NSString.class] ? item : nil;
        bytes = text ? [text dataUsingEncoding:NSUTF8StringEncoding] : [item isKindOfClass:NSData.class] ? item : nil;
        name = [contentType conformsToType:UTTypeURL] ? @"Link.txt" : @"Text.txt"; retainedType = UTTypePlainText.identifier;
      }
      dispatch_async(dispatch_get_main_queue(), ^{ [self retainData:error ? nil : bytes name:name ?: @"Attachment" type:retainedType]; });
    }]; return;
  }
  [provider loadFileRepresentationForTypeIdentifier:type completionHandler:^(NSURL* url, NSError* error) {
    if (url && !error) {
      NSData* bytes = [self readFile:url]; NSString* name = [self name:provider.suggestedName ?: url.lastPathComponent type:type];
      dispatch_async(dispatch_get_main_queue(), ^{ [self retainData:bytes name:name type:type]; }); return;
    }
    [provider loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData* bytes, NSError* dataError) {
      dispatch_async(dispatch_get_main_queue(), ^{ [self retainData:dataError ? nil : bytes name:[self name:provider.suggestedName type:type] type:type]; });
    }];
  }];
}
@end
