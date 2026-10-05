// UIKit host for a fork-compiled Bend Canvas app. Layout, content and state
// remain in Bend; this file carries drawing, editing, events and HTTPS IO.
#import <UIKit/UIKit.h>
#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int bend_main(int argc, char** argv);
extern void bend_paint(CGContextRef, NSArray*, CGFloat, CGFloat);
extern NSArray* bend_paint_regions(NSArray*);
extern NSString* bend_paint_check(NSArray*);
extern NSString* bend_paint_prepare(NSArray*);
extern void bend_paint_set_dark(BOOL);

#define IOS_LIMIT 1048576
#define IOS_EVENTS 256
#define IOS_ACTIVE 64
static NSString* const ios_pending_key = @"dot-pending-request";
static NSURL* ios_origin;
static NSDictionary* ios_boot_pending;
static BOOL ios_persist = YES;
static BOOL ios_dark;
static NSString* ios_submit_label;
static NSString* ios_session_prefix;
static pthread_mutex_t ios_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ios_bell = PTHREAD_COND_INITIALIZER;
static NSMutableArray* ios_events;
static NSMutableDictionary* ios_read;
static BOOL ios_waiting;
static NSUInteger ios_edit_serial;
static atomic_bool ios_stopped;
static atomic_int ios_active;

static char* ios_dup(NSString* text) {
  char* result = strdup(text.UTF8String ?: "");
  if (result == NULL) abort();
  return result;
}

static NSString* ios_json(id object) {
  NSData* data = [NSJSONSerialization dataWithJSONObject:object
    options:NSJSONWritingSortedKeys error:NULL];
  return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static void ios_deliver(NSString* text, NSString* key, NSUInteger version) {
  if (text == nil || [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > IOS_LIMIT) return;
  pthread_mutex_lock(&ios_lock);
  if (!atomic_load(&ios_stopped)) {
    NSArray* last = ios_events.lastObject;
    // A newer edit of the same field subsumes the adjacent unread edit.
    // Focus, clicks and other fields remain ordered boundaries.
    if (key.length && version && [last[1] isEqual:key] && [last[2] unsignedIntegerValue])
      ios_events[ios_events.count - 1] = @[text, key, @(version)];
    else if (ios_events.count < IOS_EVENTS)
      [ios_events addObject:@[text, key ?: @"", @(version)]];
  }
  pthread_cond_signal(&ios_bell);
  pthread_mutex_unlock(&ios_lock);
}

// Coalesce physical refreshes and adjacent resizes; never reorder edits.
static void ios_action(NSDictionary* data) {
  NSString* text = ios_json(data);
  if (!text) return;
  pthread_mutex_lock(&ios_lock);
  BOOL refresh = [data[@"action"] isEqual:@"refresh"];
  BOOL resize = [data[@"action"] isEqual:@"resize"];
  BOOL queued = NO;
  if (refresh) for (NSArray* event in ios_events) {
    if ([event[0] isEqual:text]) { queued = YES; break; }
  }
  NSArray* last = ios_events.lastObject;
  if (!atomic_load(&ios_stopped) && !queued) {
    if (resize && [last[0] hasPrefix:@"{\"action\":\"resize\","])
      ios_events[ios_events.count - 1] = @[text, @"", @0];
    else if (ios_events.count < IOS_EVENTS) [ios_events addObject:@[text, @"", @0]];
  }
  pthread_cond_signal(&ios_bell);
  pthread_mutex_unlock(&ios_lock);
}

static BOOL ios_has_read(NSString* key, NSUInteger version) {
  pthread_mutex_lock(&ios_lock);
  BOOL read = [ios_read[key] unsignedIntegerValue] >= version;
  pthread_mutex_unlock(&ios_lock);
  return read;
}

static char* ios_event(unsigned* status) {
  pthread_mutex_lock(&ios_lock);
  if (ios_waiting) {
    pthread_mutex_unlock(&ios_lock); *status = 2;
    return ios_dup(@"an event request is already pending");
  }
  ios_waiting = YES;
  while (!ios_events.count && !atomic_load(&ios_stopped))
    pthread_cond_wait(&ios_bell, &ios_lock);
  NSArray* event = ios_events.firstObject;
  if (event) {
    [ios_events removeObjectAtIndex:0];
    if ([event[1] length]) ios_read[event[1]] = event[2];
  }
  ios_waiting = NO;
  pthread_mutex_unlock(&ios_lock);
  *status = event ? 1 : 3;
  return ios_dup(event ? event[0] : @"stopped");
}

static NSNumber* ios_port(NSURL* url) { return url.port ?: @443; }
static BOOL ios_same_origin(NSURL* url) {
  return url && ios_origin && [ios_origin.scheme.lowercaseString isEqual:@"https"] &&
    [url.scheme.lowercaseString isEqual:@"https"] &&
    [url.host.lowercaseString isEqual:ios_origin.host.lowercaseString] &&
    [ios_port(url) isEqual:ios_port(ios_origin)] && !url.user.length && !url.password.length;
}

@interface BendIOSFetch : NSObject <NSURLSessionDataDelegate> {
@public
  NSMutableData* body;
  NSURLResponse* response;
  NSError* error;
  BOOL oversized;
  dispatch_semaphore_t done;
@private
  BOOL finished;
}
@property NSUInteger limit;
@end

@implementation BendIOSFetch
- (instancetype)init {
  self = [super init];
  if (self) { body = [NSMutableData data]; done = dispatch_semaphore_create(0); _limit = IOS_LIMIT; }
  return self;
}
- (void)finish:(NSError*)problem {
  if (!finished) { finished = YES; error = problem; dispatch_semaphore_signal(done); }
}
- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)task
  didReceiveResponse:(NSURLResponse*)got
  completionHandler:(void (^)(NSURLSessionResponseDisposition))complete {
  response = got;
  if (got.expectedContentLength > (long long)self.limit) { oversized = YES; complete(NSURLSessionResponseCancel); }
  else complete(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)task
  didReceiveData:(NSData*)data {
  if (finished || oversized) return;
  if (data.length > self.limit - body.length) { oversized = YES; [task cancel]; }
  else [body appendData:data];
}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task
  willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request
  completionHandler:(void (^)(NSURLRequest*))complete {
  // A redirect must not change the trusted origin or replay a durable send.
  complete(nil);
}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task
  didCompleteWithError:(NSError*)problem { [self finish:problem]; }
- (void)URLSession:(NSURLSession*)session didBecomeInvalidWithError:(NSError*)problem {
  [self finish:problem];
}
@end

static NSData* ios_audio_download(NSURL* url, unsigned* status) {
  *status = 2;
  if (!ios_same_origin(url)) return nil;
  BendIOSFetch* stream = [BendIOSFetch new]; stream.limit = 16u << 20;
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30;
  config.waitsForConnectivity = NO;
  NSOperationQueue* queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:queue];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url
    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request]; [task resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [session invalidateAndCancel]; *status = 3; return nil;
  }
  [session finishTasksAndInvalidate];
  if (stream->error || stream->oversized || ![stream->response isKindOfClass:NSHTTPURLResponse.class]) return nil;
  NSInteger code = ((NSHTTPURLResponse*)stream->response).statusCode;
  if (code < 200 || code > 299 || ![stream->response.MIMEType.lowercaseString isEqual:@"audio/mp4"]) return nil;
  *status = 1; return stream->body;
}

