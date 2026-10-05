// Document bytes remain private and retained until their send receipt arrives.
#define IOS_FILE_LIMIT (20u << 20)
static NSString* ios_file_draft_key = @"bend-file-draft";

static BOOL ios_file_name(NSString* name) {
  if (![name isKindOfClass:NSString.class] || !name.length || name.length > 255 ||
      [@[@".", @".."] containsObject:name]) return NO;
  NSMutableCharacterSet* forbidden = [[NSCharacterSet characterSetWithRange:NSMakeRange(0, 32)] mutableCopy];
  [forbidden addCharactersInRange:NSMakeRange(127, 1)];
  [forbidden addCharactersInString:@"/\\"];
  return [name rangeOfCharacterFromSet:forbidden].location == NSNotFound;
}

static BOOL ios_file_metadata(NSDictionary* value) {
  return [value isKindOfClass:NSDictionary.class] && ios_clip_id(value[@"fileId"]) &&
    ios_file_name(value[@"name"]) && [value[@"mimeType"] isKindOfClass:NSString.class] &&
    [value[@"caption"] isKindOfClass:NSString.class] &&
    [value[@"size"] isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)value[@"size"]) != CFBooleanGetTypeID() &&
    [value[@"size"] doubleValue] >= 0 && [value[@"size"] doubleValue] <= IOS_FILE_LIMIT &&
    floor([value[@"size"] doubleValue]) == [value[@"size"] doubleValue];
}

static NSURL* ios_file_url(NSString* identifier, NSString* name) {
  if ((!ios_clip_id(identifier) && !ios_image_hash(identifier)) || !ios_file_name(name)) return nil;
  NSURL* directory = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  directory = ios_scoped_directory(directory);
  directory = [[directory URLByAppendingPathComponent:@"BendFiles" isDirectory:YES] URLByAppendingPathComponent:identifier isDirectory:YES];
  if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
      attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:NULL]) return nil;
  return [directory URLByAppendingPathComponent:name isDirectory:NO];
}

static NSData* ios_file_bytes(NSURL* url) {
  NSNumber *regular = nil, *size = nil;
  [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:NULL];
  [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
  if (!regular.boolValue || !size || size.unsignedLongLongValue > IOS_FILE_LIMIT) return nil;
  NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL:url error:NULL];
  NSError* error = nil;
  NSData* bytes = [handle readDataUpToLength:IOS_FILE_LIMIT + 1 error:&error];
  [handle closeAndReturnError:NULL];
  return bytes && !error && bytes.length == size.unsignedLongLongValue && bytes.length <= IOS_FILE_LIMIT ? bytes : nil;
}

static BOOL ios_file_save(NSDictionary* metadata) {
  if (!ios_file_metadata(metadata)) return NO;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    [defaults setObject:metadata forKey:ios_file_draft_key];
    return [defaults synchronize] && [[defaults dictionaryForKey:ios_file_draft_key] isEqual:metadata];
  }
}

static void ios_file_acknowledged(NSDictionary* pending) {
  if (![pending[@"kind"] isEqual:@"file"]) return;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  if ([[defaults dictionaryForKey:ios_file_draft_key][@"fileId"] isEqual:pending[@"fileId"]])
    [defaults removeObjectForKey:ios_file_draft_key];
}

static UIViewController* ios_file_presenter(void) {
  for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) if ([scene isKindOfClass:UIWindowScene.class])
    for (UIWindow* window in ((UIWindowScene*)scene).windows) if (window.isKeyWindow) return window.rootViewController;
  return nil;
}

static BOOL ios_file_hash_matches(NSData* bytes, NSString* identifier) {
  if (!bytes || bytes.length > IOS_FILE_LIMIT || !ios_image_hash(identifier)) return NO;
  unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
  NSMutableString* actual = [NSMutableString stringWithCapacity:64];
  for (unsigned index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) [actual appendFormat:@"%02x", digest[index]];
  return [actual isEqual:identifier];
}

