// Apple shell
// ===========

// The main of a Bend program built as a Mac app. tool.ts -o <dir>.macos
// compiles this file beside the program's C (built with -DBEND_NATIVE=1,
// its main renamed bend_main) and std/F/apple/paint.c, so an F app's
// author writes only Bend. It is Objective-C in a .c file, as
// bend2/effs/window.c is: tool.ts builds it with -x objective-c -fobjc-arc.
//
// AppKit owns the main thread; Bend runs bend_main on its own thread
// (8 MiB, like a main thread). std/F/browser/host.c's requests come to
// bend_native_request on the runtime's IO helper threads, which block
// there (never the main thread) until the reply is ready. The replies are
// the browser's (shell.js, renderer.js), so the Bend side is the web's:
//
//   2     the next UI event: "button · <label>" (a click on an enabled
//         canvas region), the JSON {"action":"field"|"focus"|"blur",
//         "name":"textbox · <label>"[,"value":<text>]} of a textbox, or
//         "address · <path>" ($BEND_ADDRESS, else "/") when it is asked
//         before the first paint, as the browser's address.js sends the
//         page's address at load.
//   4     paint canvas commands (scene.bend's canvas): checked as
//         renderer.js checks them, then drawn by paint.c's bend_paint in
//         the window. A textbox region gets a transparent NSTextField over
//         it, which edits (the caret, the selection); Bend draws its text.
//         As shell.js does, a field's text is never overwritten while it
//         is edited or holds an edit Bend has not read, each edit is kept
//         per textbox name in NSUserDefaults (localStorage's place), and a
//         textbox that appears empty gets its kept text back as an edit.
//   3, 6  fetch a URL, or post the JSON envelope {url, body} (NSURLSession,
//         30 s, at most 1 MiB; a relative URL against $BEND_ORIGIN, else
//         Info.plist's BendOrigin).
//   7     configure automatic input persistence: "1" enables, "0" disables.
//         Apps configure it before the first paint; BEND_NO_PERSIST=1 always
//         disables it, including when the app requests persistence.
//   8     explicit Canvas appearance: "dark" or "light", including native
//         window chrome and the page outside the Canvas frame.
//   9     opt into a responsive window: JSON width, height, min_width and
//         min_height in content points. Events then include JSON action
//         "resize" with the actual viewport width and height. AppKit retains
//         the person's window size; Bend lays out a new Canvas for it.
//   1, 5  (HTML, GPU compute) answer an error: a native app paints canvas.
//
// The window is titled with the bundle's name, takes the first frame's
// size, and follows later frames' sizes until a person resizes it; a frame
// larger than the window scrolls. Closing it quits; so does the end of
// bend_main, with its exit code.
//
// For agents and tests:
//   BEND_TRACE=1       stderr: bend-paint <n> <w>x<h>, bend-text <n> <text>
//                      (each text drawn, in order) and bend-event <event>
//   BEND_TRACE=2       also bend-region <n> ... and bend-request <op> <bytes>
//   BEND_INPUTS=a|b    one step after each paint: click:<label>,
//                      type:<label>=<text>, focus:<label>, blur:<label>,
//                      address:<path>; a step with no such region prints
//                      bend-script-miss and the regions there are
//   BEND_SNAPSHOT=p    each paint, drawn offscreen at 2x, as the PNG p (a %d
//                      in p is the paint's number)
//   BEND_EXIT=1        exit 0 after the first paint after the last step (3
//                      on a miss; 4 when no paint comes in 30 s, 60 s at start)
//   BEND_HIDDEN=1      never show the window (and no Dock icon)
//   BEND_NO_PERSIST=1  keep no textbox text
//   BEND_THREADS=n     the runtime's worker count (else one per core)
// stdout is line-buffered. Launched by Finder or open (stdout at /dev/null)
// both streams go to ~/Library/Logs/<name>.log, and a launch at / works in
// ~/Library/Application Support/<bundle id>. The program's IO.args are the
// launch arguments.

#import <AppKit/AppKit.h>
#include <fcntl.h>
#include <math.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

extern int      bend_main(int argc, char** argv);
extern void     bend_paint(CGContextRef cg, NSArray* commands, CGFloat width,
  CGFloat height);
extern NSArray* bend_paint_regions(NSArray* commands);
extern NSArray* bend_paint_texts(NSArray* commands);
extern void     bend_paint_set_dark(BOOL enabled);
// renderer.js's checks and image loads (blocking), each nil or its error;
// and a paint as a PNG
extern NSString* bend_paint_check(NSArray* commands);
extern NSString* bend_paint_prepare(NSArray* commands);
extern BOOL      bend_paint_png(NSArray* commands, CGFloat width, CGFloat height,
  CGFloat scale, NSString* path);

#define SHELL_LIMIT  1048576
#define SHELL_EVENTS 256
#define SHELL_ACTIVE 64

static int       shell_trace;
static BOOL      shell_persist = YES;
static BOOL      shell_exit;
static BOOL      shell_hidden;
static BOOL      shell_dark;
static NSString* shell_snapshot;
static NSString* shell_address = @"/";
static NSURL*    shell_origin;
static NSString* shell_name;
static int       shell_argc;
static char**    shell_argv;

// Notes

static void shell_note(const char* fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  flockfile(stderr);
  vfprintf(stderr, fmt, ap);
  fputc('\n', stderr);
  funlockfile(stderr);
  va_end(ap);
}