#include "ios_voice.c"
#include "ios_media.c"

static char* ios_audio_upload(NSString* text, unsigned* status) {
  *status = 2;
  id envelope = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  NSDictionary* payload = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"body"] : nil;
  NSString* href = [envelope isKindOfClass:NSDictionary.class] ? envelope[@"url"] : nil;
  if (![payload isKindOfClass:NSDictionary.class] || ![href isKindOfClass:NSString.class] ||
    ![payload[@"requestId"] isKindOfClass:NSString.class] || ![payload[@"threadId"] isKindOfClass:NSString.class] ||
    !ios_clip_id(payload[@"clipId"])) return ios_dup(@"audio upload takes {url,body:{requestId,threadId,clipId,...}}");
  NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(url) || ![url.path isEqual:@"/api/audio"] || url.query.length || url.fragment.length)
    return ios_dup(@"audio upload requires the configured /api/audio endpoint");
  NSURL* file = ios_audio_file(payload[@"clipId"], NO);
  NSNumber* size = nil; [file getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
  if (!size || !size.unsignedLongLongValue || size.unsignedLongLongValue > IOS_AUDIO_LIMIT)
    return ios_dup(@"recorded audio is missing or exceeds 16 MiB");
  NSData* clip = [NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:NULL];
  NSData* metadata = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:NULL];
  if (!clip.length || clip.length > IOS_AUDIO_LIMIT || !metadata || metadata.length > 131072)
    return ios_dup(@"invalid audio metadata or file");
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    [defaults setObject:payload forKey:ios_pending_key];
    if (![defaults synchronize] || ![[defaults dictionaryForKey:ios_pending_key] isEqual:payload])
      return ios_dup(@"No se pudo guardar el envío de audio en este dispositivo.");
    NSDictionary* draft = [defaults dictionaryForKey:ios_audio_draft_key];
    if ([draft[@"clipId"] isEqual:payload[@"clipId"]]) {
      NSMutableDictionary* remembered = [draft mutableCopy];
      for (NSString* key in @[@"requestId", @"threadId", @"provider"])
        if ([payload[key] isKindOfClass:NSString.class]) remembered[key] = payload[key];
      if (!ios_audio_draft(remembered)) return ios_dup(@"Could not save audio retry metadata.");
    }
  }
  NSString* boundary = [@"BendAudio-" stringByAppendingString:NSUUID.UUID.UUIDString];
  NSMutableData* multipart = [NSMutableData data];
  NSString* before = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n", boundary];
  [multipart appendData:[before dataUsingEncoding:NSUTF8StringEncoding]]; [multipart appendData:metadata];
  NSString* between = [NSString stringWithFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"%@.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n", boundary, payload[@"clipId"]];
  [multipart appendData:[between dataUsingEncoding:NSUTF8StringEncoding]]; [multipart appendData:clip];
  [multipart appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url
    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  request.HTTPMethod = @"POST"; request.HTTPBody = multipart;
  [request setValue:[@"multipart/form-data; boundary=" stringByAppendingString:boundary] forHTTPHeaderField:@"Content-Type"];
  NSURLComponents* origin = [NSURLComponents componentsWithURL:ios_origin resolvingAgainstBaseURL:YES];
  origin.path = @""; origin.query = nil; origin.fragment = nil;
  [request setValue:origin.string forHTTPHeaderField:@"Origin"];
  BendIOSFetch* stream = [BendIOSFetch new];
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30; config.waitsForConnectivity = NO;
  NSOperationQueue* queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:queue];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request]; [task resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [session invalidateAndCancel]; *status = 3; return ios_dup(@"audio upload timeout");
  }
  [session finishTasksAndInvalidate];
  if (stream->oversized) return ios_dup(@"audio reply exceeds 1 MiB");
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
      ios_audio_acknowledged(pending);
      ios_image_acknowledged(pending);
      [defaults removeObjectForKey:ios_pending_key]; [defaults synchronize];
    }
  }
  char* result = malloc(stream->body.length + 1); if (!result) abort();
  memcpy(result, stream->body.bytes, stream->body.length); result[stream->body.length] = 0;
  *status = 1; return result;
}

