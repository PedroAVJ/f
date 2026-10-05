// Selected photographs stay in Bend's existing composer until Send.
// PhotosUI grants access to the selected file without opening the library.
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ImageIO/ImageIO.h>
#import <CommonCrypto/CommonDigest.h>

#define IOS_IMAGE_LIMIT (5u << 20)
static NSString* const ios_image_draft_key = @"bend-image-draft";

static BOOL ios_image_hash(NSString* value) {
  if (![value isKindOfClass:NSString.class] || value.length != 64) return NO;
  return [value rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location == NSNotFound;
}

static NSURL* ios_image_file(NSString* identifier) {
  if (!ios_clip_id(identifier) && !ios_image_hash(identifier)) return nil;
  NSURL* directory = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  directory = [directory URLByAppendingPathComponent:@"BendImages" isDirectory:YES];
  if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
    attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:NULL]) return nil;
  return [directory URLByAppendingPathComponent:[identifier stringByAppendingString:@".jpg"]];
}

static NSDictionary* ios_image_dimensions(NSData* bytes) {
  if (!bytes.length || bytes.length > IOS_IMAGE_LIMIT) return nil;
  CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)bytes, NULL);
  NSDictionary* properties = source ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) : nil;
  NSNumber* width = properties[(__bridge NSString*)kCGImagePropertyPixelWidth];
  NSNumber* height = properties[(__bridge NSString*)kCGImagePropertyPixelHeight];
  BOOL valid = width.unsignedLongLongValue > 0 && height.unsignedLongLongValue > 0 &&
    width.unsignedLongLongValue <= 4096 && height.unsignedLongLongValue <= 4096;
  CGImageRef decoded = valid ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
  if (source) CFRelease(source);
  if (!decoded) return nil;
  CFRelease(decoded);
  return @{@"width":width, @"height":height};
}

// Decode with bounded dimensions, apply EXIF orientation, and retain a JPEG.
static NSData* ios_image_jpeg(NSURL* sourceURL, NSDictionary** dimensions) {
  NSNumber* size = nil; [sourceURL getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
  if (!size.unsignedLongLongValue || size.unsignedLongLongValue > (64u << 20)) return nil;
  CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)sourceURL, NULL);
  NSDictionary* properties = source ? CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL)) : nil;
  uint64_t width = [properties[(__bridge NSString*)kCGImagePropertyPixelWidth] unsignedLongLongValue];
  uint64_t height = [properties[(__bridge NSString*)kCGImagePropertyPixelHeight] unsignedLongLongValue];
  BOOL valid = width && height && width <= 65535 && height <= 65535 && width * height <= 150000000;
  CGImageRef decoded = valid ? CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@{
    (__bridge NSString*)kCGImageSourceCreateThumbnailFromImageAlways:@YES,
    (__bridge NSString*)kCGImageSourceCreateThumbnailWithTransform:@YES,
    (__bridge NSString*)kCGImageSourceThumbnailMaxPixelSize:@4096}) : NULL;
  if (source) CFRelease(source);
  if (!decoded) return nil;
  size_t w = CGImageGetWidth(decoded), h = CGImageGetHeight(decoded);
  CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
  CGContextRef canvas = CGBitmapContextCreate(NULL, w, h, 8, w * 4, color, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(color);
  if (!canvas) { CGImageRelease(decoded); return nil; }
  CGContextSetRGBFillColor(canvas, 1, 1, 1, 1); CGContextFillRect(canvas, CGRectMake(0, 0, w, h));
  CGContextDrawImage(canvas, CGRectMake(0, 0, w, h), decoded); CGImageRelease(decoded);
  CGImageRef flat = CGBitmapContextCreateImage(canvas); CGContextRelease(canvas);
  NSMutableData* bytes = nil;
  BOOL finished = NO;
  for (NSNumber* quality in @[@0.92, @0.82, @0.72, @0.60, @0.50]) {
    bytes = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)bytes,
      (__bridge CFStringRef)UTTypeJPEG.identifier, 1, NULL);
    finished = NO;
    if (destination && flat) {
      CGImageDestinationAddImage(destination, flat, (__bridge CFDictionaryRef)@{(__bridge NSString*)kCGImageDestinationLossyCompressionQuality:quality});
      finished = CGImageDestinationFinalize(destination);
    }
    if (destination) CFRelease(destination);
    if (finished && bytes.length <= IOS_IMAGE_LIMIT) break;
  }
  if (flat) CGImageRelease(flat);
  if (!finished || !bytes.length || bytes.length > IOS_IMAGE_LIMIT) return nil;
  *dimensions = @{@"width":@(w), @"height":@(h)}; return bytes;
}