@interface BendIOSFile : NSObject <UIDocumentPickerDelegate, UIDocumentInteractionControllerDelegate>
@property(copy) NSString* session;
@property(copy) NSString* caption;
@property(strong) UIDocumentPickerViewController* picker;
@property(strong) UIDocumentInteractionController* preview;
@property NSUInteger generation;
@property BOOL loading;
@property BOOL selecting;
- (NSString*)command:(NSDictionary*)command;
- (void)background;
@end
static BendIOSFile* ios_file;

@implementation BendIOSFile
- (void)emit:(NSString*)phase metadata:(NSDictionary*)metadata {
  NSMutableDictionary* value = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
  value[@"phase"] = phase; value[@"session"] = self.session ?: @"";
  ios_action(@{@"action":@"file", @"data":value});
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
  if (controller != self.picker) return;
  ++self.generation; self.picker = nil; self.selecting = NO;
  [self emit:@"cancelled" metadata:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
  if (controller != self.picker) return;
  self.picker = nil;
  NSURL* selected = urls.firstObject;
  if (!selected) { self.selecting = NO; [self emit:@"cancelled" metadata:nil]; return; }
  NSUInteger generation = ++self.generation; self.loading = YES;
  [self emit:@"loading" metadata:nil];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    BOOL scoped = [selected startAccessingSecurityScopedResource];
    __block NSData* bytes = nil; __block NSString* name = nil; __block NSString* mime = nil;
    NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    [coordinator coordinateReadingItemAtURL:selected options:0 error:NULL byAccessor:^(NSURL* url) {
      name = url.lastPathComponent;
      if (ios_file_name(name)) bytes = ios_file_bytes(url);
      UTType* type = nil; [url getResourceValue:&type forKey:NSURLContentTypeKey error:NULL];
      mime = type.preferredMIMEType ?: @"application/octet-stream";
    }];
    if (scoped) [selected stopAccessingSecurityScopedResource];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation) return;
      self.loading = NO; self.selecting = NO;
      if (!bytes || !ios_file_name(name)) {
        [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Choose a file of at most 20 MiB with a valid filename.", @"Elige un archivo de hasta 20 MiB con un nombre válido.")}]; return;
      }
      NSString* identifier = NSUUID.UUID.UUIDString;
      NSURL* retained = ios_file_url(identifier, name);
      NSDictionary* metadata = @{@"fileId":identifier, @"name":name, @"mimeType":mime, @"size":@(bytes.length), @"caption":self.caption ?: @""};
      if (!retained || ![bytes writeToURL:retained options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL] || !ios_file_save(metadata)) {
        if (retained) [NSFileManager.defaultManager removeItemAtURL:retained error:NULL];
        [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Could not retain this file. Try choosing it again.", @"No se pudo guardar este archivo. Vuelve a seleccionarlo.")}]; return;
      }
      [self emit:@"selected" metadata:metadata];
    });
  });
}
- (UIViewController*)documentInteractionControllerViewControllerForPreview:(UIDocumentInteractionController*)controller {
  return ios_file_presenter();
}
- (void)documentInteractionControllerDidEndPreview:(UIDocumentInteractionController*)controller {
  if (controller == self.preview) self.preview = nil;
}
- (NSString*)command:(NSDictionary*)command {
  NSString* action = command[@"action"], *session = command[@"session"];
  if (![action isKindOfClass:NSString.class] || ![session isKindOfClass:NSString.class] || !session.length || session.length > 128) return @"file commands require an action and session";
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  if ([action isEqual:@"pick"]) {
    NSString* caption = command[@"caption"] ?: @"";
    if (![caption isKindOfClass:NSString.class] || [caption lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 131072) return @"invalid file caption";
    if ([defaults dictionaryForKey:ios_pending_key] || [defaults dictionaryForKey:ios_file_draft_key] || [defaults dictionaryForKey:ios_image_draft_key])
      return ios_audio_words(@"Send or remove the current attachment first.", @"Envía o elimina el archivo adjunto actual primero.");
    UIViewController* presenter = ios_file_presenter();
    if (self.picker || self.loading || !presenter.view.window || presenter.presentedViewController)
      return ios_audio_words(@"The file picker is not available yet.", @"El selector de archivos aún no está disponible.");
    self.session = session; self.caption = caption; self.selecting = YES;
    self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem] asCopy:YES];
    self.picker.delegate = self; self.picker.allowsMultipleSelection = NO;
    [presenter.view endEditing:YES]; [presenter presentViewController:self.picker animated:YES completion:nil];
    [self emit:@"picking" metadata:nil]; return nil;
  }
  if ([action isEqual:@"open"]) {
    NSString* identifier = command[@"fileId"], *href = command[@"url"], *name = command[@"name"];
    if (!ios_image_hash(identifier) || ![href isKindOfClass:NSString.class] || !ios_file_name(name) ||
        ![command[@"size"] isKindOfClass:NSNumber.class] || [command[@"size"] unsignedLongLongValue] > IOS_FILE_LIMIT) return @"invalid file preview metadata";
    NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
    if (!ios_same_origin(url) || ![url.path isEqual:[@"/api/file/" stringByAppendingString:identifier]] || url.query.length || url.fragment.length) return @"file preview requires its canonical same-origin URL";
    if (self.loading || self.preview || ios_file_presenter().presentedViewController) return ios_audio_words(@"A file is already open.", @"Ya hay un archivo abierto.");
    self.session = session; self.loading = YES; NSUInteger generation = ++self.generation;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSURL* retained = ios_file_url(identifier, name);
      NSData* bytes = ios_file_bytes(retained);
      if (!ios_file_hash_matches(bytes, identifier)) {
        BendIOSFetch* stream = [BendIOSFetch new]; stream.limit = IOS_FILE_LIMIT;
        NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30; config.waitsForConnectivity = NO;
        NSURLSession* download = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:nil];
        [[download dataTaskWithURL:url] resume];
        BOOL timedOut = dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC)) != 0;
        if (timedOut) [download invalidateAndCancel]; else [download finishTasksAndInvalidate];
        NSInteger code = [stream->response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse*)stream->response).statusCode : 0;
        bytes = !timedOut && !stream->error && !stream->oversized && code >= 200 && code <= 299 ? stream->body : nil;
      }
      BOOL valid = bytes.length == [command[@"size"] unsignedLongLongValue] && ios_file_hash_matches(bytes, identifier);
      BOOL saved = valid && [bytes writeToURL:retained options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self.generation) return;
        self.loading = NO;
        if (saved && ios_file_presenter().view.window && !ios_file_presenter().presentedViewController) {
          self.preview = [UIDocumentInteractionController interactionControllerWithURL:retained]; self.preview.delegate = self;
          if ([self.preview presentPreviewAnimated:YES]) return;
          self.preview = nil;
        }
        [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Could not preview this file.", @"No se pudo abrir este archivo.")}];
      });
    }); return nil;
  }
  if (![session isEqual:self.session]) return @"file session is no longer active";
  if (![action isEqual:@"cancel"]) return @"unsupported file action";
  NSDictionary* draft = [defaults dictionaryForKey:ios_file_draft_key];
  if (draft[@"fileId"] && [[defaults dictionaryForKey:ios_pending_key][@"fileId"] isEqual:draft[@"fileId"]])
    return ios_audio_words(@"This file is awaiting its send receipt.", @"Este archivo está esperando su confirmación de envío.");
  ++self.generation; self.loading = NO; self.selecting = NO;
  [self.picker dismissViewControllerAnimated:YES completion:nil]; self.picker = nil;
  if (ios_file_metadata(draft)) [NSFileManager.defaultManager removeItemAtURL:ios_file_url(draft[@"fileId"], draft[@"name"]) error:NULL];
  [defaults removeObjectForKey:ios_file_draft_key]; [defaults synchronize];
  [self emit:@"cancelled" metadata:nil]; return nil;
}
- (void)background {
  if (!self.picker && !self.loading) return;
  BOOL selecting = self.selecting;
  ++self.generation; self.loading = NO; self.selecting = NO;
  [self.picker dismissViewControllerAnimated:NO completion:nil]; self.picker = nil;
  if (selecting) [self emit:@"cancelled" metadata:nil];
}
@end