static char* ios_fetch(unsigned op, NSString* text, unsigned* status) {
  *status = 2;
  NSString* href = text;
  NSDictionary* payload = nil;
  NSData* post = nil;
  if (op == 6) {
    id envelope = [NSJSONSerialization JSONObjectWithData:
      [text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    if (![envelope isKindOfClass:NSDictionary.class] ||
        ![envelope[@"url"] isKindOfClass:NSString.class] ||
        ![envelope[@"body"] isKindOfClass:NSDictionary.class])
      return ios_dup(@"a post takes the JSON {url, body}");
    href = envelope[@"url"]; payload = envelope[@"body"];
    post = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    if (!post || post.length > IOS_LIMIT) return ios_dup(@"invalid or oversized POST body");
  }
  NSURL* url = [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(url)) return ios_dup(@"requests require the configured HTTPS origin");
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  if (op == 6 && payload[@"requestId"] != nil) {
    if (![payload[@"requestId"] isKindOfClass:NSString.class] ||
        ![payload[@"threadId"] isKindOfClass:NSString.class] ||
        ![payload[@"text"] isKindOfClass:NSString.class])
      return ios_dup(@"invalid durable request");
    // This write precedes transport; a crash or lost reply can reuse its id.
    @synchronized(defaults) {
      NSMutableDictionary* pending = [payload mutableCopy];
      if ([payload[@"mode"] isEqual:@"call"]) pending[@"kind"] = @"call";
      [defaults setObject:pending forKey:ios_pending_key];
      if (![defaults synchronize] || ![[defaults dictionaryForKey:ios_pending_key] isEqual:pending])
        return ios_dup(@"No se pudo guardar el envío en este dispositivo.");
    }
  }
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url
    cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
  if (op == 6) {
    request.HTTPMethod = @"POST"; request.HTTPBody = post;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSURLComponents* origin = [NSURLComponents componentsWithURL:ios_origin resolvingAgainstBaseURL:YES];
    origin.path = @""; origin.query = nil; origin.fragment = nil;
    [request setValue:origin.string forHTTPHeaderField:@"Origin"];
  }
  BendIOSFetch* stream = [BendIOSFetch new];
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 30;
  config.waitsForConnectivity = NO;
  NSOperationQueue* queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:stream delegateQueue:queue];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request];
  [task resume];
  if (dispatch_semaphore_wait(stream->done, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC))) {
    [task cancel]; [session invalidateAndCancel];
    *status = 3; return ios_dup(@"request timeout");
  }
  [session finishTasksAndInvalidate];
  if (stream->oversized) return ios_dup(@"response exceeds 1 MiB");
  if (stream->error) {
    *status = stream->error.code == NSURLErrorTimedOut || stream->error.code == NSURLErrorCancelled ? 3 : 2;
    return ios_dup(stream->error.code == NSURLErrorTimedOut ? @"request timeout" : stream->error.localizedDescription);
  }
  if (![stream->response isKindOfClass:NSHTTPURLResponse.class]) return ios_dup(@"invalid HTTPS response");
  NSInteger code = ((NSHTTPURLResponse*)stream->response).statusCode;
  id decoded = [NSJSONSerialization JSONObjectWithData:stream->body options:0 error:NULL];
  if (code < 200 || code > 299) {
    NSString* problem = [decoded isKindOfClass:NSDictionary.class] &&
      [decoded[@"error"] isKindOfClass:NSString.class] ? decoded[@"error"] : nil;
    return ios_dup(problem.length ? problem : [NSString stringWithFormat:@"HTTP %ld", (long)code]);
  }
  NSArray* receipts = [decoded isKindOfClass:NSDictionary.class] &&
    [decoded[@"acceptedRequestIds"] isKindOfClass:NSArray.class] ? decoded[@"acceptedRequestIds"] : nil;
  @synchronized(defaults) {
    NSDictionary* pending = [defaults dictionaryForKey:ios_pending_key];
    if (pending[@"requestId"] && [receipts containsObject:pending[@"requestId"]]) {
      ios_audio_acknowledged(pending);
      ios_image_acknowledged(pending);
      [defaults removeObjectForKey:ios_pending_key]; [defaults synchronize];
    }
  }
  // host.c decodes UTF-8; do not reinterpret or truncate its reply bytes.
  char* result = malloc(stream->body.length + 1);
  if (!result) abort();
  memcpy(result, stream->body.bytes, stream->body.length); result[stream->body.length] = 0;
  *status = 1;
  return result;
}