static BOOL ios_image_draft(NSDictionary* metadata) {
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    [defaults setObject:metadata forKey:ios_image_draft_key];
    return [defaults synchronize] && [[defaults dictionaryForKey:ios_image_draft_key] isEqual:metadata];
  }
}

static void ios_image_acknowledged(NSDictionary* pending) {
  if (![pending[@"kind"] isEqual:@"image"] || !ios_clip_id(pending[@"imageId"])) return;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  if ([[defaults dictionaryForKey:ios_image_draft_key][@"imageId"] isEqual:pending[@"imageId"]])
    [defaults removeObjectForKey:ios_image_draft_key];
}

static NSURL* ios_image_remote(NSDictionary* command) {
  NSString* identifier = command[@"imageId"], *href = command[@"url"];
  if (!ios_image_hash(identifier) || ![href isKindOfClass:NSString.class]) return nil;
  NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
  return ios_same_origin(url) && [url.path isEqual:[@"/api/image/" stringByAppendingString:identifier]] &&
    !url.query.length && !url.fragment.length ? url : nil;
}

static BOOL ios_image_hash_matches(NSData* bytes, NSString* identifier) {
  if (!bytes.length || bytes.length > IOS_IMAGE_LIMIT || !ios_image_hash(identifier)) return NO;
  unsigned char digest[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
  NSMutableString* actual = [NSMutableString stringWithCapacity:64];
  for (unsigned index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) [actual appendFormat:@"%02x", digest[index]];
  return [actual isEqual:identifier];
}

static NSData* ios_image_download(NSURL* url, unsigned* status) {
  *status = 2;
  if (!ios_same_origin(url)) return nil;
  BendIOSFetch* stream = [BendIOSFetch new]; stream.limit = IOS_IMAGE_LIMIT;
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30; config.waitsForConnectivity = NO;
  NSOperationQueue* queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:queue];
  NSURLSessionDataTask* task = [session dataTaskWithURL:url]; [task resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [session invalidateAndCancel]; *status = 3; return nil;
  }
  [session finishTasksAndInvalidate];
  NSInteger code = [stream->response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse*)stream->response).statusCode : 0;
  if (stream->error || stream->oversized || code < 200 || code > 299 ||
    ![@[@"image/jpeg", @"image/png"] containsObject:stream->response.MIMEType.lowercaseString] || !ios_image_dimensions(stream->body)) return nil;
  *status = 1; return stream->body;
}

@interface BendIOSImage : NSObject <PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(copy) NSString* session;
@property(copy) NSString* caption;
@property(strong) PHPickerViewController* picker;
@property(strong) UIImagePickerController* camera;
@property(strong) NSProgress* loading;
@property(strong) NSMutableSet<NSString*>* activeLoads;
@property NSUInteger generation;
- (NSString*)command:(NSDictionary*)command;
- (void)background;
@end
static BendIOSImage* ios_image;