static void ios_file_edited(NSString* name, NSString* value) {
  if (![@[@"textbox · Message", @"textbox · Mensaje"] containsObject:name ?: @""] || ![value isKindOfClass:NSString.class]) return;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    NSDictionary* draft = [defaults dictionaryForKey:ios_file_draft_key];
    if (draft[@"requestId"]) return;
    if (ios_file.picker || ios_file.loading) ios_file.caption = value;
    if (ios_file_metadata(draft)) { NSMutableDictionary* updated = [draft mutableCopy]; updated[@"caption"] = value; ios_file_save(updated); }
  }
}

static void ios_file_restore(void) {
  NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_file_draft_key];
  if (!ios_file_metadata(draft)) return;
  if (!ios_file) ios_file = [BendIOSFile new]; ios_file.session = ios_session_prefix;
  NSData* bytes = ios_file_bytes(ios_file_url(draft[@"fileId"], draft[@"name"]));
  if (!bytes || bytes.length != [draft[@"size"] unsignedLongLongValue]) {
    [ios_file emit:@"error" metadata:@{@"error":ios_audio_words(@"The saved attachment is missing. Its send receipt has been kept.", @"No se encuentra el archivo guardado. Su confirmación de envío se conservó.")}]; return;
  }
  NSMutableDictionary* restored = [draft mutableCopy]; restored[@"restored"] = @YES;
  [ios_file emit:@"selected" metadata:restored];
}