@interface BendIOSEditor : UITextView
@property(copy) NSString* key;
@property(copy) NSString* name;
@property NSUInteger version;
@end
@implementation BendIOSEditor
@end

@interface BendIOSButton : UIButton
@property(copy) NSString* eventName;
@end
@implementation BendIOSButton
@end

static CGRect ios_rect(NSDictionary* region) {
  return CGRectMake([region[@"x"] doubleValue], [region[@"y"] doubleValue],
    [region[@"w"] doubleValue], [region[@"h"] doubleValue]);
}
static BOOL ios_enabled(NSDictionary* region) {
  return region[@"enabled"] == nil || [region[@"enabled"] boolValue];
}
static BOOL ios_textbox(NSDictionary* region) {
  return [region[@"kind"] isEqual:@"textbox"] || [region[@"name"] hasPrefix:@"textbox · "];
}
static BOOL ios_field_proxy(NSDictionary* region, NSArray* regions) {
  if (![region[@"kind"] isEqual:@"field"] || ![region[@"name"] isEqual:@"Field text"]) return NO;
  // Field text is the drawn child of F's textbox, not a second control.
  // Native editor hit testing owns this area; sheet/button order stays intact.
  for (NSDictionary* owner in regions)
    if (ios_textbox(owner) && CGRectContainsRect(ios_rect(owner), ios_rect(region))) return YES;
  return NO;
}
static UIColor* ios_ink(void) {
  return ios_dark ? [UIColor colorWithRed:0xf6 / 255.0 green:0xf7 / 255.0 blue:0xf8 / 255.0 alpha:1]
    : [UIColor colorWithRed:0x10 / 255.0 green:0x11 / 255.0 blue:0x12 / 255.0 alpha:1];
}

// HTML overflow remains reachable beyond its declared frame. Give the native
// bitmap and scroll view the same content bounds, without resizing the viewport.
static NSArray* ios_content_projection(NSArray* commands) {
  NSArray* frame = commands[0];
  double width = [frame[1] doubleValue], height = [frame[2] doubleValue];
  for (NSArray* command in commands) {
    if (command.count >= 6 && ([command[0] isEqual:@"shape"] || [command[0] isEqual:@"region"])) {
      width = MAX(width, [command[2] doubleValue] + [command[4] doubleValue]);
      height = MAX(height, [command[3] doubleValue] + [command[5] doubleValue]);
    }
  }
  width = ceil(width); height = ceil(height);
  if (width == [frame[1] doubleValue] && height == [frame[2] doubleValue]) return commands;
  NSMutableArray* projected = [commands mutableCopy];
  projected[0] = @[@"frame", @(width), @(height)];
  return projected;
}

@interface BendIOSCanvas : UIView
@property(strong) NSArray* commands;
@property CGSize canvasSize;
@end
@implementation BendIOSCanvas
- (void)drawRect:(CGRect)rect {
  if (!self.commands) return;
  NSMutableArray* fields = [NSMutableArray array], *editing = [NSMutableArray array];
  for (UIView* child in self.subviews) if ([child isKindOfClass:BendIOSEditor.class]) {
    BendIOSEditor* editor = (BendIOSEditor*)child;
    [fields addObject:[NSValue valueWithCGRect:editor.frame]];
    if (editor.isFirstResponder && editor.text.length) [editing addObject:[NSValue valueWithCGRect:editor.frame]];
  }
  NSMutableArray* projected = [NSMutableArray arrayWithCapacity:self.commands.count];
  for (NSArray* command in self.commands) {
    BOOL hide = NO;
    if (command.count >= 7 && [command[0] isEqual:@"shape"] && [command[6] isKindOfClass:NSArray.class]) {
      NSArray* shape = command[6];
      BOOL caret = [command[1] isEqual:@"Caret"];
      if (caret || (shape.count && [shape[0] isEqual:@"text"])) {
        CGRect bounds = CGRectMake([command[2] doubleValue], [command[3] doubleValue],
          [command[4] doubleValue], [command[5] doubleValue]);
        for (NSValue* field in caret ? fields : editing)
          if (CGRectIntersectsRect(bounds, field.CGRectValue)) { hide = YES; break; }
      }
    }
    if (!hide) [projected addObject:command];
  }
  bend_paint(UIGraphicsGetCurrentContext(), ios_content_projection(projected),
    self.bounds.size.width, self.bounds.size.height);
}
@end