@implementation BendIOSImage
- (void)emit:(NSString*)phase metadata:(NSDictionary*)metadata {
  NSMutableDictionary* event = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
  event[@"session"] = self.session ?: @""; event[@"phase"] = phase;
  ios_action(@{@"action":@"image", @"data":event});
}
- (void)retainPhoto:(NSData*)bytes dimensions:(NSDictionary*)dimensions {
  if (!bytes) { [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Could not load this photograph.", @"No se pudo cargar esta fotografía.")}]; return; }
  NSString* identifier = NSUUID.UUID.UUIDString;
  NSURL* retained = ios_image_file(identifier);
  NSMutableDictionary* metadata = [dimensions mutableCopy];
  metadata[@"imageId"] = identifier; metadata[@"url"] = retained.absoluteString ?: @"";
  metadata[@"mimeType"] = @"image/jpeg"; metadata[@"caption"] = self.caption ?: @"";
  if (!retained || ![bytes writeToURL:retained options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL] || !ios_image_draft(metadata)) {
    if (retained) [NSFileManager.defaultManager removeItemAtURL:retained error:NULL];
    [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Could not save this photograph.", @"No se pudo guardar esta fotografía.")}]; return;
  }
  [self emit:@"selected" metadata:metadata];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker {
  if (picker != self.camera) return;
  ++self.generation; self.camera = nil;
  [picker dismissViewControllerAnimated:YES completion:nil];
  [self emit:@"cancelled" metadata:nil];
}
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info {
  if (picker != self.camera) return;
  UIImage* image = info[UIImagePickerControllerOriginalImage];
  NSUInteger generation = ++self.generation;
  [picker dismissViewControllerAnimated:YES completion:nil];
  [self emit:@"loading" metadata:nil];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSURL* temporary = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".jpg"]]];
    NSData* original = image ? UIImageJPEGRepresentation(image, 0.95) : nil;
    NSDictionary* dimensions = nil;
    NSData* bytes = original.length <= (64u << 20) && [original writeToURL:temporary options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL]
      ? ios_image_jpeg(temporary, &dimensions) : nil;
    [NSFileManager.defaultManager removeItemAtURL:temporary error:NULL];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation) return;
      self.camera = nil;
      [self retainPhoto:bytes dimensions:dimensions];
    });
  });
}
- (void)picker:(PHPickerViewController*)picker didFinishPicking:(NSArray<PHPickerResult*>*)results {
  if (picker != self.picker) return;
  [picker dismissViewControllerAnimated:YES completion:nil]; self.picker = nil;
  if (!results.count) { ++self.generation; [self emit:@"cancelled" metadata:nil]; return; }
  NSItemProvider* provider = results.firstObject.itemProvider;
  NSUInteger generation = ++self.generation;
  [self emit:@"loading" metadata:nil];
  self.loading = [provider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier completionHandler:^(NSURL* file, NSError* error) {
    NSDictionary* dimensions = nil;
    NSData* bytes = file && !error ? ios_image_jpeg(file, &dimensions) : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation) return;
      self.loading = nil;
      [self retainPhoto:bytes dimensions:dimensions];
    });
  }];
}
- (NSString*)command:(NSDictionary*)command {
  NSString* action = command[@"action"], *session = command[@"session"];
  if (![action isKindOfClass:NSString.class] || ![session isKindOfClass:NSString.class] || !session.length || session.length > 128)
    return @"image commands require an action and session";
  if ([action isEqual:@"pick"] || [action isEqual:@"camera"]) {
    id caption = command[@"caption"] ?: @"";
    if (![caption isKindOfClass:NSString.class] || [caption lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 131072) return @"invalid image caption";
    if ([NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key]) return ios_audio_words(@"Wait for the current send receipt first.", @"Espera la confirmación del envío actual primero.");
    if ([NSUserDefaults.standardUserDefaults dictionaryForKey:ios_image_draft_key]) return ios_audio_words(@"Send or remove the current photograph first.", @"Envía o elimina la fotografía actual primero.");
    if (self.picker || self.camera || self.loading) return ios_audio_words(@"A photograph is already being selected.", @"Ya se está seleccionando una fotografía.");
    UIViewController* presenter = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) if ([scene isKindOfClass:UIWindowScene.class])
      for (UIWindow* window in ((UIWindowScene*)scene).windows) if (window.isKeyWindow) presenter = window.rootViewController;
    if (!presenter.view.window || presenter.presentedViewController) return ios_audio_words(@"The photo picker is not available yet.", @"El selector de fotos aún no está disponible.");
    self.session = session; self.caption = caption;
    if ([action isEqual:@"camera"]) {
      if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
        return ios_audio_words(@"This device has no available camera.", @"Este dispositivo no tiene una cámara disponible.");
      if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSCameraUsageDescription"] length]) return @"This build is missing its camera permission description.";
      AVAuthorizationStatus authorization = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
      if (authorization == AVAuthorizationStatusDenied || authorization == AVAuthorizationStatusRestricted)
        return ios_audio_words(@"Allow camera access in Settings to take a photo.", @"Permite el acceso a la cámara en Ajustes para tomar una foto.");
      self.camera = [UIImagePickerController new]; self.camera.delegate = self;
      NSUInteger generation = ++self.generation;
      void (^present)(BOOL) = ^(BOOL granted) {
        if (generation != self.generation) return;
        if (!granted || !presenter.view.window || presenter.presentedViewController) {
          self.camera = nil;
          [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Camera access is unavailable. Try again or check Settings.", @"No se pudo acceder a la cámara. Reintenta o revisa Ajustes.")}]; return;
        }
        self.camera.sourceType = UIImagePickerControllerSourceTypeCamera;
        self.camera.mediaTypes = @[UTTypeImage.identifier];
        [presenter.view endEditing:YES]; [presenter presentViewController:self.camera animated:YES completion:nil];
      };
      [self emit:@"picking" metadata:nil];
      if (authorization == AVAuthorizationStatusAuthorized) present(YES);
      else [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{ present(granted); });
      }];
      return nil;
    }
    PHPickerConfiguration* config = [PHPickerConfiguration new]; config.filter = PHPickerFilter.imagesFilter;
    config.selectionLimit = 1; config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;
    self.picker = [[PHPickerViewController alloc] initWithConfiguration:config]; self.picker.delegate = self;
    [presenter.view endEditing:YES]; [presenter presentViewController:self.picker animated:YES completion:nil];
    [self emit:@"picking" metadata:nil]; return nil;
  }
  if ([action isEqual:@"load"]) {
    NSURL* remote = ios_image_remote(command);
    if (!remote) return @"photograph load requires its canonical same-origin image URL";
    NSString* identifier = command[@"imageId"]; NSURL* retained = ios_image_file(identifier);
    NSData* cached = [NSData dataWithContentsOfURL:retained options:NSDataReadingMappedIfSafe error:NULL];
    NSDictionary* dimensions = ios_image_hash_matches(cached, identifier) ? ios_image_dimensions(cached) : nil;
    if (dimensions) { NSMutableDictionary* metadata = [dimensions mutableCopy]; metadata[@"imageId"] = identifier; metadata[@"url"] = retained.absoluteString;
      metadata[@"session"] = session; metadata[@"phase"] = @"loaded";
      ios_action(@{@"action":@"image", @"data":metadata}); return nil; }
    if (!self.activeLoads) self.activeLoads = [NSMutableSet set];
    if ([self.activeLoads containsObject:identifier]) return nil;
    if (self.activeLoads.count >= 4) return @"four photograph loads are already active";
    [self.activeLoads addObject:identifier];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      unsigned status = 2; NSData* bytes = ios_image_download(remote, &status);
      NSDictionary* size = ios_image_hash_matches(bytes, identifier) ? ios_image_dimensions(bytes) : nil;
      BOOL saved = size && [bytes writeToURL:retained options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.activeLoads removeObject:identifier];
        NSMutableDictionary* metadata = saved ? [size mutableCopy] : [NSMutableDictionary dictionary];
        metadata[@"session"] = session; metadata[@"phase"] = saved ? @"loaded" : @"error"; metadata[@"imageId"] = identifier;
        if (saved) metadata[@"url"] = retained.absoluteString;
        else metadata[@"error"] = ios_audio_words(@"Could not load the sent photograph.", @"No se pudo cargar la fotografía enviada.");
        ios_action(@{@"action":@"image", @"data":metadata});
      });
    }); return nil;
  }
  if (![session isEqual:self.session]) return @"image session is no longer active";
  if (![action isEqual:@"cancel"]) return @"unsupported image action";
  NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_image_draft_key];
  if (command[@"imageId"] && ![command[@"imageId"] isEqual:draft[@"imageId"]]) return @"image draft no longer matches";
  NSDictionary* pending = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key];
  if (draft[@"imageId"] && [pending[@"imageId"] isEqual:draft[@"imageId"]]) return ios_audio_words(@"This photograph is awaiting its send receipt.", @"Esta fotografía está esperando su confirmación de envío.");
  ++self.generation; [self.loading cancel]; self.loading = nil;
  [self.picker dismissViewControllerAnimated:YES completion:nil]; self.picker = nil;
  [self.camera dismissViewControllerAnimated:YES completion:nil]; self.camera = nil;
  if (ios_clip_id(draft[@"imageId"])) [NSFileManager.defaultManager removeItemAtURL:ios_image_file(draft[@"imageId"]) error:NULL];
  [NSUserDefaults.standardUserDefaults removeObjectForKey:ios_image_draft_key]; [NSUserDefaults.standardUserDefaults synchronize];
  [self emit:@"cancelled" metadata:nil]; return nil;
}
- (void)background {
  if (!self.picker && !self.camera && !self.loading) return;
  ++self.generation; [self.loading cancel]; self.loading = nil;
  [self.picker dismissViewControllerAnimated:NO completion:nil]; self.picker = nil;
  [self.camera dismissViewControllerAnimated:NO completion:nil]; self.camera = nil;
  [self emit:@"cancelled" metadata:nil];
}
@end