// A note's text on one line (use its UTF8String within the note's call).
static NSString* shell_one(NSString* s) {
  s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
  return [s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
}

static char* shell_dup(NSString* s) {
  char* p = strdup(s.UTF8String ?: "");
  if (p == NULL) {
    abort();
  }
  return p;
}

// JSON.stringify of a string: the same escapes, byte for byte.
static NSString* shell_quote(NSString* s) {
  NSUInteger       n = s.length;
  NSMutableString* o = [NSMutableString stringWithCapacity:n + 2];
  [o appendString:@"\""];
  for (NSUInteger i = 0; i < n; i += 1) {
    unichar c = [s characterAtIndex:i];
    unichar d = i + 1 < n ? [s characterAtIndex:i + 1] : 0;
    if (c == '"' || c == '\\') {
      [o appendFormat:@"\\%C", c];
    } else if (c == '\b' || c == '\f' || c == '\n' || c == '\r' || c == '\t') {
      [o appendString:c == '\b' ? @"\\b" : c == '\f' ? @"\\f" : c == '\n'
        ? @"\\n" : c == '\r' ? @"\\r" : @"\\t"];
    } else if (c < 0x20) {
      [o appendFormat:@"\\u%04x", c];
    } else if (CFStringIsSurrogateHighCharacter(c)
      && CFStringIsSurrogateLowCharacter(d)) {
      [o appendFormat:@"%C%C", c, d];
      i += 1;
    } else if (CFStringIsSurrogateHighCharacter(c)
      || CFStringIsSurrogateLowCharacter(c)) {
      [o appendFormat:@"\\u%04x", c];
    } else {
      [o appendFormat:@"%C", c];
    }
  }
  [o appendString:@"\""];
  return o;
}

static NSString* shell_field_json(NSString* action, NSString* name,
  NSString* value) {
  return value == nil
    ? [NSString stringWithFormat:@"{\"action\":%@,\"name\":%@}",
      shell_quote(action), shell_quote(name)]
    : [NSString stringWithFormat:@"{\"action\":%@,\"name\":%@,\"value\":%@}",
      shell_quote(action), shell_quote(name), shell_quote(value)];
}

// Events

// The events a person made that Bend has not read yet (at most 256, as in
// shell.js), and per textbox the last edit Bend has read.
static pthread_mutex_t      shell_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t       shell_bell = PTHREAD_COND_INITIALIZER;
static NSMutableArray*      shell_events;
static NSMutableDictionary* shell_read;
static BOOL                 shell_waiting;
static BOOL                 shell_addressed;
static long                 shell_painted;
static atomic_int           shell_active;

static void shell_deliver(NSString* text, NSString* key, NSUInteger version) {
  pthread_mutex_lock(&shell_lock);
  if (shell_events.count < SHELL_EVENTS) {
    [shell_events addObject:@[text, key ?: @"", @(version)]];
  }
  pthread_cond_signal(&shell_bell);
  pthread_mutex_unlock(&shell_lock);
}

// Whether Bend has read the field's edit `version`.
static BOOL shell_has_read(NSString* key, NSUInteger version) {
  pthread_mutex_lock(&shell_lock);
  BOOL got = [shell_read[key] unsignedIntegerValue] >= version;
  pthread_mutex_unlock(&shell_lock);
  return got;
}

static char* shell_event(unsigned* status) {
  pthread_mutex_lock(&shell_lock);
  if (shell_waiting) {
    pthread_mutex_unlock(&shell_lock);
    *status = 2;
    return shell_dup(@"an event request is already pending");
  }
  NSString* text;
  if (shell_events.count == 0 && shell_painted == 0 && !shell_addressed) {
    shell_addressed = YES;
    text = [@"address · " stringByAppendingString:shell_address];
  } else {
    shell_waiting = YES;
    while (shell_events.count == 0) {
      pthread_cond_wait(&shell_bell, &shell_lock);
    }
    NSArray* e = shell_events[0];
    [shell_events removeObjectAtIndex:0];
    shell_waiting = NO;
    text = e[0];
    if ([e[1] length] != 0
      && [shell_read[e[1]] unsignedIntegerValue] < [e[2] unsignedIntegerValue]) {
      shell_read[e[1]] = e[2];
    }
  }
  pthread_mutex_unlock(&shell_lock);
  if (shell_trace) {
    shell_note("bend-event %s", shell_one(text).UTF8String);
  }
  *status = 1;
  return shell_dup(text);
}

// JSON values

static BOOL shell_is_bool(id x) {
  return [x isKindOfClass:NSNumber.class]
    && CFGetTypeID((__bridge CFTypeRef)x) == CFBooleanGetTypeID();
}

static BOOL shell_is_num(id x) {
  if (![x isKindOfClass:NSNumber.class] || shell_is_bool(x)) {
    return NO;
  }
  double v = [x doubleValue];
  return isfinite(v) && v >= 0 && v <= 4294967295.0;
}

// Fetch and post

// NSURLSession's completion-handler data task buffers the entire body. Its
// delegate form lets us enforce the browser's response limit as bytes arrive.
// Each fetch has a serial delegate queue; cancellation and session failure
// both complete through finish, which signals its blocked IO thread once.
@interface BendFetch : NSObject <NSURLSessionDataDelegate> {
  @public
  NSMutableData*        body;
  NSURLResponse*        response;
  NSError*              error;
  BOOL                  oversized;
  dispatch_semaphore_t  done;
  @private
  BOOL                  finished;
}
@end

@implementation BendFetch

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    body = [NSMutableData data];
    done = dispatch_semaphore_create(0);
  }
  return self;
}

- (void)finish:(NSError*)bad {
  if (!finished) {
    error = bad;
    finished = YES;
    dispatch_semaphore_signal(done);
  }
}

- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)task
  didReceiveResponse:(NSURLResponse*)got
  completionHandler:(void (^)(NSURLSessionResponseDisposition))complete {
  response = got;
  complete(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession*)session dataTask:(NSURLSessionDataTask*)task
  didReceiveData:(NSData*)data {
  if (finished || oversized) {
    return;
  }
  if (data.length > SHELL_LIMIT - body.length) {
    oversized = YES;
    [task cancel];
  } else {
    [body appendData:data];
  }
}

- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task
  didCompleteWithError:(NSError*)bad {
  [self finish:bad];
}

- (void)URLSession:(NSURLSession*)session didBecomeInvalidWithError:(NSError*)bad {
  [self finish:bad];
}

@end

// The response's text, as raw bytes (host.c reads them as UTF-8, as the
// browser's TextDecoder does).
static char* shell_bytes(NSData* d) {
  char* p = malloc(d.length + 1);
  if (p == NULL) {
    abort();
  }
  memcpy(p, d.bytes, d.length);
  p[d.length] = 0;
  return p;
}

static char* shell_fetch(unsigned op, NSString* text, unsigned* status) {
  NSString* href = text;
  NSData*   body = nil;
  *status = 2;
  if (op == 6) {
    NSError* err  = nil;
    id       spec = [NSJSONSerialization JSONObjectWithData:
      [text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err];
    if (![spec isKindOfClass:NSDictionary.class]) {
      return shell_dup(spec == nil ? [@"invalid JSON: "
        stringByAppendingString:err.localizedDescription ?: @""]
        : @"a post takes the JSON {url, body}");
    }
    href = [spec[@"url"] isKindOfClass:NSString.class] ? spec[@"url"] : @"";
    id b = spec[@"body"];
    if (b != nil) {
      body = [NSJSONSerialization dataWithJSONObject:b
        options:NSJSONWritingFragmentsAllowed
          | NSJSONWritingWithoutEscapingSlashes | NSJSONWritingSortedKeys
        error:&err];
      if (body == nil) {
        return shell_dup(err.localizedDescription ?: @"invalid body");
      }
    }
  }
  NSURL* url = shell_origin != nil
    ? [NSURL URLWithString:href relativeToURL:shell_origin].absoluteURL
    : [NSURL URLWithString:href];
  NSString* scheme = url.scheme.lowercaseString;
  if (url == nil || !([scheme isEqual:@"http"] || [scheme isEqual:@"https"])
    || url.host.length == 0) {
    return shell_dup([NSString stringWithFormat:@"Invalid URL: %@%@", href,
      shell_origin == nil && url.scheme == nil
        ? @" (a relative URL needs BendOrigin)" : @""]);
  }
  NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url
    cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
  if (op == 6) {
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = body;
  }
  if (shell_trace >= 2) {
    shell_note("bend-fetch %s %s", op == 6 ? "POST" : "GET",
      url.absoluteString.UTF8String);
  }
  BendFetch* stream = [BendFetch new];
  NSURLSessionConfiguration* config =
    NSURLSessionConfiguration.defaultSessionConfiguration;
  config.timeoutIntervalForRequest  = 30;
  config.timeoutIntervalForResource = 30;
  NSOperationQueue* queue = [NSOperationQueue new];
  queue.maxConcurrentOperationCount = 1;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:config
    delegate:stream delegateQueue:queue];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:req];
  [task resume];
  dispatch_semaphore_wait(stream->done, DISPATCH_TIME_FOREVER);
  [session finishTasksAndInvalidate];
  if (stream->oversized) {
    return shell_dup(@"response exceeds 1 MiB");
  }
  NSData* got = stream->body;
  NSURLResponse* res = stream->response;
  NSError* bad = stream->error;
  if (bad != nil) {
    BOOL late = bad.code == NSURLErrorTimedOut || bad.code == NSURLErrorCancelled;
    *status = late ? 3 : 2;
    return shell_dup(bad.code == NSURLErrorTimedOut ? @"request timeout"
      : bad.localizedDescription ?: @"fetch failed");
  }
  NSInteger code = [res isKindOfClass:NSHTTPURLResponse.class]
    ? ((NSHTTPURLResponse*)res).statusCode : 200;
  if (code < 200 || code > 299) {
    id j = got.length == 0 ? nil
      : [NSJSONSerialization JSONObjectWithData:got
        options:NSJSONReadingFragmentsAllowed error:NULL];
    id e = [j isKindOfClass:NSDictionary.class] ? j[@"error"] : nil;
    BOOL say = [e isKindOfClass:NSString.class] ? [e length] != 0
      : e != nil && e != NSNull.null && !(shell_is_num(e) && [e doubleValue] == 0)
        && !(shell_is_bool(e) && ![e boolValue]);
    return shell_dup(say ? ([e isKindOfClass:NSString.class] ? e
      : [e isKindOfClass:NSDictionary.class] ? @"[object Object]" : [e description])
      : [NSString stringWithFormat:@"HTTP %ld", (long)code]);
  }
  *status = 1;
  return shell_bytes(got ?: [NSData data]);
}