@interface BendIOSController : UIViewController <UITextViewDelegate>
@property(strong) UIScrollView* scroll;
@property(strong) BendIOSCanvas* canvas;
@property(strong) NSMutableDictionary<NSString*, BendIOSEditor*>* fields;
@property(strong) NSMutableDictionary<NSString*, BendIOSButton*>* buttons;
@property CGRect keyboardFrame;
@property CGSize sentViewport;
@property BOOL painting;
@property BOOL restoredPending;
- (void)apply:(NSArray*)commands;
- (void)scheme:(BOOL)dark;
@end
static BendIOSController* ios_controller;

@implementation BendIOSController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.fields = [NSMutableDictionary dictionary]; self.buttons = [NSMutableDictionary dictionary];
  self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
  self.scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  self.scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  self.scroll.alwaysBounceVertical = NO;
  self.canvas = [[BendIOSCanvas alloc] initWithFrame:CGRectZero];
  self.canvas.opaque = NO;
  [self.scroll addSubview:self.canvas]; [self.view addSubview:self.scroll];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:)
    name:UIKeyboardWillChangeFrameNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:)
    name:UIKeyboardWillHideNotification object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(assetsChanged:)
    name:@"BendPaintAssetsChanged" object:nil];
  [self scheme:ios_dark];
}
- (void)assetsChanged:(NSNotification*)notification { [self.canvas setNeedsDisplay]; }
- (void)keyboard:(NSNotification*)notification {
  self.keyboardFrame = [notification.name isEqual:UIKeyboardWillHideNotification]
    ? CGRectZero : [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  [self.view setNeedsLayout];
  [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]
    animations:^{ [self.view layoutIfNeeded]; }];
}
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGRect viewport = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
  if (!CGRectIsEmpty(self.keyboardFrame)) {
    CGRect keyboard = [self.view convertRect:self.keyboardFrame fromView:nil];
    CGRect covered = CGRectIntersection(viewport, keyboard);
    if (!CGRectIsNull(covered) && covered.size.width > viewport.size.width / 2)
      viewport.size.height = MAX(1, CGRectGetMinY(covered) - viewport.origin.y);
  }
  self.scroll.frame = viewport;
  CGSize size = CGSizeMake(MAX(1, floor(viewport.size.width)), MAX(1, floor(viewport.size.height)));
  if (!CGSizeEqualToSize(size, self.sentViewport)) {
    self.sentViewport = size;
    ios_action(@{@"action":@"resize", @"width":@((unsigned)size.width), @"height":@((unsigned)size.height)});
  }
  [self fitCanvas];
}
- (void)fitCanvas {
  CGSize size = CGSizeMake(MAX(self.canvas.canvasSize.width, self.scroll.bounds.size.width),
    MAX(self.canvas.canvasSize.height, self.scroll.bounds.size.height));
  self.canvas.frame = (CGRect){CGPointZero, size}; self.scroll.contentSize = size;
}
- (void)scheme:(BOOL)dark {
  ios_dark = dark; bend_paint_set_dark(dark);
  self.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
  self.view.backgroundColor = dark ? UIColor.blackColor : UIColor.whiteColor;
  self.scroll.backgroundColor = self.view.backgroundColor;
  for (BendIOSEditor* field in self.fields.allValues) {
    field.tintColor = ios_ink(); field.textColor = field.isFirstResponder ? ios_ink() : UIColor.clearColor;
  }
  [self.canvas setNeedsDisplay];
}
- (void)edited:(BendIOSEditor*)field {
  // A recreated textbox must never reuse an acknowledged edit version.
  field.version = ++ios_edit_serial;
  ios_deliver(ios_json(@{@"action":@"field", @"name":field.name, @"value":field.text ?: @""}), field.key, field.version);
  ios_image_edited(field.name, field.text ?: @"");
  if (ios_persist) {
    NSString* key = [@"bend-input:" stringByAppendingString:field.name];
    if (field.text.length) [NSUserDefaults.standardUserDefaults setObject:field.text forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
  }
}
- (void)textViewDidChange:(UITextView*)textView { [self edited:(BendIOSEditor*)textView]; }
- (void)textViewDidBeginEditing:(UITextView*)textView {
  BendIOSEditor* field = (BendIOSEditor*)textView;
  field.textColor = ios_ink(); [self.canvas setNeedsDisplay];
  if (!self.painting) ios_deliver(ios_json(@{@"action":@"focus", @"name":field.name}), nil, 0);
}
- (void)textViewDidEndEditing:(UITextView*)textView {
  BendIOSEditor* field = (BendIOSEditor*)textView;
  field.textColor = UIColor.clearColor; [self.canvas setNeedsDisplay];
  if (!self.painting) ios_deliver(ios_json(@{@"action":@"blur", @"name":field.name}), nil, 0);
}
- (BOOL)textView:(UITextView*)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString*)text {
  NSString* submit = ios_submit_label;
  if ([text isEqual:@"\n"] && submit.length && textView.markedTextRange == nil) {
    NSString* name = [@"button · " stringByAppendingString:submit];
    for (BendIOSButton* button in self.buttons.allValues)
      if (button.enabled && [button.eventName isEqual:name]) { ios_deliver(name, nil, 0); return NO; }
  }
  return YES;
}
- (void)clicked:(BendIOSButton*)button {
  if (!button.enabled) return;
  NSString* submit = ios_submit_label;
  if (!submit.length || ![button.eventName isEqual:[@"button · " stringByAppendingString:submit]])
    [self.view endEditing:YES];
  ios_deliver(button.eventName, nil, 0);
}
- (BendIOSEditor*)field:(NSString*)name key:(NSString*)key {
  BendIOSEditor* field = [[BendIOSEditor alloc] initWithFrame:CGRectZero];
  field.name = name; field.key = key; field.delegate = self;
  field.backgroundColor = UIColor.clearColor; field.textColor = UIColor.clearColor;
  field.tintColor = ios_ink(); field.font = [UIFont systemFontOfSize:17];
  field.textContainerInset = UIEdgeInsetsMake(14, 16, 14, 16);
  field.textContainer.lineFragmentPadding = 0;
  NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
  style.minimumLineHeight = 22; style.maximumLineHeight = 22;
  field.typingAttributes = @{NSFontAttributeName:field.font, NSParagraphStyleAttributeName:style};
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  field.spellCheckingType = UITextSpellCheckingTypeNo;
  field.accessibilityLabel = [name hasPrefix:@"textbox · "] ? [name substringFromIndex:10] : name;
  if (ios_submit_label.length) field.returnKeyType = UIReturnKeySend;
  return field;
}
- (void)apply:(NSArray*)commands {
  NSArray* frame = ios_content_projection(commands)[0];
  self.canvas.canvasSize = CGSizeMake([frame[1] doubleValue], [frame[2] doubleValue]);
  self.canvas.commands = commands;
  NSArray* regions = bend_paint_regions(commands) ?: @[];
  NSMutableDictionary* fields = [NSMutableDictionary dictionary], *buttons = [NSMutableDictionary dictionary];
  NSMutableArray* fresh = [NSMutableArray array]; NSCountedSet* seen = [NSCountedSet set];
  self.painting = YES;
  for (NSDictionary* region in regions) {
    if (ios_field_proxy(region, regions)) continue;
    NSString* name = [region[@"name"] isKindOfClass:NSString.class] ? region[@"name"] : @"";
    NSUInteger occurrence = [seen countForObject:name]; [seen addObject:name];
    NSString* key = occurrence ? [NSString stringWithFormat:@"%@#%lu", name, (unsigned long)occurrence] : name;
    CGRect bounds = ios_rect(region); BOOL enabled = ios_enabled(region);
    if (ios_textbox(region)) {
      NSString* value = [region[@"value"] isKindOfClass:NSString.class] ? region[@"value"] : nil;
      BendIOSEditor* field = self.fields[key];
      if (!field) { field = [self field:name key:key]; field.text = value ?: @""; [fresh addObject:field]; }
      else if (value && field.markedTextRange == nil && ios_has_read(key, field.version) && ![field.text isEqual:value]) {
        NSRange selection = field.selectedRange;
        field.text = value;
        selection.location = MIN(selection.location, value.length);
        selection.length = MIN(selection.length, value.length - selection.location);
        field.selectedRange = selection;
      }
      field.frame = bounds; field.editable = enabled; field.selectable = enabled;
      field.userInteractionEnabled = enabled; field.textColor = field.isFirstResponder ? ios_ink() : UIColor.clearColor;
      [self.canvas addSubview:field]; fields[key] = field;
      // Persist the rendered value only after Bend has consumed the latest edit.
      if (ios_persist && ![fresh containsObject:field] && field.markedTextRange == nil && ios_has_read(key, field.version)) {
        NSString* cached = [@"bend-input:" stringByAppendingString:field.name];
        if (field.text.length) [NSUserDefaults.standardUserDefaults setObject:field.text forKey:cached];
        else [NSUserDefaults.standardUserDefaults removeObjectForKey:cached];
      }
    } else {
      BendIOSButton* button = self.buttons[key];
      if (!button) {
        button = [BendIOSButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self action:@selector(clicked:) forControlEvents:UIControlEventTouchUpInside];
      }
      button.eventName = name; button.frame = bounds; button.enabled = enabled;
      NSRange separator = [name rangeOfString:@" · "];
      button.accessibilityLabel = separator.location == NSNotFound ? name : [name substringFromIndex:NSMaxRange(separator)];
      [self.canvas addSubview:button]; buttons[key] = button;
    }
  }
  for (NSString* key in self.fields) if (!fields[key]) [self.fields[key] removeFromSuperview];
  for (NSString* key in self.buttons) if (!buttons[key]) [self.buttons[key] removeFromSuperview];
  self.fields = fields; self.buttons = buttons; self.painting = NO;
  [self fitCanvas]; [self.canvas setNeedsDisplay];
  for (BendIOSEditor* field in fields.allValues)
    if (field.isFirstResponder) [self.scroll scrollRectToVisible:field.frame animated:NO];
  for (BendIOSEditor* field in fresh) if (ios_persist && !field.text.length) {
    NSString* text = [NSUserDefaults.standardUserDefaults stringForKey:[@"bend-input:" stringByAppendingString:field.name]];
    if (text.length) { field.text = text; [self edited:field]; }
  }
  // Cached Typed precedes Pending, including when the first GET already acknowledged it.
  if (!self.restoredPending) {
    self.restoredPending = YES;
    ios_voice_restore();
    ios_image_restore();
    if ([ios_boot_pending[@"kind"] isEqual:@"image"] &&
        [ios_boot_pending[@"requestId"] isKindOfClass:NSString.class] &&
        [ios_boot_pending[@"threadId"] isKindOfClass:NSString.class] && ios_clip_id(ios_boot_pending[@"imageId"])) {
      NSMutableDictionary* pending = [ios_boot_pending mutableCopy];
      pending[@"id"] = pending[@"requestId"]; pending[@"thread"] = pending[@"threadId"];
      ios_action(@{@"action":@"pending", @"data":pending});
    } else if ([ios_boot_pending[@"requestId"] isKindOfClass:NSString.class] &&
        [ios_boot_pending[@"threadId"] isKindOfClass:NSString.class] && ios_clip_id(ios_boot_pending[@"clipId"])) {
      NSMutableDictionary* pending = [ios_boot_pending mutableCopy];
      pending[@"kind"] = @"audio"; pending[@"id"] = pending[@"requestId"]; pending[@"thread"] = pending[@"threadId"];
      ios_action(@{@"action":@"pending", @"data":pending});
    } else if ([ios_boot_pending[@"requestId"] isKindOfClass:NSString.class] &&
        [ios_boot_pending[@"threadId"] isKindOfClass:NSString.class] &&
        [ios_boot_pending[@"text"] isKindOfClass:NSString.class])
      {
        NSMutableDictionary* pending = [ios_boot_pending mutableCopy];
        pending[@"id"] = pending[@"requestId"]; pending[@"thread"] = pending[@"threadId"];
        if ([pending[@"mode"] isEqual:@"call"] || [pending[@"kind"] isEqual:@"call"]) pending[@"kind"] = @"call";
        ios_action(@{@"action":@"pending", @"data":pending});
      }
    ios_boot_pending = nil;
  }
}
@end