static void ios_image_edited(NSString* name, NSString* value) {
  if (![@[@"textbox · Message", @"textbox · Mensaje"] containsObject:name ?: @""] ||
      ![value isKindOfClass:NSString.class]) return;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    NSDictionary* draft = [defaults dictionaryForKey:ios_image_draft_key];
    // Once sent, the photo caption belongs to its durable receipt. Later
    // composer edits keep using the ordinary textbox cache instead.
    if (draft[@"requestId"]) return;
    if (ios_image.picker || ios_image.camera || ios_image.loading) ios_image.caption = value;
    if (ios_clip_id(draft[@"imageId"])) {
      NSMutableDictionary* edited = [draft mutableCopy]; edited[@"caption"] = value;
      ios_image_draft(edited);
    }
  }
}

static void ios_image_restore(void) {
  NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_image_draft_key];
  if (!ios_clip_id(draft[@"imageId"]) || ![draft[@"caption"] isKindOfClass:NSString.class]) return;
  NSURL* file = ios_image_file(draft[@"imageId"]);
  NSDictionary* dimensions = ios_image_dimensions([NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:NULL]);
  if (!dimensions) return;
  if (!ios_image) ios_image = [BendIOSImage new]; ios_image.session = ios_session_prefix;
  NSMutableDictionary* metadata = [draft mutableCopy]; [metadata addEntriesFromDictionary:dimensions];
  metadata[@"url"] = file.absoluteString; metadata[@"restored"] = @YES;
  [ios_image emit:@"selected" metadata:metadata];
}