// The window
// ==========

@class BendShell, BendField;
static BendShell* shell;

@interface BendShell : NSObject <NSApplicationDelegate, NSWindowDelegate,
  NSTextFieldDelegate>
- (void)apply:(NSArray*)commands;
- (void)focused:(BendField*)field;
- (void)blurred:(BendField*)field;
- (void)scheme:(BOOL)dark;
- (void)configureWindow:(NSDictionary*)config;
@end

static NSColor* shell_ink(void) {
  return shell_dark
    ? [NSColor colorWithSRGBRed:0xf6 / 255.0 green:0xf7 / 255.0
      blue:0xf8 / 255.0 alpha:1]
    : [NSColor colorWithSRGBRed:0x10 / 255.0 green:0x11 / 255.0
      blue:0x12 / 255.0 alpha:1];
}

// A textbox's field: the browser's <input> (scene.bend's textbox_html):
// the system font at 17, padded 16 on each side, its text transparent over
// the text Bend draws. F's growing fields add 22-point lines above 50 points.
@interface BendFieldCell : NSTextFieldCell
@property BOOL growing;
@end

@implementation BendFieldCell

- (NSRect)drawingRectForBounds:(NSRect)r {
  if (self.growing) {
    NSRect d = NSInsetRect(r, 16, 14);
    d.size.width  = MAX(1, d.size.width);
    d.size.height = MAX(22, d.size.height);
    return d;
  }
  NSRect  d = [super drawingRectForBounds:NSInsetRect(r, 14, 0)];
  NSFont* f = self.font;
  CGFloat h = ceil(f.ascender - f.descender + f.leading);
  if (h < d.size.height) {
    d.origin.y   += floor((d.size.height - h) / 2);
    d.size.height = h;
  }
  return d;
}

- (NSText*)setUpFieldEditorAttributes:(NSText*)t {
  t = [super setUpFieldEditorAttributes:t];
  if ([t isKindOfClass:NSTextView.class]) {
    ((NSTextView*)t).insertionPointColor = shell_ink();
  }
  return t;
}

@end

@interface BendField : NSTextField
@property (copy) NSString*  key;
@property (copy) NSString*  name;
@property NSUInteger        version;
@property BOOL               editorGrowing;
- (void)fitEditor;
@end

@implementation BendField

+ (Class)cellClass {
  return BendFieldCell.class;
}

- (BOOL)becomeFirstResponder {
  BOOL ok = [super becomeFirstResponder];
  if (ok) {
    [self fitEditor];
    [shell focused:self];
  }
  return ok;
}

- (void)textDidBeginEditing:(NSNotification*)n {
  [super textDidBeginEditing:n];
  [self fitEditor];
}

// AppKit shares one field editor. A paint can grow or shrink its field
// while it is editing; update its container and viewport as well as the
// cell, keeping the text, selection and marked text in that editor.
- (void)fitEditor {
  NSText* text = self.currentEditor;
  if (![text isKindOfClass:NSTextView.class]) {
    return;
  }
  NSTextView* tv = (NSTextView*)text;
  BendFieldCell* cell = (BendFieldCell*)self.cell;
  NSRect d = [cell drawingRectForBounds:self.bounds];
  tv.insertionPointColor = shell_ink();
  tv.drawsBackground = NO;
  tv.textColor = shell_ink();
  NSMutableDictionary* attrs = [tv.typingAttributes mutableCopy];
  attrs[NSForegroundColorAttributeName] = shell_ink();
  tv.typingAttributes = attrs;
  if (tv.string.length != 0) {
    [tv.textStorage addAttribute:NSForegroundColorAttributeName
      value:shell_ink() range:NSMakeRange(0, tv.string.length)];
  }
  [self.superview setNeedsDisplay:YES];
  if (!cell.growing && !self.editorGrowing) {
    return;
  }
  self.editorGrowing = cell.growing;
  tv.horizontallyResizable = !cell.growing;
  tv.verticallyResizable   = cell.growing;
  tv.textContainerInset    = NSZeroSize;
  tv.textContainer.lineFragmentPadding = 0;
  tv.textContainer.widthTracksTextView = cell.growing;
  tv.textContainer.heightTracksTextView = NO;
  tv.minSize = NSMakeSize(d.size.width, d.size.height);
  tv.maxSize = cell.growing ? NSMakeSize(d.size.width, CGFLOAT_MAX)
    : NSMakeSize(CGFLOAT_MAX, d.size.height);
  NSMutableParagraphStyle* style = [NSParagraphStyle.defaultParagraphStyle mutableCopy];
  if (cell.growing) {
    style.minimumLineHeight = 22;
    style.maximumLineHeight = 22;
    style.lineBreakMode = NSLineBreakByWordWrapping;
  } else {
    style.lineBreakMode = NSLineBreakByClipping;
  }
  tv.defaultParagraphStyle = style;
  attrs = [tv.typingAttributes mutableCopy];
  attrs[NSParagraphStyleAttributeName] = style;
  tv.typingAttributes = attrs;
  if (tv.string.length != 0) {
    [tv.textStorage addAttribute:NSParagraphStyleAttributeName value:style
      range:NSMakeRange(0, tv.string.length)];
  }
  NSView* parent = tv.superview;
  if ([parent isKindOfClass:NSClipView.class] && parent.superview == self) {
    parent.frame = d;
    tv.frame = NSMakeRect(0, 0, d.size.width, d.size.height);
  } else if (parent == self) {
    tv.frame = d;
  }
  tv.textContainer.containerSize = NSMakeSize(cell.growing ? d.size.width
    : CGFLOAT_MAX, CGFLOAT_MAX);
  [tv scrollRangeToVisible:tv.selectedRange];
}