static char* ios_file_request(NSString* text, unsigned* status) {
  id command = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if (![command isKindOfClass:NSDictionary.class]) { *status = 2; return ios_dup(@"file command must be JSON"); }
  __block NSString* problem = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{ if (!ios_file) ios_file = [BendIOSFile new]; problem = [ios_file command:command]; });
  *status = problem ? 2 : 1; return ios_dup(problem ?: @"");
}

static char* ios_file_upload(NSString* text, unsigned* status) {
  *status = 2;
  id envelope = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  NSDictionary* payload = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"body"] : nil;
  NSString* href = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"url"] : nil;
  if (![payload isKindOfClass:NSDictionary.class] || ![href isKindOfClass:NSString.class] ||
      ![payload[@"requestId"] isKindOfClass:NSString.class] || ![payload[@"requestId"] length] ||
      ![payload[@"threadId"] isKindOfClass:NSString.class] || ![payload[@"threadId"] length] ||
      ![payload[@"text"] isKindOfClass:NSString.class] || !ios_clip_id(payload[@"fileId"])) return ios_dup(@"invalid file upload metadata");
  NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(url) || ![url.path isEqual:@"/api/file"] || url.query.length || url.fragment.length) return ios_dup(@"file upload requires the configured /api/file endpoint");
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  NSDictionary* draft = [defaults dictionaryForKey:ios_file_draft_key];
  if (!ios_file_metadata(draft) || ![draft[@"fileId"] isEqual:payload[@"fileId"]]) return ios_dup(@"selected file no longer matches");
  NSData* bytes = ios_file_bytes(ios_file_url(draft[@"fileId"], draft[@"name"]));
  NSMutableDictionary* wire = [payload mutableCopy]; wire[@"name"] = draft[@"name"];
  NSData* metadata = [NSJSONSerialization dataWithJSONObject:wire options:NSJSONWritingSortedKeys error:NULL];
  if (!bytes || bytes.length != [draft[@"size"] unsignedLongLongValue] || !metadata || metadata.length > 131072) return ios_dup(@"file is missing or invalid");
  NSMutableDictionary* marker = [payload mutableCopy]; marker[@"kind"] = @"file";
  @synchronized(defaults) {
    NSDictionary* pending = [defaults dictionaryForKey:ios_pending_key];
    if (pending && ![pending isEqual:marker]) return ios_dup(@"another send is still awaiting its receipt");
    if (draft[@"requestId"] && (![draft[@"requestId"] isEqual:payload[@"requestId"]] || ![draft[@"caption"] isEqual:payload[@"text"]])) return ios_dup(@"file retry must preserve its original caption and request identifier");
    NSMutableDictionary* remembered = [draft mutableCopy]; remembered[@"requestId"] = payload[@"requestId"]; remembered[@"threadId"] = payload[@"threadId"]; remembered[@"caption"] = payload[@"text"];
    if (!ios_file_save(remembered)) return ios_dup(@"could not save file retry metadata");
    [defaults setObject:marker forKey:ios_pending_key];
    if (![defaults synchronize] || ![[defaults dictionaryForKey:ios_pending_key] isEqual:marker]) return ios_dup(@"could not save file send receipt metadata");
  }
  NSString* boundary = [@"BendFile-" stringByAppendingString:NSUUID.UUID.UUIDString];
  NSString* filename = [draft[@"name"] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]];
  NSString* mime = draft[@"mimeType"];
  if ([mime rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/!#$&^_.+-"].invertedSet].location != NSNotFound || ![mime containsString:@"/"]) mime = @"application/octet-stream";
  NSMutableData* multipart = [NSMutableData data];
  [multipart appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [multipart appendData:metadata];
  [multipart appendData:[[NSString stringWithFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: %@\r\n\r\n", boundary, filename, mime] dataUsingEncoding:NSUTF8StringEncoding]];
  [multipart appendData:bytes]; [multipart appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  request.HTTPMethod = @"POST"; request.HTTPBody = multipart;
  [request setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
  NSURLComponents* origin = [NSURLComponents componentsWithURL:ios_origin resolvingAgainstBaseURL:YES]; origin.path = @""; origin.query = nil; origin.fragment = nil;
  [request setValue:origin.string forHTTPHeaderField:@"Origin"];
  BendIOSFetch* stream = [BendIOSFetch new];
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30; config.waitsForConnectivity = NO;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:nil];
  [[session dataTaskWithRequest:request] resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [session invalidateAndCancel]; *status = 3; return ios_dup(@"file upload timeout");
  }
  [session finishTasksAndInvalidate];
  if (stream->oversized) return ios_dup(@"file reply exceeds 1 MiB");
  if (stream->error) return ios_dup(stream->error.localizedDescription);
  NSInteger code = [stream->response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse*)stream->response).statusCode : 0;
  id decoded = [NSJSONSerialization JSONObjectWithData:stream->body options:0 error:NULL];
  if (code < 200 || code > 299) {
    NSString* problem = [decoded isKindOfClass:NSDictionary.class] && [decoded[@"error"] isKindOfClass:NSString.class] ? decoded[@"error"] : nil;
    return ios_dup(problem ?: [NSString stringWithFormat:@"HTTP %ld", (long)code]);
  }
  NSArray* receipts = [decoded isKindOfClass:NSDictionary.class] && [decoded[@"acceptedRequestIds"] isKindOfClass:NSArray.class] ? decoded[@"acceptedRequestIds"] : nil;
  @synchronized(defaults) {
    NSDictionary* pending = [defaults dictionaryForKey:ios_pending_key];
    if (pending[@"requestId"] && [receipts containsObject:pending[@"requestId"]]) {
      ios_file_acknowledged(pending); [defaults removeObjectForKey:ios_pending_key]; [defaults synchronize];
    }
  }
  char* result = malloc(stream->body.length + 1); if (!result) abort();
  memcpy(result, stream->body.bytes, stream->body.length); result[stream->body.length] = 0;
  *status = 1; return result;
}