static char* ios_canvas(const char* data, unsigned len, unsigned* status) {
  NSError* error = nil;
  id commands = [NSJSONSerialization JSONObjectWithData:
    [NSData dataWithBytesNoCopy:(void*)data length:len freeWhenDone:NO] options:0 error:&error];
  NSString* problem = commands == nil ? @"invalid Canvas JSON" : bend_paint_check(commands) ?: bend_paint_prepare(commands);
  if (!problem) problem = bend_paint_check(ios_content_projection(commands));
  if (problem) { *status = 2; return ios_dup(problem); }
  dispatch_sync(dispatch_get_main_queue(), ^{ [ios_controller apply:commands]; });
  *status = 1; return ios_dup(@"");
}

char* bend_native_request(unsigned op, const char* data, unsigned len, unsigned* status) {
  @autoreleasepool {
    *status = 2;
    if (len > IOS_LIMIT) return ios_dup(@"request exceeds 1 MiB");
    if (atomic_fetch_add(&ios_active, 1) >= IOS_ACTIVE) {
      atomic_fetch_sub(&ios_active, 1); return ios_dup(@"too many pending requests");
    }
    char* reply = NULL;
    if (op == 2) reply = ios_event(status);
    else if (op == 4) reply = ios_canvas(data, len, status);
    else if (op == 3 || op == 6) {
      NSString* text = [[NSString alloc] initWithBytes:data length:len encoding:NSUTF8StringEncoding];
      reply = text ? ios_fetch(op, text, status) : ios_dup(@"request is not UTF-8");
    } else if (op == 7 && len == 1 && (data[0] == '0' || data[0] == '1')) {
      dispatch_sync(dispatch_get_main_queue(), ^{ ios_persist = data[0] == '1'; });
      *status = 1; reply = ios_dup(@"");
    } else if (op == 8 && ((len == 4 && memcmp(data, "dark", 4) == 0) ||
      (len == 5 && memcmp(data, "light", 5) == 0))) {
      dispatch_sync(dispatch_get_main_queue(), ^{ [ios_controller scheme:len == 4]; });
      *status = 1; reply = ios_dup(@"");
    } else if (op == 9) {
      id config = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithBytesNoCopy:(void*)data length:len freeWhenDone:NO] options:0 error:NULL];
      BOOL valid = [config isKindOfClass:NSDictionary.class];
      for (NSString* key in @[@"width", @"height", @"min_width", @"min_height"]) {
        id n = valid ? config[key] : nil;
        double number = [n isKindOfClass:NSNumber.class] ? [n doubleValue] : 0;
        valid = valid && [n isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)n) != CFBooleanGetTypeID()
          && number >= 1 && number <= 100000 && floor(number) == number;
      }
      if (valid) {
        // A phone's content bounds are UIKit's; Bend receives their actual size.
        dispatch_sync(dispatch_get_main_queue(), ^{ [ios_controller.view setNeedsLayout]; });
        *status = 1; reply = ios_dup(@"");
      } else reply = ios_dup(@"viewport dimensions must be positive integer points");
    } else if (op == 10 || op == 11) {
      NSString* text = [[NSString alloc] initWithBytes:data length:len encoding:NSUTF8StringEncoding];
      reply = text ? (op == 10 ? ios_voice_request(text, status) : ios_audio_upload(text, status)) : ios_dup(@"request is not UTF-8");
    } else if (op == 12 || op == 13) {
      NSString* text = [[NSString alloc] initWithBytes:data length:len encoding:NSUTF8StringEncoding];
      reply = text ? (op == 12 ? ios_image_request(text, status) : ios_image_upload(text, status)) : ios_dup(@"request is not UTF-8");
    } else reply = ios_dup([NSString stringWithFormat:@"unsupported native operation %u", op]);
    atomic_fetch_sub(&ios_active, 1);
    return reply;
  }
}