- (void)textDidEndEditing:(NSNotification*)n {
  [super textDidEndEditing:n];
  [self.superview setNeedsDisplay:YES];
  [shell blurred:self];
}

// The text as typed so far, marked (composing) text included.
- (NSString*)typed {
  NSText* ed = self.currentEditor;
  return ed != nil ? [ed.string copy] : self.stringValue;
}

@end

// The canvas: the last paint's commands, drawn by paint.c, and its regions.
@interface BendShellView : NSView
@property (strong) NSArray*                commands;
@property NSSize                           canvas;
@property (strong) NSArray<NSDictionary*>* regions;
@end

static NSString* shell_kind(NSDictionary* r) {
  NSString* k = [r[@"kind"] isKindOfClass:NSString.class] ? r[@"kind"] : nil;
  NSString* n = [r[@"name"] isKindOfClass:NSString.class] ? r[@"name"] : @"";
  return k ?: [n hasPrefix:@"textbox · "] ? @"textbox" : @"button";
}

static BOOL shell_enabled(NSDictionary* r) {
  return r[@"enabled"] == nil || [r[@"enabled"] boolValue];
}

static NSRect shell_rect(NSDictionary* r) {
  return NSMakeRect([r[@"x"] doubleValue], [r[@"y"] doubleValue],
    [r[@"w"] doubleValue], [r[@"h"] doubleValue]);
}

// The Canvas supplies the field's background, hint and resting text. While
// it is edited, AppKit owns both its actual glyph layout and caret, so they
// cannot disagree with F's estimated line widths or show a second caret.
static NSArray* shell_editor_commands(NSArray* commands, NSArray* textboxes,
  NSArray* editing) {
  NSMutableArray* projected = [NSMutableArray arrayWithCapacity:commands.count];
  for (NSArray* c in commands) {
    BOOL hide = NO;
    if (c.count >= 7 && [c[0] isEqual:@"shape"]
      && [c[6] isKindOfClass:NSArray.class]) {
      NSArray* shape = c[6];
      BOOL caret = [c[1] isEqual:@"Caret"];
      BOOL text = shape.count > 0 && [shape[0] isEqual:@"text"];
      if (caret || text) {
        NSRect bounds = NSMakeRect([c[2] doubleValue], [c[3] doubleValue],
          [c[4] doubleValue], [c[5] doubleValue]);
        for (NSValue* box in caret ? textboxes : editing) {
          if (NSIntersectsRect(bounds, box.rectValue)) {
            hide = YES;
            break;
          }
        }
      }
    }
    if (!hide) {
      [projected addObject:c];
    }
  }
  return projected.count == commands.count ? commands : projected;
}

@implementation BendShellView {
  NSInteger down;
  NSString* down_name;
}

- (BOOL)isFlipped {
  return YES;
}

- (BOOL)isOpaque {
  return NO;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)ev {
  return YES;
}

- (void)drawRect:(NSRect)dirty {
  if (self.commands == nil) {
    return;
  }
  NSMutableArray* textboxes = [NSMutableArray array];
  NSMutableArray* editing = [NSMutableArray array];
  for (NSView* child in self.subviews) {
    if ([child isKindOfClass:BendField.class]) {
      BendField* field = (BendField*)child;
      NSValue* bounds = [NSValue valueWithRect:field.frame];
      [textboxes addObject:bounds];
      if (field.currentEditor != nil && field.typed.length != 0) {
        [editing addObject:bounds];
      }
    }
  }
  bend_paint(NSGraphicsContext.currentContext.CGContext,
    shell_editor_commands(self.commands, textboxes, editing),
    self.bounds.size.width, self.bounds.size.height);
}

// The topmost region at p (the last painted), as renderer.js finds it.
- (NSInteger)regionAt:(NSPoint)p {
  for (NSInteger i = (NSInteger)self.regions.count - 1; i >= 0; i -= 1) {
    NSRect r = shell_rect(self.regions[i]);
    if (p.x >= r.origin.x && p.y >= r.origin.y && p.x < NSMaxX(r)
      && p.y < NSMaxY(r)) {
      return i;
    }
  }
  return -1;
}

- (void)mouseDown:(NSEvent*)ev {
  [self.window makeFirstResponder:self];
  down      = [self regionAt:[self convertPoint:ev.locationInWindow fromView:nil]];
  down_name = down >= 0 ? self.regions[down][@"name"] : nil;
}

// A click is a press and a release on one enabled region.
- (void)mouseUp:(NSEvent*)ev {
  NSInteger at = [self regionAt:[self convertPoint:ev.locationInWindow fromView:nil]];
  NSInteger was = down;
  down = -1;
  if (at < 0 || at != was) {
    return;
  }
  NSDictionary* r = self.regions[at];
  if ([r[@"name"] isEqual:down_name] && shell_enabled(r)
    && ![shell_kind(r) isEqual:@"textbox"]) {
    shell_deliver(r[@"name"], nil, 0);
  }
}

@end

// Snapshots

static void shell_snap(NSArray* cmds, long n) {
  NSString* file = [shell_snapshot stringByReplacingOccurrencesOfString:@"%d"
    withString:[NSString stringWithFormat:@"%ld", n]];
  if (!bend_paint_png(cmds, 0, 0, 2, file)) {
    shell_note("bend-snapshot %s: cannot write it", file.UTF8String);
  }
}