static char* ios_image_request(NSString* text, unsigned* status) {
  id command = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if (![command isKindOfClass:NSDictionary.class]) { *status = 2; return ios_dup(@"image command must be JSON"); }
  __block NSString* problem = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{ if (!ios_image) ios_image = [BendIOSImage new]; problem = [ios_image command:command]; });
  *status = problem ? 2 : 1; return ios_dup(problem ?: @"");
}

static char* ios_image_upload(NSString* text, unsigned* status) {
  *status = 2;
  id envelope = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  NSDictionary* payload = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"body"] : nil;
  NSString* href = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"url"] : nil;
  if (![payload isKindOfClass:NSDictionary.class] || ![href isKindOfClass:NSString.class] ||
    ![payload[@"requestId"] isKindOfClass:NSString.class] || ![payload[@"requestId"] length] ||
    ![payload[@"threadId"] isKindOfClass:NSString.class] || ![payload[@"threadId"] length] ||
    ![payload[@"text"] isKindOfClass:NSString.class] || !ios_clip_id(payload[@"imageId"])) return ios_dup(@"invalid image upload metadata");
  NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(url) || ![url.path isEqual:@"/api/image"] || url.query.length || url.fragment.length) return ios_dup(@"image upload requires the configured /api/image endpoint");
  NSData* bytes = [NSData dataWithContentsOfURL:ios_image_file(payload[@"imageId"]) options:NSDataReadingMappedIfSafe error:NULL];
  NSDictionary* dimensions = ios_image_dimensions(bytes);
  NSData* metadata = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:NULL];
  if (!dimensions || !metadata || metadata.length > 131072) return ios_dup(@"image file is missing or invalid");
  if (![payload[@"width"] isEqual:dimensions[@"width"]] || ![payload[@"height"] isEqual:dimensions[@"height"]]) return ios_dup(@"image dimensions do not match the selected photograph");
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  NSMutableDictionary* marker = [payload mutableCopy]; marker[@"kind"] = @"image";
  @synchronized(defaults) {
    NSDictionary* pending = [defaults dictionaryForKey:ios_pending_key];
    if (pending && ![pending isEqual:marker]) return ios_dup(@"another send is still awaiting its receipt");
    NSDictionary* draft = [defaults dictionaryForKey:ios_image_draft_key];
    if (![draft[@"imageId"] isEqual:payload[@"imageId"]]) return ios_dup(@"selected photograph no longer matches");
    if (draft[@"requestId"] && (![draft[@"requestId"] isEqual:payload[@"requestId"]] || ![draft[@"caption"] isEqual:payload[@"text"]])) return ios_dup(@"image retry must preserve its original caption and request identifier");
    NSMutableDictionary* remembered = [draft mutableCopy];
    for (NSString* key in @[@"requestId", @"threadId", @"provider"]) if ([payload[key] isKindOfClass:NSString.class]) remembered[key] = payload[key];
    remembered[@"caption"] = payload[@"text"];
    if (!ios_image_draft(remembered)) return ios_dup(@"could not save photograph retry metadata");
    [defaults setObject:marker forKey:ios_pending_key];
    if (![defaults synchronize] || ![[defaults dictionaryForKey:ios_pending_key] isEqual:marker]) return ios_dup(@"could not save photograph send receipt metadata");
  }
  NSString* boundary = [@"BendImage-" stringByAppendingString:NSUUID.UUID.UUIDString];
  NSMutableData* multipart = [NSMutableData data];
  [multipart appendData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [multipart appendData:metadata];
  [multipart appendData:[[NSString stringWithFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%@.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n", boundary, payload[@"imageId"]] dataUsingEncoding:NSUTF8StringEncoding]];
  [multipart appendData:bytes]; [multipart appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  request.HTTPMethod = @"POST"; request.HTTPBody = multipart;
  [request setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
  NSURLComponents* origin = [NSURLComponents componentsWithURL:ios_origin resolvingAgainstBaseURL:YES]; origin.path = @""; origin.query = nil; origin.fragment = nil;
  [request setValue:origin.string forHTTPHeaderField:@"Origin"];
  BendIOSFetch* stream = [BendIOSFetch new];
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30; config.waitsForConnectivity = NO;
  NSOperationQueue* queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:queue];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request]; [task resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [session invalidateAndCancel]; *status = 3; return ios_dup(@"photograph upload timeout");
  }
  [session finishTasksAndInvalidate];
  if (stream->oversized) return ios_dup(@"image reply exceeds 1 MiB");
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
      ios_image_acknowledged(pending); [defaults removeObjectForKey:ios_pending_key]; [defaults synchronize];
    }
  }
  char* result = malloc(stream->body.length + 1); if (!result) abort();
  memcpy(result, stream->body.bytes, stream->body.length); result[stream->body.length] = 0;
  *status = 1; return result;
}