static void* ios_run(void* ignored) {
  @autoreleasepool {
    char* args[] = {"Bend", "--threads", "1", "--gpu", "off", "--", NULL};
    int code = bend_main(6, args);
    if (!atomic_load(&ios_stopped)) dispatch_async(dispatch_get_main_queue(), ^{
      UILabel* notice = [[UILabel alloc] initWithFrame:ios_controller.view.bounds];
      notice.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      notice.backgroundColor = ios_controller.view.backgroundColor; notice.textColor = ios_ink();
      notice.numberOfLines = 0; notice.textAlignment = NSTextAlignmentCenter;
      notice.text = [NSString stringWithFormat:@"Dot se detuvo (%d). Cierra y vuelve a abrir la app.", code];
      [ios_controller.view addSubview:notice];
    });
  }
  return NULL;
}

@interface BendIOSAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow* window;
@property(strong) NSTimer* refreshTimer;
@end
@implementation BendIOSAppDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
  ios_events = [NSMutableArray array]; ios_read = [NSMutableDictionary dictionary];
  NSString* language = [NSLocale.preferredLanguages.firstObject.lowercaseString hasPrefix:@"es"] ? @"es" : @"en";
  NSString* configuredSubmit = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendSubmitLabel"];
  ios_submit_label = [@[@"Enviar", @"Send"] containsObject:configuredSubmit ?: @""]
    ? ([language isEqual:@"es"] ? @"Enviar" : @"Send") : configuredSubmit;
  ios_action(@{@"action":@"language", @"value":language});
  NSString* origin = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendOrigin"];
  ios_origin = [NSURL URLWithString:origin ?: @""];
  ios_boot_pending = [[NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key] copy];
  ios_session_prefix = NSUUID.UUID.UUIDString;
  ios_action(@{@"action":@"session", @"value":ios_session_prefix});
  ios_controller = [BendIOSController new];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = ios_controller; [self.window makeKeyAndVisible];
  [ios_controller.view layoutIfNeeded];
  pthread_attr_t attributes; pthread_attr_init(&attributes);
  pthread_attr_setstacksize(&attributes, 8u << 20);
  pthread_t thread;
  int failed = pthread_create(&thread, &attributes, ios_run, NULL);
  pthread_attr_destroy(&attributes);
  if (failed) { fprintf(stderr, "Bend UIKit thread failed: %d\n", failed); return NO; }
  pthread_detach(thread);
  return YES;
}
- (void)refresh:(NSTimer*)timer { ios_action(@{@"action":@"refresh"}); }
- (void)applicationDidBecomeActive:(UIApplication*)application {
  [self.refreshTimer invalidate];
  self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(refresh:)
    userInfo:nil repeats:YES];
  ios_action(@{@"action":@"refresh"}); [ios_controller.view setNeedsLayout];
}
- (void)applicationWillResignActive:(UIApplication*)application {
  [self.refreshTimer invalidate]; self.refreshTimer = nil;
  [NSUserDefaults.standardUserDefaults synchronize];
}
- (void)applicationDidEnterBackground:(UIApplication*)application { [ios_voice background]; [ios_image background]; }
- (void)applicationWillTerminate:(UIApplication*)application {
  [ios_voice background];
  [ios_image background];
  atomic_store(&ios_stopped, YES);
  pthread_mutex_lock(&ios_lock); pthread_cond_broadcast(&ios_bell); pthread_mutex_unlock(&ios_lock);
  [NSUserDefaults.standardUserDefaults synchronize];
}
@end

int main(int argc, char** argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(BendIOSAppDelegate.class)); }
}