@implementation BendShell {
  NSWindow*                                   window;
  NSScrollView*                               scroll;
  BendShellView*                              view;
  NSMutableDictionary<NSString*, BendField*>* fields;
  NSMutableArray<NSString*>*                  script;
  long                                        paints;
  NSUInteger                                  watch;
  BOOL                                        painting;
  BOOL                                        sizing;
  BOOL                                        sized;
  BOOL                                        shown;
  BOOL                                        responsive;
  BOOL                                        resizeQueued;
  NSSize                                      sentViewport;
}

// Launch

- (void)applicationDidFinishLaunching:(NSNotification*)n {
  NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  [self menus];
  window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 390, 640)
    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
      | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
    backing:NSBackingStoreBuffered defer:NO];
  window.title                       = shell_name;
  window.releasedWhenClosed          = NO;
  window.backgroundColor             = NSColor.whiteColor;
  window.delegate                    = self;
  window.contentMinSize              = NSMakeSize(120, 80);
  window.autorecalculatesKeyViewLoop = NO;
  scroll = [[NSScrollView alloc] initWithFrame:window.contentView.bounds];
  scroll.autoresizingMask      = NSViewWidthSizable | NSViewHeightSizable;
  scroll.hasVerticalScroller   = YES;
  scroll.hasHorizontalScroller = YES;
  scroll.autohidesScrollers    = YES;
  scroll.backgroundColor       = NSColor.whiteColor;
  view = [[BendShellView alloc] initWithFrame:scroll.contentView.bounds];
  scroll.documentView = view;
  window.contentView  = scroll;
  window.initialFirstResponder = view;
  [window makeFirstResponder:view];
  scroll.contentView.postsFrameChangedNotifications = YES;
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(clipped:)
    name:NSViewFrameDidChangeNotification object:scroll.contentView];
  // paint.c loads a remote image in the background, then says so.
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(loaded:)
    name:@"BendPaintAssetsChanged" object:nil];
  [window center];
  fields = [NSMutableDictionary dictionary];
  script = [NSMutableArray array];
  const char* steps = getenv("BEND_INPUTS");
  for (NSString* s in [@(steps ?: "") componentsSeparatedByString:@"|"]) {
    if (s.length != 0) {
      [script addObject:s];
    }
  }
  [self watch:60];
  // A program that paints nothing still shows its window, after a moment.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
    dispatch_get_main_queue(), ^{
      [self show];
    });
  [self start];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)app {
  return YES;
}

