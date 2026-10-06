// Selected photographs stay in Bend's existing composer until Send.
// PhotosUI grants access to the selected file without opening the library.
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ImageIO/ImageIO.h>
#import <CommonCrypto/CommonDigest.h>
#import <AVFoundation/AVFoundation.h>
#include <TargetConditionals.h>

static BOOL ios_file_stage(NSURL* source, NSString* name, NSString* session, NSString* caption);

#define IOS_IMAGE_LIMIT (5u << 20)
static NSString* ios_image_draft_key = @"bend-image-draft";

static BOOL ios_image_hash(NSString* value) {
  if (![value isKindOfClass:NSString.class] || value.length != 64) return NO;
  return [value rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"].invertedSet].location == NSNotFound;
}

static NSURL* ios_image_file(NSString* identifier) {
  if (!ios_clip_id(identifier) && !ios_image_hash(identifier)) return nil;
  NSURL* directory = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
  directory = ios_scoped_directory(directory);
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

@interface BendIOSCameraSurface : UIView
@property(strong) UIImageView* still;
@end
@implementation BendIOSCameraSurface
+ (Class)layerClass { return AVCaptureVideoPreviewLayer.class; }
- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.userInteractionEnabled = NO; self.isAccessibilityElement = NO;
    self.clipsToBounds = YES;
    ((AVCaptureVideoPreviewLayer*)self.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.still = [[UIImageView alloc] initWithFrame:self.bounds];
    self.still.contentMode = UIViewContentModeScaleAspectFill;
    self.still.clipsToBounds = YES; self.still.hidden = YES;
    self.still.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.still];
  }
  return self;
}
@end

@interface BendIOSImage : NSObject <PHPickerViewControllerDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>
@property(copy) NSString* session;
@property(copy) NSString* caption;
@property(strong) PHPickerViewController* picker;
@property(strong) AVCaptureSession* camera;
@property(strong) AVCapturePhotoOutput* photoOutput;
@property(strong) AVCaptureMovieFileOutput* movieOutput;
@property(strong) AVCaptureDeviceInput* cameraInput;
@property(strong) AVCaptureDeviceInput* microphoneInput;
@property(strong) NSURL* movieURL;
@property BOOL movieRequested;
@property BOOL discardMovie;
@property(strong) AVCaptureDevice* cameraDevice;
@property(strong) AVCaptureDeviceRotationCoordinator* rotation API_AVAILABLE(ios(17.0));
@property(strong) BendIOSCameraSurface* surface;
@property(strong) dispatch_queue_t cameraQueue;
@property(copy) NSString* cameraPhase;
@property(strong) NSData* previewBytes;
@property(strong) NSDictionary* previewMetadata;
@property(strong) NSURL* previewURL;
@property(strong) NSMutableArray* cameraObservers;
@property int64_t captureID;
@property(strong) AVAudioPlayer* captureSound;
@property BOOL customCaptureSound;
@property BOOL cameraDisplayed;
@property BOOL cameraAttached;
@property(strong) NSProgress* loading;
@property(strong) NSMutableSet<NSString*>* activeLoads;
@property NSUInteger generation;
- (NSString*)command:(NSDictionary*)command;
- (void)background;
- (void)surfaceIn:(UIView*)container rect:(CGRect)rect session:(NSString*)session visible:(BOOL)visible radius:(CGFloat)radius;
@end
static BendIOSImage* ios_image;
static void* ios_camera_rotation_context = &ios_camera_rotation_context;