- (void)menus {
  NSMenu*     bar  = [[NSMenu alloc] init];
  NSMenuItem* item = [bar addItemWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenu*     m    = [[NSMenu alloc] initWithTitle:shell_name];
  [m addItemWithTitle:[@"About " stringByAppendingString:shell_name]
    action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
  [m addItem:NSMenuItem.separatorItem];
  [m addItemWithTitle:[@"Hide " stringByAppendingString:shell_name]
    action:@selector(hide:) keyEquivalent:@"h"];
  [[m addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:)
    keyEquivalent:@"h"] setKeyEquivalentModifierMask:
      NSEventModifierFlagCommand | NSEventModifierFlagOption];
  [m addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:)
    keyEquivalent:@""];
  [m addItem:NSMenuItem.separatorItem];
  [m addItemWithTitle:[@"Quit " stringByAppendingString:shell_name]
    action:@selector(terminate:) keyEquivalent:@"q"];
  item.submenu = m;
  item = [bar addItemWithTitle:@"" action:nil keyEquivalent:@""];
  m    = [[NSMenu alloc] initWithTitle:@"Edit"];
  [m addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
  [m addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
  [m addItem:NSMenuItem.separatorItem];
  [m addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [m addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [m addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [m addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  item.submenu = m;
  item = [bar addItemWithTitle:@"" action:nil keyEquivalent:@""];
  m    = [[NSMenu alloc] initWithTitle:@"Window"];
  [m addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:)
    keyEquivalent:@"m"];
  [m addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
  [[m addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:)
    keyEquivalent:@"f"] setKeyEquivalentModifierMask:
      NSEventModifierFlagCommand | NSEventModifierFlagControl];
  [m addItemWithTitle:@"Close" action:@selector(performClose:) keyEquivalent:@"w"];
  item.submenu    = m;
  NSApp.windowsMenu = m;
  NSApp.mainMenu    = bar;
}

static void* shell_run(void* arg) {
  (void)arg;
  int code = bend_main(shell_argc, shell_argv);
  fflush(stdout);
  if (shell_trace) {
    shell_note("bend-exit %d", code);
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    exit(code);
  });
  return NULL;
}

// bend_main(<exe> [--threads N] --gpu off -- <launch args>) on its own
// thread.
- (void)start {
  const char* thr = getenv("BEND_THREADS");
  int         n   = 0;
  char**      av  = calloc((size_t)shell_argc + 8, sizeof(char*));
  av[n++] = shell_argv[0];
  if (thr != NULL && *thr != 0) {
    av[n++] = "--threads";
    av[n++] = (char*)thr;
  }
  av[n++] = "--gpu";
  av[n++] = "off";
  av[n++] = "--";
  for (int i = 1; i < shell_argc; i += 1) {
    if (strncmp(shell_argv[i], "-psn_", 5) != 0) {
      av[n++] = shell_argv[i];
    }
  }
  shell_argc = n;
  shell_argv = av;
  pthread_attr_t at;
  pthread_attr_init(&at);
  pthread_attr_setstacksize(&at, 8u << 20);
  pthread_t tid;
  if (pthread_create(&tid, &at, shell_run, NULL) != 0) {
    shell_note("bend-shell: pthread_create failed");
    exit(1);
  }
  pthread_attr_destroy(&at);
}

- (void)show {
  if (shown || shell_hidden) {
    return;
  }
  shown = YES;
  [window makeKeyAndOrderFront:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [NSApp activateIgnoringOtherApps:YES];
#pragma clang diagnostic pop
}

// Size

// The window takes the frame's size (within the screen) at the first paint,
// and later ones', its top left kept, until a person sizes it.
- (void)fit:(NSSize)canvas {
  if (!responsive && (paints == 1 || !sized)) {
    NSRect  vis  = (window.screen ?: NSScreen.mainScreen).visibleFrame;
    NSRect  want = [window frameRectForContentRect:NSMakeRect(0, 0,
      MAX(canvas.width, 120), MAX(canvas.height, 80))];
    CGFloat top  = NSMaxY(window.frame);
    want.size.width  = MIN(want.size.width, vis.size.width);
    want.size.height = MIN(want.size.height, vis.size.height);
    if (paints == 1) {
      want.origin.x = NSMidX(vis) - want.size.width / 2;
      want.origin.y = NSMidY(vis) - want.size.height / 2 + vis.size.height / 8;
      want.origin.y = MIN(want.origin.y, NSMaxY(vis) - want.size.height);
    } else {
      want.origin.x = window.frame.origin.x;
      want.origin.y = top - want.size.height;
    }
    want.origin.y = MAX(want.origin.y, vis.origin.y);
    if (!NSEqualRects(want, window.frame)) {
      sizing = YES;
      [window setFrame:want display:YES];
      sizing = NO;
    }
  }
  [self document];
}

- (void)document {
  NSSize clip = scroll.contentView.bounds.size;
  NSSize want = NSMakeSize(MAX(view.canvas.width, clip.width),
    MAX(view.canvas.height, clip.height));
  if (!NSEqualSizes(want, view.frame.size)) {
    [view setFrameSize:want];
  }
}

- (void)clipped:(NSNotification*)n {
  [self document];
  [self viewport];
}

// Keep only the latest consecutive resize while Bend is painting; typed and
// clicked events keep their order. The clip's bounds are exactly the Canvas
// viewport, including the space AppKit reserves for a non-overlay scroller.
- (void)viewport {
  if (!responsive || sizing || resizeQueued) {
    return;
  }
  resizeQueued = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    self->resizeQueued = NO;
    NSSize size = self->scroll.contentView.bounds.size;
    size.width  = MAX(1, floor(size.width));
    size.height = MAX(1, floor(size.height));
    if (NSEqualSizes(size, self->sentViewport)) {
      return;
    }
    self->sentViewport = size;
    NSString* text = [NSString stringWithFormat:
      @"{\"action\":\"resize\",\"width\":%.0f,\"height\":%.0f}",
      size.width, size.height];
    pthread_mutex_lock(&shell_lock);
    NSArray* last = shell_events.lastObject;
    if (last != nil && [last[0] hasPrefix:@"{\"action\":\"resize\","]) {
      shell_events[shell_events.count - 1] = @[text, @"", @0];
    } else if (shell_events.count < SHELL_EVENTS) {
      [shell_events addObject:@[text, @"", @0]];
    }
    pthread_cond_signal(&shell_bell);
    pthread_mutex_unlock(&shell_lock);
  });
}

- (void)configureWindow:(NSDictionary*)config {
  responsive = YES;
  sizing = YES;
  window.contentMinSize = NSMakeSize([config[@"min_width"] doubleValue],
    [config[@"min_height"] doubleValue]);
  NSRect vis = (window.screen ?: NSScreen.mainScreen).visibleFrame;
  NSSize initial = NSMakeSize(MAX([config[@"width"] doubleValue],
      window.contentMinSize.width), MAX([config[@"height"] doubleValue],
      window.contentMinSize.height));
  NSRect frame = [window frameRectForContentRect:NSMakeRect(0, 0,
    initial.width, initial.height)];
  frame.size.width = MIN(frame.size.width, vis.size.width);
  frame.size.height = MIN(frame.size.height, vis.size.height);
  frame.origin = NSMakePoint(NSMidX(vis) - frame.size.width / 2,
    NSMidY(vis) - frame.size.height / 2);
  [window setFrame:frame display:YES];
  sizing = NO;
  [self document];
  [self viewport];
}

- (void)loaded:(NSNotification*)n {
  [view setNeedsDisplay:YES];
}

- (void)scheme:(BOOL)dark {
  shell_dark = dark;
  NSApp.appearance = [NSAppearance appearanceNamed:dark
    ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
  NSColor* background = dark ? NSColor.blackColor : NSColor.whiteColor;
  window.backgroundColor = background;
  scroll.backgroundColor = background;
  bend_paint_set_dark(dark);
  [view setNeedsDisplay:YES];
}

- (void)windowDidResize:(NSNotification*)n {
  if (!sizing && paints > 0) {
    sized = YES;
  }
  [self document];
  [self viewport];
}

// Paint

- (void)apply:(NSArray*)cmds {
  NSArray* frame = cmds[0];
  NSSize   size  = NSMakeSize([frame[1] doubleValue], [frame[2] doubleValue]);
  paints += 1;
  watch  += 1;
  pthread_mutex_lock(&shell_lock);
  shell_painted = paints;
  pthread_mutex_unlock(&shell_lock);
  NSArray* regions = bend_paint_regions(cmds) ?: @[];
  painting = YES;
  view.commands = cmds;
  view.canvas   = size;
  view.regions  = regions;
  [self fit:size];
  [view setNeedsDisplay:YES];
  NSMutableArray*      fresh = [NSMutableArray array];
  NSMutableDictionary* next  = [NSMutableDictionary dictionary];
  NSCountedSet*        seen  = [NSCountedSet set];
  for (NSDictionary* r in regions) {
    if (![shell_kind(r) isEqual:@"textbox"]) {
      continue;
    }
    NSString* name = [r[@"name"] isKindOfClass:NSString.class] ? r[@"name"] : @"";
    NSUInteger k = [seen countForObject:name];
    [seen addObject:name];
    NSString*  key   = k == 0 ? name : [NSString stringWithFormat:@"%@#%lu", name, k];
    NSString*  value = [r[@"value"] isKindOfClass:NSString.class] ? r[@"value"] : nil;
    BendField* f     = fields[key];
    if (f == nil) {
      f = [self field:name key:key];
      f.stringValue = value ?: @"";
      [fresh addObject:f];
    } else if (value != nil && f.currentEditor == nil
      && shell_has_read(key, f.version) && ![f.stringValue isEqual:value]) {
      f.stringValue = value;
    }
    NSRect bounds = shell_rect(r);
    BOOL growing = bounds.size.height > 50;
    ((BendFieldCell*)f.cell).growing = growing;
    f.usesSingleLineMode = !growing;
    f.lineBreakMode = growing ? NSLineBreakByWordWrapping : NSLineBreakByClipping;
    f.cell.scrollable = !growing;
    f.cell.wraps = growing;
    f.frame   = bounds;
    f.enabled = shell_enabled(r);
    [f fitEditor];
    next[key] = f;
  }
  for (NSString* key in fields) {
    if (next[key] == nil) {
      [fields[key] removeFromSuperview];
    }
  }
  fields   = next;
  painting = NO;
  for (BendField* f in fresh) {
    [self restore:f];
  }
  if (shell_trace) {
    shell_note("bend-paint %ld %gx%g", paints, size.width, size.height);
    for (id t in bend_paint_texts(cmds) ?: @[]) {
      shell_note("bend-text %ld %s", paints, shell_one([t description]).UTF8String);
    }
  }
  if (shell_trace >= 2) {
    for (NSDictionary* r in regions) {
      NSRect b = shell_rect(r);
      shell_note("bend-region %ld %s %s %g,%g %gx%g %s", paints,
        shell_kind(r).UTF8String, shell_enabled(r) ? "on" : "off", b.origin.x,
        b.origin.y, b.size.width, b.size.height, shell_one(r[@"name"] ?: @"").UTF8String);
    }
  }
  if (shell_snapshot != nil) {
    shell_snap(cmds, paints);
  }
  [self show];
  [self step];
}

- (BendField*)field:(NSString*)name key:(NSString*)key {
  BendField* f = [[BendField alloc] initWithFrame:NSZeroRect];
  f.key                = key;
  f.name               = name;
  f.bezeled            = NO;
  f.bordered           = NO;
  f.drawsBackground    = NO;
  f.editable           = YES;
  f.selectable         = YES;
  f.focusRingType      = NSFocusRingTypeNone;
  f.font               = [NSFont systemFontOfSize:17];
  f.textColor          = NSColor.clearColor;
  f.usesSingleLineMode = YES;
  f.lineBreakMode      = NSLineBreakByClipping;
  f.cell.scrollable    = YES;
  f.cell.wraps         = NO;
  f.delegate           = self;
  f.accessibilityLabel = [name hasPrefix:@"textbox · "]
    ? [name substringFromIndex:10] : name;
  [view addSubview:f];
  return f;
}

// Textboxes

- (void)edited:(BendField*)f text:(NSString*)text {
  f.version += 1;
  shell_deliver(shell_field_json(@"field", f.name, text), f.key, f.version);
  if (shell_persist) {
    NSString* k = [@"bend-input:" stringByAppendingString:f.name];
    if (text.length != 0) {
      [NSUserDefaults.standardUserDefaults setObject:text forKey:k];
    } else {
      [NSUserDefaults.standardUserDefaults removeObjectForKey:k];
    }
  }
}

- (void)restore:(BendField*)f {
  if (!shell_persist || f.stringValue.length != 0) {
    return;
  }
  NSString* text = [NSUserDefaults.standardUserDefaults
    stringForKey:[@"bend-input:" stringByAppendingString:f.name]];
  if (text.length != 0) {
    f.stringValue = text;
    [self edited:f text:text];
  }
}

- (void)controlTextDidChange:(NSNotification*)n {
  if ([n.object isKindOfClass:BendField.class]) {
    BendField* f = n.object;
    [self edited:f text:[f typed]];
  }
}

// Return and Escape do nothing in a textbox, as in the browser's <input>.
- (BOOL)control:(NSControl*)c textView:(NSTextView*)tv
  doCommandBySelector:(SEL)sel {
  return sel == @selector(insertNewline:) || sel == @selector(cancelOperation:)
    || sel == @selector(complete:) || sel == @selector(insertLineBreak:);
}

- (void)focused:(BendField*)f {
  if (!painting) {
    shell_deliver(shell_field_json(@"focus", f.name, nil), nil, 0);
  }
}

- (void)blurred:(BendField*)f {
  if (!painting) {
    shell_deliver(shell_field_json(@"blur", f.name, nil), nil, 0);
  }
}

// Scripts

- (void)watch:(int)seconds {
  if (!shell_exit) {
    return;
  }
  NSUInteger was = watch;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC),
    dispatch_get_main_queue(), ^{
      if (self->watch == was) {
        shell_note("bend-script-stall no paint in %d s", seconds);
        fflush(stdout);
        exit(4);
      }
    });
}

- (void)miss:(NSString*)step why:(NSString*)why {
  NSMutableArray* names = [NSMutableArray array];
  for (NSDictionary* r in view.regions) {
    [names addObject:[NSString stringWithFormat:@"%@%@", r[@"name"] ?: @"",
      shell_enabled(r) ? @"" : @" (disabled)"]];
  }
  shell_note("bend-script-miss %s: %s; the regions: %s", shell_one(step).UTF8String,
    why.UTF8String, shell_one([names componentsJoinedByString:@" | "]).UTF8String);
  [script removeAllObjects];
  if (shell_exit) {
    fflush(stdout);
    exit(3);
  }
}

// The region a step's label names: its whole name, or its name after the
// role ("button · Send": Send).
- (NSDictionary*)region:(NSString*)label textbox:(BOOL)box {
  NSDictionary* got = nil;
  for (NSDictionary* r in view.regions) {
    NSString* n = [r[@"name"] isKindOfClass:NSString.class] ? r[@"name"] : @"";
    NSRange   d = [n rangeOfString:@" · "];
    NSString* l = d.location == NSNotFound ? n
      : [n substringFromIndex:NSMaxRange(d)];
    if ([shell_kind(r) isEqual:@"textbox"] == box
      && ([n isEqual:label] || [l isEqual:label])) {
      got = r;
    }
  }
  return got;
}

- (BendField*)fieldFor:(NSDictionary*)r {
  for (BendField* f in fields.allValues) {
    if ([f.name isEqual:r[@"name"]] && NSEqualRects(f.frame, shell_rect(r))) {
      return f;
    }
  }
  return nil;
}

// After a paint: the next step, or, past the last one, the exit asked for.
- (void)step {
  if (script.count == 0) {
    if (shell_exit) {
      fflush(stdout);
      exit(0);
    }
    return;
  }
  NSString* step = script[0];
  [script removeObjectAtIndex:0];
  NSRange   c    = [step rangeOfString:@":"];
  NSString* verb = c.location == NSNotFound ? step : [step substringToIndex:c.location];
  NSString* arg  = c.location == NSNotFound ? @"" : [step substringFromIndex:NSMaxRange(c)];
  if (shell_trace) {
    shell_note("bend-step %s", shell_one(step).UTF8String);
  }
  if ([verb isEqual:@"click"]) {
    NSDictionary* r = [self region:arg textbox:NO];
    if (r == nil || !shell_enabled(r)) {
      return [self miss:step why:r == nil ? @"no such button" : @"it is disabled"];
    }
    shell_deliver(r[@"name"], nil, 0);
  } else if ([verb isEqual:@"type"] || [verb isEqual:@"focus"]
    || [verb isEqual:@"blur"]) {
    NSRange   eq    = [arg rangeOfString:@"="];
    BOOL      type  = [verb isEqual:@"type"];
    NSString* label = type && eq.location != NSNotFound
      ? [arg substringToIndex:eq.location] : arg;
    BendField* f = [self fieldFor:[self region:label textbox:YES]];
    if (f == nil || (type && eq.location == NSNotFound)) {
      return [self miss:step why:f == nil ? @"no such textbox" : @"type:<label>=<text>"];
    }
    if (type) {
      NSString* text = [arg substringFromIndex:NSMaxRange(eq)];
      f.stringValue = text;
      [self edited:f text:text];
    } else {
      shell_deliver(shell_field_json(verb, f.name, nil), nil, 0);
    }
  } else if ([verb isEqual:@"address"]) {
    shell_deliver([@"address · " stringByAppendingString:arg], nil, 0);
  } else {
    return [self miss:step why:@"steps are click:, type:, focus:, blur:, address:"];
  }
  [self watch:30];
}

@end

// Requests
// ========

static char* shell_paint(const char* data, unsigned len, unsigned* status) {
  NSError* err  = nil;
  id       cmds = [NSJSONSerialization JSONObjectWithData:
    [NSData dataWithBytesNoCopy:(void*)data length:len freeWhenDone:NO]
    options:0 error:&err];
  NSString* why = cmds == nil ? [@"invalid canvas JSON: "
    stringByAppendingString:err.localizedDescription ?: @""]
    : bend_paint_check(cmds) ?: bend_paint_prepare(cmds);
  if (why != nil) {
    *status = 2;
    return shell_dup(why);
  }
  dispatch_sync(dispatch_get_main_queue(), ^{
    [shell apply:cmds];
  });
  *status = 1;
  return shell_dup(@"");
}

char* bend_native_request(unsigned op, const char* data, unsigned len,
  unsigned* status) {
  @autoreleasepool {
    if (atomic_fetch_add(&shell_active, 1) >= SHELL_ACTIVE) {
      atomic_fetch_sub(&shell_active, 1);
      *status = 2;
      return shell_dup(@"too many pending requests");
    }
    if (shell_trace >= 2) {
      shell_note("bend-request %u %u", op, len);
    }
    char* reply;
    *status = 2;
    if (op == 2) {
      reply = shell_event(status);
    } else if (op == 4) {
      reply = shell_paint(data, len, status);
    } else if (op == 3 || op == 6) {
      NSString* text = [[NSString alloc] initWithBytes:data length:len
        encoding:NSUTF8StringEncoding];
      reply = shell_fetch(op, text ?: @"", status);
    } else if (op == 7 && len == 1 && (data[0] == '0' || data[0] == '1')) {
      const char* forced = getenv("BEND_NO_PERSIST");
      BOOL enabled = data[0] == '1'
        && !(forced != NULL && strcmp(forced, "1") == 0);
      dispatch_sync(dispatch_get_main_queue(), ^{
        shell_persist = enabled;
      });
      *status = 1;
      reply = shell_dup(@"");
    } else if (op == 8 && ((len == 4 && memcmp(data, "dark", 4) == 0)
      || (len == 5 && memcmp(data, "light", 5) == 0))) {
      BOOL dark = len == 4;
      dispatch_sync(dispatch_get_main_queue(), ^{
        [shell scheme:dark];
      });
      *status = 1;
      reply = shell_dup(@"");
    } else if (op == 9) {
      id config = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithBytesNoCopy:(void*)data length:len freeWhenDone:NO]
        options:0 error:NULL];
      BOOL valid = [config isKindOfClass:NSDictionary.class];
      for (NSString* key in @[@"width", @"height", @"min_width", @"min_height"]) {
        id value = valid ? config[key] : nil;
        double number = [value isKindOfClass:NSNumber.class]
          ? [value doubleValue] : 0;
        valid = valid && shell_is_num(value) && number >= 1
          && number <= 100000 && floor(number) == number;
      }
      if (valid) {
        dispatch_sync(dispatch_get_main_queue(), ^{
          [shell configureWindow:config];
        });
        *status = 1;
        reply = shell_dup(@"");
      } else {
        reply = shell_dup(@"window dimensions must be positive integer content points");
      }
    } else {
      reply = shell_dup([NSString stringWithFormat:
        @"unsupported native operation %u", op]);
    }
    atomic_fetch_sub(&shell_active, 1);
    return reply;
  }
}