@implementation BendIOSImage
- (void)emit:(NSString*)phase metadata:(NSDictionary*)metadata {
  NSMutableDictionary* event = metadata ? [metadata mutableCopy] : [NSMutableDictionary dictionary];
  event[@"session"] = self.session ?: @""; event[@"phase"] = phase;
  ios_action(@{@"action":@"image", @"data":event});
}
- (BOOL)retainPhoto:(NSData*)bytes dimensions:(NSDictionary*)dimensions {
  if (!bytes) { [self emit:@"error" metadata:@{@"error":ios_audio_words(@"Could not load this photograph.", @"No se pudo cargar esta fotografía.")}]; return NO; }
  NSString* identifier = NSUUID.UUID.UUIDString;
  NSURL* retained = ios_image_file(identifier);
  NSMutableDictionary* metadata = [@{@"width":dimensions[@"width"], @"height":dimensions[@"height"]} mutableCopy];
  metadata[@"imageId"] = identifier; metadata[@"url"] = retained.absoluteString ?: @"";
  metadata[@"mimeType"] = @"image/jpeg"; metadata[@"caption"] = self.caption ?: @"";
  if (!retained || ![bytes writeToURL:retained options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL] || !ios_image_draft(metadata)) {
    if (retained) [NSFileManager.defaultManager removeItemAtURL:retained error:NULL];
    NSString* problem = ios_audio_words(@"Could not save this photograph.", @"No se pudo guardar esta fotografía.");
    if (self.camera) [self cameraUnavailable:@"storage" message:problem];
    else [self emit:@"error" metadata:@{@"error":problem}];
    return NO;
  }
  [self emit:@"selected" metadata:metadata]; return YES;
}
- (void)discardPreview {
  if (self.previewURL) [NSFileManager.defaultManager removeItemAtURL:self.previewURL error:NULL];
  self.previewURL = nil; self.previewBytes = nil; self.previewMetadata = nil;
  self.surface.still.image = nil; self.surface.still.hidden = YES;
}
- (void)stopCamera {
  ++self.generation; self.captureID = 0; self.movieRequested = NO; self.discardMovie = YES;
  if (self.movieOutput.isRecording) [self.movieOutput stopRecording];
  for (id observer in self.cameraObservers) [NSNotificationCenter.defaultCenter removeObserver:observer];
  self.cameraObservers = nil;
  if (@available(iOS 17.0, *)) {
    if (self.rotation) [self.rotation removeObserver:self forKeyPath:@"videoRotationAngleForHorizonLevelPreview" context:ios_camera_rotation_context];
    self.rotation = nil;
  }
  AVCaptureSession* camera = self.camera;
  self.camera = nil; self.photoOutput = nil; self.movieOutput = nil; self.cameraInput = nil; self.microphoneInput = nil; self.cameraDevice = nil; self.cameraPhase = nil; self.cameraDisplayed = NO; self.cameraAttached = NO;
  ((AVCaptureVideoPreviewLayer*)self.surface.layer).session = nil;
  [self.surface removeFromSuperview]; self.surface = nil;
  if (camera) dispatch_async(self.cameraQueue, ^{ [camera stopRunning]; });
  [self discardPreview];
}
- (void)cameraUnavailable:(NSString*)reason message:(NSString*)message {
  ++self.generation;
  self.cameraPhase = @"camera-unavailable"; self.captureID = 0;
  [self.surface removeFromSuperview];
  AVCaptureSession* camera = self.camera;
  if (camera) dispatch_async(self.cameraQueue, ^{ [camera stopRunning]; });
  [self emit:@"camera-unavailable" metadata:@{@"reason":reason, @"error":message}];
}
- (void)updateRotation {
  AVCaptureConnection* preview = ((AVCaptureVideoPreviewLayer*)self.surface.layer).connection;
  if (@available(iOS 17.0, *)) {
    CGFloat angle = self.rotation.videoRotationAngleForHorizonLevelPreview;
    if (self.rotation && [preview isVideoRotationAngleSupported:angle]) preview.videoRotationAngle = angle;
  }
  if (preview.isVideoMirroringSupported) {
    preview.automaticallyAdjustsVideoMirroring = NO;
    preview.videoMirrored = self.cameraDevice.position == AVCaptureDevicePositionFront;
  }
}
- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
  if (context != ios_camera_rotation_context) { [super observeValueForKeyPath:keyPath ofObject:object change:change context:context]; return; }
  dispatch_async(dispatch_get_main_queue(), ^{ if (@available(iOS 17.0, *)) if (object == self.rotation) [self updateRotation]; });
}
- (void)surfaceIn:(UIView*)container rect:(CGRect)rect session:(NSString*)session visible:(BOOL)visible radius:(CGFloat)radius {
  if (!visible && self.camera && self.cameraDisplayed) {
    BOOL attached = self.cameraAttached;
    [self stopCamera];
    if (!attached) [self emit:@"cancelled" metadata:nil];
    return;
  }
  if (!visible || ![session isEqual:self.session] || !self.camera || [self.cameraPhase isEqual:@"camera-unavailable"] ||
      !isfinite(rect.origin.x) || !isfinite(rect.origin.y) || !isfinite(rect.size.width) || !isfinite(rect.size.height) || CGRectIsEmpty(rect)) {
    [self.surface removeFromSuperview]; return;
  }
  if (!self.surface) {
    self.surface = [[BendIOSCameraSurface alloc] initWithFrame:rect];
    ((AVCaptureVideoPreviewLayer*)self.surface.layer).session = self.camera;
  }
  if (self.surface.superview != container) [container insertSubview:self.surface atIndex:0];
  self.surface.frame = rect; self.cameraDisplayed = YES;
  self.surface.layer.cornerRadius = isfinite(radius) ? MAX(0, MIN(radius, MIN(rect.size.width, rect.size.height) / 2)) : 0;
  self.surface.layer.masksToBounds = YES;
  [self updateRotation];
}
- (void)configureCamera:(NSUInteger)generation {
  AVCaptureSession* camera = self.camera;
  dispatch_async(self.cameraQueue, ^{
    if (generation != self.generation) return;
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if (!device) device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError* error = nil;
    AVCaptureDeviceInput* input = device ? [AVCaptureDeviceInput deviceInputWithDevice:device error:&error] : nil;
    AVCapturePhotoOutput* output = [AVCapturePhotoOutput new];
    [camera beginConfiguration];
    BOOL configured = input && !error && [camera canAddInput:input] && [camera canSetSessionPreset:AVCaptureSessionPresetHigh];
    if (configured) {
      camera.sessionPreset = AVCaptureSessionPresetHigh;
      [camera addInput:input]; configured = [camera canAddOutput:output];
      if (configured) [camera addOutput:output];
    }
    [camera commitConfiguration];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation || camera != self.camera) return;
      if (!configured) { [self cameraUnavailable:@"configuration" message:ios_audio_words(@"The camera could not start. Try again.", @"No se pudo iniciar la cámara. Reintenta.")]; return; }
      self.cameraDevice = device; self.cameraInput = input; self.photoOutput = output;
      if (@available(iOS 17.0, *)) {
        self.rotation = [[AVCaptureDeviceRotationCoordinator alloc] initWithDevice:device previewLayer:self.surface.layer];
        [self.rotation addObserver:self forKeyPath:@"videoRotationAngleForHorizonLevelPreview" options:NSKeyValueObservingOptionNew context:ios_camera_rotation_context];
      }
      [self updateRotation];
      dispatch_async(self.cameraQueue, ^{
        if (generation != self.generation) return;
        [camera startRunning];
        BOOL running = camera.isRunning;
        dispatch_async(dispatch_get_main_queue(), ^{
          if (generation != self.generation || camera != self.camera || ![self.cameraPhase isEqual:@"camera-opening"]) return;
          if (!running) { [self cameraUnavailable:@"start" message:ios_audio_words(@"The camera is unavailable right now.", @"La cámara no está disponible en este momento.")]; return; }
          self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:nil];
        });
      });
    });
  });
}
- (void)openCamera {
  if (!self.cameraQueue) self.cameraQueue = dispatch_queue_create("bend.camera.capture", DISPATCH_QUEUE_SERIAL);
  self.camera = [AVCaptureSession new]; self.cameraPhase = @"camera-opening";
  self.surface = [[BendIOSCameraSurface alloc] initWithFrame:CGRectZero];
  ((AVCaptureVideoPreviewLayer*)self.surface.layer).session = self.camera;
  NSUInteger generation = ++self.generation;
  [self emit:self.cameraPhase metadata:nil];
#if TARGET_OS_SIMULATOR
  [self cameraUnavailable:@"simulator" message:ios_audio_words(@"Camera capture is unavailable in Simulator. Choose a photograph instead.", @"La captura con cámara no está disponible en el simulador. Elige una fotografía.")];
  return;
#endif
  if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSCameraUsageDescription"] length]) {
    [self cameraUnavailable:@"configuration" message:@"This build is missing its camera permission description."]; return;
  }
  AVCaptureSession* camera = self.camera;
  __weak BendIOSImage* weakSelf = self;
  self.cameraObservers = [NSMutableArray array];
  for (NSNotificationName name in @[AVCaptureSessionWasInterruptedNotification, AVCaptureSessionRuntimeErrorNotification]) {
    id observer = [NSNotificationCenter.defaultCenter addObserverForName:name object:camera queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* note) {
      BendIOSImage* owner = weakSelf;
      if (!owner || generation != owner.generation || camera != owner.camera || owner.previewBytes.length) return;
      [owner cameraUnavailable:@"interrupted" message:ios_audio_words(@"Camera access was interrupted. Close the camera and try again.", @"Se interrumpió el acceso a la cámara. Ciérrala y vuelve a intentarlo.")];
    }];
    [self.cameraObservers addObject:observer];
  }
  AVAuthorizationStatus authorization = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
  if (authorization == AVAuthorizationStatusDenied || authorization == AVAuthorizationStatusRestricted) {
    [self cameraUnavailable:@"permission" message:ios_audio_words(@"Allow camera access in Settings to take a photo.", @"Permite el acceso a la cámara en Ajustes para tomar una foto.")]; return;
  }
  if (authorization == AVAuthorizationStatusAuthorized) { [self configureCamera:generation]; return; }
  [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation || camera != self.camera) return;
      if (granted) [self configureCamera:generation];
      else [self cameraUnavailable:@"permission" message:ios_audio_words(@"Allow camera access in Settings to take a photo.", @"Permite el acceso a la cámara en Ajustes para tomar una foto.")];
    });
  }];
}
- (NSString*)flipCamera {
  if (![self.cameraPhase isEqual:@"camera-ready"] || self.movieRequested) return nil;
  self.cameraPhase = @"camera-opening"; [self emit:self.cameraPhase metadata:nil];
  NSUInteger generation = self.generation; AVCaptureSession* camera = self.camera;
  AVCaptureDevicePosition position = self.cameraDevice.position == AVCaptureDevicePositionFront ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
  dispatch_async(self.cameraQueue, ^{
    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:position];
    AVCaptureDeviceInput* input = device ? [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL] : nil;
    if (generation != self.generation || camera != self.camera) return;
    AVCaptureDeviceInput* old = self.cameraInput; BOOL changed = NO;
    if (input) {
      [camera beginConfiguration]; [camera removeInput:old];
      changed = [camera canAddInput:input];
      if (changed) [camera addInput:input]; else if ([camera canAddInput:old]) [camera addInput:old];
      [camera commitConfiguration];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation || camera != self.camera) return;
      if (changed) {
        self.cameraDevice = device; self.cameraInput = input;
        if (@available(iOS 17.0, *)) {
          if (self.rotation) [self.rotation removeObserver:self forKeyPath:@"videoRotationAngleForHorizonLevelPreview" context:ios_camera_rotation_context];
          self.rotation = [[AVCaptureDeviceRotationCoordinator alloc] initWithDevice:device previewLayer:self.surface.layer];
          [self.rotation addObserver:self forKeyPath:@"videoRotationAngleForHorizonLevelPreview" options:NSKeyValueObservingOptionNew context:ios_camera_rotation_context];
        }
        [self updateRotation];
      }
      self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:changed ? nil : @{@"error":ios_audio_words(@"This camera is unavailable.", @"Esta cámara no está disponible.")}];
    });
  }); return nil;
}
- (void)beginMovie:(NSUInteger)generation {
  if (generation != self.generation || !self.movieRequested) return;
  AVCaptureSession* camera = self.camera;
  CGFloat rotation = 90; if (@available(iOS 17.0, *)) if (self.rotation) rotation = self.rotation.videoRotationAngleForHorizonLevelCapture;
  BOOL mirrored = self.cameraDevice.position == AVCaptureDevicePositionFront;
  self.discardMovie = NO;
  dispatch_async(self.cameraQueue, ^{
    if (generation != self.generation || !self.movieRequested) return;
    NSError* error = nil;
    AVAudioSession* audio = AVAudioSession.sharedInstance;
    BOOL ready = [audio setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVideoRecording options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error] && [audio setActive:YES error:&error];
    AVCaptureDeviceInput* microphone = self.microphoneInput ?: [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    AVCaptureMovieFileOutput* output = self.movieOutput ?: [AVCaptureMovieFileOutput new];
    [camera beginConfiguration];
    if (!self.microphoneInput && microphone && [camera canAddInput:microphone]) { [camera addInput:microphone]; self.microphoneInput = microphone; }
    if (!self.movieOutput && [camera canAddOutput:output]) { [camera addOutput:output]; self.movieOutput = output; }
    [camera commitConfiguration];
    ready = ready && self.microphoneInput && self.movieOutput && !error;
    if (!ready || generation != self.generation || !self.movieRequested) {
      dispatch_async(dispatch_get_main_queue(), ^{ if (generation == self.generation) { self.movieRequested = NO; self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:@{@"error":ios_audio_words(@"Could not start video recording.", @"No se pudo iniciar la grabación de video.")}]; } }); return;
    }
    output.maxRecordedFileSize = 20u << 20; output.maxRecordedDuration = CMTimeMake(300, 1);
    AVCaptureConnection* connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if (@available(iOS 17.0, *)) if ([connection isVideoRotationAngleSupported:rotation]) connection.videoRotationAngle = rotation;
    if (connection.isVideoMirroringSupported) { connection.automaticallyAdjustsVideoMirroring = NO; connection.videoMirrored = mirrored; }
    NSURL* file = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".mov"]]];
    self.movieURL = file;
    [output startRecordingToOutputFileURL:file recordingDelegate:self];
  });
}
- (NSString*)startMovie {
  if (![self.cameraPhase isEqual:@"camera-ready"] || self.movieRequested) return nil;
  self.movieRequested = YES; self.cameraPhase = @"camera-authorizing-video"; [self emit:self.cameraPhase metadata:nil];
  NSUInteger generation = self.generation;
  AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
  if (status == AVAuthorizationStatusAuthorized) { [self beginMovie:generation]; return nil; }
  if (status == AVAuthorizationStatusNotDetermined) {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self.generation) return;
        if (granted && self.movieRequested) [self beginMovie:generation];
        else { self.movieRequested = NO; self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:granted ? nil : @{@"error":ios_audio_words(@"Allow microphone access in Settings to record video with sound.", @"Permite el acceso al micrófono en Ajustes para grabar video con sonido.")}]; }
      });
    }]; return nil;
  }
  self.movieRequested = NO; self.cameraPhase = @"camera-ready";
  [self emit:self.cameraPhase metadata:@{@"error":ios_audio_words(@"Allow microphone access in Settings to record video with sound.", @"Permite el acceso al micrófono en Ajustes para grabar video con sonido.")}]; return nil;
}
- (NSString*)finishMovie:(BOOL)cancelled {
  self.movieRequested = NO; self.discardMovie = cancelled;
  AVCaptureMovieFileOutput* output = self.movieOutput;
  if (output.isRecording) { self.cameraPhase = @"camera-saving-video"; [self emit:self.cameraPhase metadata:nil]; dispatch_async(self.cameraQueue, ^{ [output stopRecording]; }); }
  else if ([self.cameraPhase isEqual:@"camera-authorizing-video"]) { self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:nil]; }
  return nil;
}
- (void)captureOutput:(AVCaptureFileOutput*)output didStartRecordingToOutputFileAtURL:(NSURL*)file fromConnections:(NSArray<AVCaptureConnection*>*)connections {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (output != self.movieOutput || ![file isEqual:self.movieURL] || !self.movieRequested) { [output stopRecording]; return; }
    self.cameraPhase = @"camera-recording"; [self emit:self.cameraPhase metadata:nil];
  });
}
- (void)captureOutput:(AVCaptureFileOutput*)output didFinishRecordingToOutputFileAtURL:(NSURL*)file fromConnections:(NSArray<AVCaptureConnection*>*)connections error:(NSError*)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    BOOL current = output == self.movieOutput && [file isEqual:self.movieURL];
    BOOL saved = NO;
    if (current && !self.discardMovie && (!error || [error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue])) saved = ios_file_stage(file, @"Video.mov", self.session, self.caption);
    [NSFileManager.defaultManager removeItemAtURL:file error:NULL];
    if (!current) return;
    self.movieURL = nil; self.movieRequested = NO;
    if (saved) { self.cameraAttached = YES; [self stopCamera]; }
    else { self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:self.discardMovie ? nil : @{@"error":ios_audio_words(@"Could not save this video. Videos must be at most 20 MiB.", @"No se pudo guardar este video. Los videos deben ser de hasta 20 MiB.")}]; }
  });
}
- (NSString*)capturePhoto {
  if (![self.cameraPhase isEqual:@"camera-ready"] || !self.photoOutput || self.captureID) return nil;
  AVCapturePhotoOutput* output = self.photoOutput;
  AVCapturePhotoSettings* settings = [output.availablePhotoCodecTypes containsObject:AVVideoCodecTypeJPEG]
    ? [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey:AVVideoCodecTypeJPEG}] : [AVCapturePhotoSettings photoSettings];
  self.customCaptureSound = NO;
  if (@available(iOS 18.0, *)) {
    if (self.captureSound && output.isShutterSoundSuppressionSupported) {
      settings.shutterSoundSuppressionEnabled = YES;
      self.customCaptureSound = YES;
    }
  }
  self.captureID = settings.uniqueID; self.cameraPhase = @"camera-capturing";
  NSUInteger generation = self.generation;
  CGFloat rotation = 90;
  if (@available(iOS 17.0, *)) if (self.rotation) rotation = self.rotation.videoRotationAngleForHorizonLevelCapture;
  BOOL mirrored = self.cameraDevice.position == AVCaptureDevicePositionFront;
  [self emit:self.cameraPhase metadata:nil];
  dispatch_async(self.cameraQueue, ^{
    if (generation != self.generation) return;
    AVCaptureConnection* connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if (@available(iOS 17.0, *)) if ([connection isVideoRotationAngleSupported:rotation]) connection.videoRotationAngle = rotation;
    if (connection.isVideoMirroringSupported) { connection.automaticallyAdjustsVideoMirroring = NO; connection.videoMirrored = mirrored; }
    [output capturePhotoWithSettings:settings delegate:self];
  });
  return nil;
}
- (void)captureOutput:(AVCapturePhotoOutput*)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings*)settings {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (output == self.photoOutput && settings.uniqueID == self.captureID && self.customCaptureSound) {
      self.captureSound.currentTime = 0;
      [self.captureSound play];
    }
  });
}
- (void)captureOutput:(AVCapturePhotoOutput*)output didFinishProcessingPhoto:(AVCapturePhoto*)photo error:(NSError*)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (output != self.photoOutput || photo.resolvedSettings.uniqueID != self.captureID || ![self.cameraPhase isEqual:@"camera-capturing"]) return;
    if (error) { [self cameraUnavailable:@"capture" message:ios_audio_words(@"Could not capture this photograph. Try again.", @"No se pudo capturar esta fotografía. Reintenta.")]; return; }
    NSUInteger generation = self.generation;
    dispatch_async(self.cameraQueue, ^{
      NSData* original = [photo fileDataRepresentation];
      NSURL* temporary = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".jpg"]]];
      NSDictionary* dimensions = nil;
      NSData* bytes = original.length && original.length <= (64u << 20) && [original writeToURL:temporary options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL]
        ? ios_image_jpeg(temporary, &dimensions) : nil;
      [NSFileManager.defaultManager removeItemAtURL:temporary error:NULL];
      NSURL* preview = bytes ? [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".jpg"]]] : nil;
      BOOL saved = preview && [bytes writeToURL:preview options:NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication error:NULL];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (generation != self.generation || output != self.photoOutput || ![self.cameraPhase isEqual:@"camera-capturing"]) {
          if (preview) [NSFileManager.defaultManager removeItemAtURL:preview error:NULL]; return;
        }
        self.captureID = 0;
        if (!saved) { [self cameraUnavailable:@"capture" message:ios_audio_words(@"Could not save this camera preview. Try again.", @"No se pudo guardar la vista previa. Reintenta.")]; return; }
        self.previewBytes = bytes; self.previewURL = preview;
        NSMutableDictionary* metadata = [dimensions mutableCopy];
        metadata[@"imageId"] = preview.lastPathComponent.stringByDeletingPathExtension;
        metadata[@"url"] = preview.absoluteString; metadata[@"mimeType"] = @"image/jpeg";
        self.previewMetadata = metadata; self.cameraPhase = @"camera-preview";
        self.surface.still.image = [UIImage imageWithData:bytes]; self.surface.still.hidden = NO;
        AVCaptureSession* camera = self.camera;
        dispatch_async(self.cameraQueue, ^{ [camera stopRunning]; });
        [self emit:self.cameraPhase metadata:metadata];
      });
    });
  });
}
- (void)captureOutput:(AVCapturePhotoOutput*)output didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings*)settings error:(NSError*)error {
  if (!error) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    if (output == self.photoOutput && settings.uniqueID == self.captureID)
      [self cameraUnavailable:@"capture" message:ios_audio_words(@"Could not capture this photograph. Try again.", @"No se pudo capturar esta fotografía. Reintenta.")];
  });
}
- (NSString*)retakePhoto {
  if (![self.cameraPhase isEqual:@"camera-preview"] || !self.previewBytes.length) return nil;
  [self discardPreview]; self.cameraPhase = @"camera-opening";
  NSUInteger generation = self.generation; AVCaptureSession* camera = self.camera;
  [self emit:self.cameraPhase metadata:nil];
  dispatch_async(self.cameraQueue, ^{
    if (generation != self.generation) return;
    [camera startRunning]; BOOL running = camera.isRunning;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation || camera != self.camera || ![self.cameraPhase isEqual:@"camera-opening"]) return;
      if (!running) { [self cameraUnavailable:@"start" message:ios_audio_words(@"The camera is unavailable right now.", @"La cámara no está disponible en este momento.")]; return; }
      self.cameraPhase = @"camera-ready"; [self emit:self.cameraPhase metadata:nil];
    });
  });
  return nil;
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
      id asset = command[@"captureSound"];
      self.captureSound = nil;
      if (asset) {
        if (![asset isKindOfClass:NSString.class] || ![asset length] || [asset length] > 128 || ![asset isEqual:[asset lastPathComponent]]) return @"invalid capture sound asset";
        NSURL* file = [NSBundle.mainBundle URLForResource:asset withExtension:nil];
        NSError* error = nil;
        // Ambient follows the Ring/Silent switch and cannot retain voice playback's receiver route.
        AVAudioSession* audioSession = AVAudioSession.sharedInstance;
        if (![audioSession setCategory:AVAudioSessionCategoryAmbient mode:AVAudioSessionModeDefault options:0 error:&error] ||
            ![audioSession setActive:YES error:&error]) return error.localizedDescription ?: @"capture sound is unavailable";
        AVAudioPlayer* player = file ? [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&error] : nil;
        if (!player || !isfinite(player.duration) || player.duration > 2 || ![player prepareToPlay]) return error.localizedDescription ?: @"capture sound asset is unavailable";
        self.captureSound = player;
      }
      [self openCamera]; return nil;
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
  if ([action isEqual:@"camera-capture"]) return [self capturePhoto];
  if ([action isEqual:@"camera-flip"]) return [self flipCamera];
  if ([action isEqual:@"camera-video-start"]) return [self startMovie];
  if ([action isEqual:@"camera-video-stop"]) return [self finishMovie:NO];
  if ([action isEqual:@"camera-video-cancel"]) return [self finishMovie:YES];
  if ([action isEqual:@"camera-retake"]) return [self retakePhoto];
  if ([action isEqual:@"camera-attach"]) {
    if (![self.cameraPhase isEqual:@"camera-preview"] || !self.previewBytes.length) return nil;
    if ([self retainPhoto:self.previewBytes dimensions:self.previewMetadata]) self.cameraAttached = YES;
    return nil;
  }
  if (![action isEqual:@"cancel"]) return @"unsupported image action";
  if (self.camera) { [self stopCamera]; [self emit:@"cancelled" metadata:nil]; return nil; }
  NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_image_draft_key];
  if (command[@"imageId"] && ![command[@"imageId"] isEqual:draft[@"imageId"]]) return @"image draft no longer matches";
  NSDictionary* pending = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key];
  if (draft[@"imageId"] && [pending[@"imageId"] isEqual:draft[@"imageId"]]) return ios_audio_words(@"This photograph is awaiting its send receipt.", @"Esta fotografía está esperando su confirmación de envío.");
  ++self.generation; [self.loading cancel]; self.loading = nil;
  [self.picker dismissViewControllerAnimated:YES completion:nil]; self.picker = nil;
  if (ios_clip_id(draft[@"imageId"])) [NSFileManager.defaultManager removeItemAtURL:ios_image_file(draft[@"imageId"]) error:NULL];
  [NSUserDefaults.standardUserDefaults removeObjectForKey:ios_image_draft_key]; [NSUserDefaults.standardUserDefaults synchronize];
  [self emit:@"cancelled" metadata:nil]; return nil;
}
- (void)background {
  if (!self.picker && !self.camera && !self.loading) return;
  ++self.generation; [self.loading cancel]; self.loading = nil;
  [self.picker dismissViewControllerAnimated:NO completion:nil]; self.picker = nil;
  BOOL attached = self.cameraAttached;
  if (self.camera) [self stopCamera];
  if (!attached) [self emit:@"cancelled" metadata:nil];
}
@end

static void ios_image_surface_update(UIView* container, CGRect rect, NSString* session, BOOL visible, CGFloat cornerRadius) {
  [ios_image surfaceIn:container rect:rect session:session visible:visible radius:cornerRadius];
}

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