// Main
// ====

// Launched by Finder or open, stdout and stderr are /dev/null: they go to
// ~/Library/Logs/<name>.log instead, and a launch at / works in the app's
// Application Support folder.
static void shell_home(void) {
  struct stat out, null;
  if (fstat(STDOUT_FILENO, &out) == 0 && stat("/dev/null", &null) == 0
    && S_ISCHR(out.st_mode) && out.st_rdev == null.st_rdev) {
    NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir
      withIntermediateDirectories:YES attributes:nil error:NULL];
    int fd = open([dir stringByAppendingPathComponent:[shell_name
      stringByAppendingString:@".log"]].fileSystemRepresentation,
      O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd >= 0) {
      struct stat err;
      dup2(fd, STDOUT_FILENO);
      if (fstat(STDERR_FILENO, &err) == 0 && S_ISCHR(err.st_mode)
        && err.st_rdev == null.st_rdev) {
        dup2(fd, STDERR_FILENO);
      }
      close(fd);
    }
  }
  setvbuf(stdout, NULL, _IOLBF, BUFSIZ);
  char cwd[2];
  if (getcwd(cwd, sizeof cwd) != NULL && strcmp(cwd, "/") == 0) {
    NSString* id  = NSBundle.mainBundle.bundleIdentifier ?: shell_name;
    NSString* dir = [[NSHomeDirectory() stringByAppendingPathComponent:
      @"Library/Application Support"] stringByAppendingPathComponent:id];
    [NSFileManager.defaultManager createDirectoryAtPath:dir
      withIntermediateDirectories:YES attributes:nil error:NULL];
    if (chdir(dir.fileSystemRepresentation) != 0) {
      shell_note("bend-shell: cannot enter %s", dir.UTF8String);
    }
  }
}

static void shell_config(void) {
  NSDictionary* info = NSBundle.mainBundle.infoDictionary;
  shell_name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"]
    ?: NSProcessInfo.processInfo.processName;
  const char* v;
  shell_trace     = (v = getenv("BEND_TRACE")) != NULL ? atoi(v) : 0;
  shell_persist   = !((v = getenv("BEND_NO_PERSIST")) != NULL && strcmp(v, "1") == 0);
  shell_exit      = (v = getenv("BEND_EXIT")) != NULL && strcmp(v, "1") == 0;
  shell_hidden    = (v = getenv("BEND_HIDDEN")) != NULL && strcmp(v, "1") == 0;
  if ((v = getenv("BEND_SNAPSHOT")) != NULL && *v != 0) {
    shell_snapshot = [NSURL fileURLWithPath:@(v)].path;
  }
  if ((v = getenv("BEND_ADDRESS")) != NULL && *v != 0) {
    shell_address = @(v);
  }
  NSString* origin = (v = getenv("BEND_ORIGIN")) != NULL && *v != 0 ? @(v)
    : [info[@"BendOrigin"] isKindOfClass:NSString.class] ? info[@"BendOrigin"] : nil;
  shell_origin = origin != nil ? [NSURL URLWithString:origin] : nil;
  shell_events = [NSMutableArray array];
  shell_read   = [NSMutableDictionary dictionary];
}

int main(int argc, char** argv) {
  @autoreleasepool {
    shell_argc = argc;
    shell_argv = argv;
    shell_config();
    shell_home();
    NSApplication* app = NSApplication.sharedApplication;
    app.activationPolicy = shell_hidden ? NSApplicationActivationPolicyAccessory
      : NSApplicationActivationPolicyRegular;
    shell = [[BendShell alloc] init];
    app.delegate = shell;
    [app run];
  }
  return 0;
}
