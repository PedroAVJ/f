// Native Canvas painter
// =====================

// The CoreGraphics and CoreText port of ../browser/renderer.js: it paints the
// op-4 packet (Scene.canvas: frame, clear, shape and region commands) exactly
// as the browser's canvas does, and nothing else. Positions, token colours,
// text and sprite frames are values produced by Bend; this file only applies
// drawing operations. Compiled as Objective-C (ARC) next to apple/shell.c; no
// header: the shell declares the prototypes it uses.
//
//   void      bend_paint(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height);
//   NSArray*  bend_paint_regions(NSArray* commands);   // NSDictionary per region, paint order
//   NSArray*  bend_paint_texts(NSArray* commands);     // NSString per text shape, paint order
//   NSString* bend_paint_check(NSArray* commands);     // nil, or renderer.js's error for the packet
//   CGSize    bend_paint_size(NSArray* commands);      // the frame's size (zero without one)
//   NSString* bend_paint_prepare(NSArray* commands);   // loads its images (blocking); nil or the error
//   BOOL      bend_paint_png(NSArray* commands, CGFloat width, CGFloat height, CGFloat scale, NSString* path);
//   void      bend_paint_set_dark(BOOL enabled);       // explicit native page background
//
// bend_paint draws in points with a top-left origin (a flipped view, or a
// bitmap context flipped by its caller): the configured page background
// (white by default) over width x height,
// then the frame at (0,0). It renders the canvas into its own bitmap at the
// context's device scale, so shadows, blurs and glass read and write real
// pixels as the browser's canvas does, whatever context it is given.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#endif
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>
#include <xlocale.h>

// Values
// ------

// JSON crosses as NSJSONSerialization values. As in renderer.js: a number is
// finite in [0, 2^32-1]; booleans are not numbers; numeric strings are JS
// Number() of the text.
#define BP_MAX 4096
#define BP_SHAPE_LIMIT 16777216.0

static BOOL bp_is_bool(id x) {
  return [x isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)x) == CFBooleanGetTypeID();
}
static BOOL bp_is_num(id x) {
  return [x isKindOfClass:NSNumber.class] && !bp_is_bool(x);
}
static BOOL bp_in_range(double v) {
  return isfinite(v) && v >= 0 && v <= 4294967295.0;
}
static BOOL bp_number(id x) {
  return bp_is_num(x) && bp_in_range([x doubleValue]);
}
static BOOL bp_string(id x) {
  return [x isKindOfClass:NSString.class];
}
static BOOL bp_array(id x) {
  return [x isKindOfClass:NSArray.class];
}
static double bp_strtod(const char* s, size_t n, size_t* used) {
  char small[64];
  char* buf = n < sizeof small ? small : malloc(n + 1);
  memcpy(buf, s, n);
  buf[n] = 0;
  char* end = buf;
  double v = strtod_l(buf, &end, LC_C_LOCALE);
  *used = (size_t)(end - buf);
  if (buf != small) free(buf);
  return v;
}
// JS Number(text): trimmed, empty is 0, or a whole decimal/radix literal.
static double bp_js_number(NSString* s) {
  NSString* t = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (t.length == 0) return 0;
  const char* c = t.UTF8String;
  size_t n = strlen(c);
  if (n > 2 && c[0] == '0') {
    int base = c[1] == 'x' || c[1] == 'X' ? 16 : c[1] == 'o' || c[1] == 'O' ? 8 : c[1] == 'b' || c[1] == 'B' ? 2 : 0;
    if (base) {
      double v = 0;
      for (size_t i = 2; i < n; i++) {
        char ch = c[i];
        int d = ch >= '0' && ch <= '9' ? ch - '0' : ch >= 'a' && ch <= 'f' ? ch - 'a' + 10 : ch >= 'A' && ch <= 'F' ? ch - 'A' + 10 : -1;
        if (d < 0 || d >= base) return NAN;
        v = v * base + d;
      }
      return v;
    }
  }
  for (size_t i = 0; i < n; i++) {
    if (!strchr("0123456789+-.eE", c[i])) return NAN;
  }
  size_t used = 0;
  double v = bp_strtod(c, n, &used);
  return used == n ? v : NAN;
}
static BOOL bp_numeric(id x) {
  if (bp_string(x)) return bp_in_range(bp_js_number(x));
  return bp_number(x);
}
static double bp_value(id x) {
  if (bp_string(x)) return bp_js_number(x);
  return bp_is_num(x) ? [x doubleValue] : 0;
}
// renderer.js's isStrokeWidth: /^\+?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$/
static BOOL bp_stroke_width(id x) {
  if (!bp_string(x)) return NO;
  const char* s = [x UTF8String];
  const char* p = s;
  if (*p == '+') p++;
  const char* d = p;
  while (*p >= '0' && *p <= '9') p++;
  BOOL whole = p > d;
  if (whole && *p == '.') {
    p++;
    while (*p >= '0' && *p <= '9') p++;
  } else if (!whole) {
    if (*p != '.') return NO;
    p++;
    const char* f = p;
    while (*p >= '0' && *p <= '9') p++;
    if (p == f) return NO;
  }
  if (*p == 'e' || *p == 'E') {
    p++;
    if (*p == '+' || *p == '-') p++;
    const char* e = p;
    while (*p >= '0' && *p <= '9') p++;
    if (p == e) return NO;
  }
  return *p == 0 && bp_in_range(bp_js_number(x));
}

// Each unsupported kind (and each rejected packet's reason) is reported
// once, on stderr: "bend-unsupported <kind>", "bend-paint-invalid <reason>".
static void bp_once(const char* tag, NSString* what) {
  static NSMutableSet* seen;
  NSString* line = [NSString stringWithFormat:@"%s %@", tag, what];
  @synchronized (NSNull.null) {
    if (!seen) seen = [NSMutableSet set];
    if ([seen containsObject:line]) return;
    [seen addObject:line];
  }
  fprintf(stderr, "%s\n", line.UTF8String);
  fflush(stderr);
}
static void bp_unsupported(NSString* kind) {
  bp_once("bend-unsupported", kind);
}

// Validation
// ----------

// The same checks, in the same order and with the same messages, as
// renderer.js's paint: a packet it would reject is rejected here.
static NSString* bp_check_shape(NSArray* c) {
  if (c.count != 10 || !bp_string(c[1]) || !bp_number(c[2]) || !bp_number(c[3]) || !bp_number(c[4]) || !bp_number(c[5]) ||
      !bp_array(c[6]) || !bp_array(c[7]) || !bp_array(c[8]) || !bp_array(c[9])) return @"invalid F shape packet";
  NSArray* g = c[6];
  NSArray* f = c[7];
  NSArray* s = c[8];
  NSArray* e = c[9];
  id gk = g.count ? g[0] : nil;
  if ([gk isEqual:@"rounded"]) {
    if (g.count != 4 || !bp_number(g[1]) || !bp_number(g[2]) || !bp_number(g[3])) return @"invalid Rounded geometry";
  } else if ([gk isEqual:@"text"]) {
    if ((g.count != 4 && g.count != 5) || !bp_string(g[1]) || !bp_number(g[2]) || !bp_number(g[3]) || (g.count == 5 && ![g[4] isEqual:@"monospace"])) return @"invalid Text geometry";
  } else if ([gk isEqual:@"path"]) {
    if (g.count != 2 || !bp_array(g[1]) || [g[1] count] > BP_MAX) return @"invalid Path geometry";
    for (id p in g[1]) {
      if (!bp_array(p)) return @"invalid symbol path";
      NSArray* q = p;
      if (q.count == 2 && [q[0] isEqual:@"path"] && bp_string(q[1])) continue;
      if (q.count == 4 && [q[0] isEqual:@"circle"] && bp_numeric(q[1]) && bp_numeric(q[2]) && bp_numeric(q[3])) continue;
      return @"invalid symbol path";
    }
  } else return @"unsupported F geometry";
  id fk = f.count ? f[0] : nil;
  if ([fk isEqual:@"none"] && f.count == 1) {
  } else if ([fk isEqual:@"solid"] && f.count == 2 && bp_string(f[1])) {
  } else if ([fk isEqual:@"gradient"] && f.count == 4 && bp_string(f[1]) && bp_string(f[2]) && bp_number(f[3]) && [f[3] doubleValue] <= 100) {
  } else if ([fk isEqual:@"photo"] && f.count == 4 && bp_string(f[1]) && bp_number(f[2]) && bp_number(f[3])) {
  } else if ([fk isEqual:@"atlas"] && f.count == 8 && bp_string(f[1]) && bp_number(f[2]) && bp_number(f[3]) && bp_number(f[4]) &&
             bp_number(f[5]) && bp_number(f[6]) && bp_number(f[7])) {
  } else return @"invalid F fill";
  id sk = s.count ? s[0] : nil;
  if (!([sk isEqual:@"none"] && s.count == 1) && !([sk isEqual:@"stroke"] && s.count == 3 && bp_string(s[1]) && bp_stroke_width(s[2])))
    return @"invalid F stroke";
  if (e.count > BP_MAX) return @"too many F effects";
  for (id x in e) {
    NSArray* q = bp_array(x) ? x : @[];
    id k = q.count ? q[0] : nil;
    if ([k isEqual:@"blur"] && q.count == 2 && bp_number(q[1])) continue;
    if ([k isEqual:@"shadow"] && q.count == 4 && bp_number(q[1]) && bp_number(q[2]) && bp_string(q[3])) continue;
    if ([k isEqual:@"glass"] && q.count == 7 && bp_number(q[1]) && bp_number(q[2]) && bp_number(q[3]) && bp_number(q[4]) &&
        bp_number(q[5]) && bp_string(q[6]) && [gk isEqual:@"rounded"]) continue;
    return @"invalid F effect";
  }
  return nil;
}
static BOOL bp_integer(id x) {
  return bp_is_num(x) && isfinite([x doubleValue]) && [x doubleValue] == floor([x doubleValue]);
}
NSString* bend_paint_check(NSArray* commands) {
  if (!bp_array(commands) || commands.count > BP_MAX) return @"invalid canvas command list";
  NSUInteger frames = 0;
  for (id x in commands) {
    if (!bp_array(x)) return @"invalid canvas command";
    NSArray* c = x;
    id k = c.count ? c[0] : nil;
    if ([k isEqual:@"shape"]) {
      NSString* e = bp_check_shape(c);
      if (e) return e;
    } else if ([k isEqual:@"frame"] && c.count == 3 && bp_integer(c[1]) && bp_integer(c[2]) && [c[1] doubleValue] >= 0 &&
               [c[1] doubleValue] <= 16384 && [c[2] doubleValue] >= 0 && [c[2] doubleValue] <= 16384 &&
               [c[1] doubleValue] * [c[2] doubleValue] <= BP_SHAPE_LIMIT) {
      frames++;
    } else if ([k isEqual:@"region"] && c.count == 7 && bp_string(c[1]) && bp_number(c[2]) && bp_number(c[3]) && bp_number(c[4]) &&
               bp_number(c[5]) && bp_is_bool(c[6])) {
    } else if ([k isEqual:@"clear"] && c.count == 1) {
    } else return @"unsupported canvas command";
  }
  if (frames != 1 || ![commands[0][0] isEqual:@"frame"]) return @"invalid Canvas frame";
  return nil;
}
CGSize bend_paint_size(NSArray* commands) {
  for (id x in bp_array(commands) ? commands : @[]) {
    if (bp_array(x) && [x count] == 3 && [x[0] isEqual:@"frame"] && bp_number(x[1]) && bp_number(x[2]))
      return CGSizeMake([x[1] doubleValue], [x[2] doubleValue]);
  }
  return CGSizeZero;
}

// Regions and texts
// -----------------

// A region is what renderer.js hit-tests: name, x, y, width, height and
// enabled; the shell tests them last to first (the last paints on top) and
// sends a hit's event. kind and label read the F role from the
// name ("button · Send", "button, disabled · Send", "textbox · Write to
// Dot", "address · /x"); a textbox's value is its "value · " leaf, the 0x0
// shape F places first inside it.
static NSDictionary* bp_region(NSArray* c, NSArray* commands) {
  NSString* name = c[1];
  NSString* kind = @"other";
  NSString* label = name;
  NSArray* roles = @[@[@"button · ", @"button"], @[@"button, disabled · ", @"button"], @[@"textbox · ", @"textbox"], @[@"textbox, disabled · ", @"textbox"], @[@"address · ", @"address"]];
  for (NSArray* r in roles) {
    if ([name hasPrefix:r[0]]) {
      kind = r[1];
      label = [name substringFromIndex:[r[0] length]];
      break;
    }
  }
  if ([kind isEqual:@"other"] && ([name isEqual:@"Field text"] || [name isEqual:@"Scroll content · Field text"] || [name hasSuffix:@" button"])) kind = [name hasSuffix:@" button"] ? @"button" : @"field";
  // A tab separates a stable routing key from a human-readable label.
  NSString* event = name;
  NSRange separator = [name rangeOfString:@"\t"];
  if (([kind isEqual:@"button"] || [kind isEqual:@"textbox"]) && separator.location != NSNotFound) {
    event = [name substringToIndex:separator.location];
    label = [name substringFromIndex:NSMaxRange(separator)];
  }
  double x = [c[2] doubleValue], y = [c[3] doubleValue], w = [c[4] doubleValue], h = [c[5] doubleValue];
  NSMutableDictionary* d = [@{@"name": name, @"event": event, @"label": label, @"kind": kind, @"x": c[2], @"y": c[3], @"w": c[4], @"h": c[5],
                              @"enabled": @([c[6] boolValue] && ![name hasPrefix:@"textbox, disabled · "])} mutableCopy];
  if ([kind isEqual:@"textbox"]) {
    NSString* value = @"";
    for (id item in commands) {
      if (!bp_array(item)) continue;
      NSArray* s = item;
      if (s.count < 6 || ![s[0] isEqual:@"shape"] || ![s[1] isKindOfClass:NSString.class]) continue;
      NSString* valueName = s[1];
      if ([valueName hasPrefix:@"Scroll content · "]) valueName = [valueName substringFromIndex:17];
      if (![valueName hasPrefix:@"value · "]) continue;
      double sx = [s[2] doubleValue], sy = [s[3] doubleValue];
      if (sx >= x && sy >= y && sx <= x + w && sy <= y + h) {
        value = [valueName substringFromIndex:8];
        break;
      }
    }
    d[@"value"] = value;
  }
  return d;
}
NSArray* bend_paint_regions(NSArray* commands) {
  NSMutableArray* out = [NSMutableArray array];
  if (!bp_array(commands)) return out;
  for (id c in commands) {
    if (bp_array(c) && [c count] == 7 && [c[0] isEqual:@"region"] && bp_string(c[1]) && bp_number(c[2]) && bp_number(c[3]) &&
        bp_number(c[4]) && bp_number(c[5]) && bp_is_bool(c[6]))
      [out addObject:bp_region(c, commands)];
  }
  return out;
}
NSArray* bend_paint_texts(NSArray* commands) {
  NSMutableArray* out = [NSMutableArray array];
  if (!bp_array(commands)) return out;
  for (id c in commands) {
    if (!bp_array(c) || [c count] != 10 || ![c[0] isEqual:@"shape"] || !bp_array(c[6])) continue;
    NSArray* g = c[6];
    if ((g.count == 4 || g.count == 5) && [g[0] isEqual:@"text"] && bp_string(g[1])) [out addObject:g[1]];
  }
  return out;
}

// Colours
// -------

// CSS colours as the tokens write them (#rgb, #rrggbb, #rrggbbaa, rgb(),
// rgba(), transparent and the basic names), in sRGB. An invalid colour leaves
// the canvas default: black for fills and strokes, no shadow.
static CGColorSpaceRef bp_srgb(void) {
  static CGColorSpaceRef cs;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); });
  return cs;
}
static int bp_hex(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}
static BOOL bp_parse_color(NSString* text, double rgba[4]) {
  NSString* s = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] lowercaseString];
  const char* c = s.UTF8String;
  size_t n = strlen(c);
  if (n > 0 && c[0] == '#') {
    if (n != 4 && n != 5 && n != 7 && n != 9) return NO;
    int v[8];
    for (size_t i = 1; i < n; i++) if ((v[i - 1] = bp_hex(c[i])) < 0) return NO;
    if (n == 4 || n == 5) {
      for (int i = 0; i < 4; i++) rgba[i] = i < (int)n - 1 ? (v[i] * 17) / 255.0 : 1;
      return YES;
    }
    if (n == 7 || n == 9) {
      for (int i = 0; i < 4; i++) rgba[i] = i < ((int)n - 1) / 2 ? (v[2 * i] * 16 + v[2 * i + 1]) / 255.0 : 1;
      return YES;
    }
    return NO;
  }
  NSDictionary* names = @{@"transparent": @[@0, @0, @0, @0], @"black": @[@0, @0, @0, @1], @"white": @[@1, @1, @1, @1],
                          @"red": @[@1, @0, @0, @1], @"green": @[@0, @(128 / 255.0), @0, @1], @"blue": @[@0, @0, @1, @1],
                          @"gray": @[@(128 / 255.0), @(128 / 255.0), @(128 / 255.0), @1], @"grey": @[@(128 / 255.0), @(128 / 255.0), @(128 / 255.0), @1]};
  NSArray* named = names[s];
  if (named) {
    for (int i = 0; i < 4; i++) rgba[i] = [named[i] doubleValue];
    return YES;
  }
  if (([s hasPrefix:@"rgb("] || [s hasPrefix:@"rgba("]) && [s hasSuffix:@")"]) {
    NSRange open = [s rangeOfString:@"("];
    NSString* body = [s substringWithRange:NSMakeRange(open.location + 1, s.length - open.location - 2)];
    body = [[body stringByReplacingOccurrencesOfString:@"/" withString:@" "] stringByReplacingOccurrencesOfString:@"," withString:@" "];
    NSMutableArray* parts = [NSMutableArray array];
    for (NSString* p in [body componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]) if (p.length) [parts addObject:p];
    if (parts.count != 3 && parts.count != 4) return NO;
    for (NSUInteger i = 0; i < 4; i++) {
      if (i == parts.count) {
        rgba[3] = 1;
        break;
      }
      NSString* p = parts[i];
      BOOL percent = [p hasSuffix:@"%"];
      if (percent) p = [p substringToIndex:p.length - 1];
      size_t used = 0;
      const char* pc = p.UTF8String;
      double v = bp_strtod(pc, strlen(pc), &used);
      if (used != strlen(pc) || !isfinite(v)) return NO;
      v = percent ? v / 100 : (i < 3 ? v / 255 : v);
      rgba[i] = fmin(1, fmax(0, v));
    }
    return YES;
  }
  return NO;
}
static CGColorRef bp_color(NSString* text, double fallback_alpha) {
  double c[4] = {0, 0, 0, fallback_alpha};
  if (!bp_string(text) || !bp_parse_color(text, c)) {
    if (bp_string(text)) bp_unsupported([@"color " stringByAppendingString:text]);
    c[0] = c[1] = c[2] = 0;
    c[3] = fallback_alpha;
  }
  CGFloat f[4] = {c[0], c[1], c[2], c[3]};
  return CGColorCreate(bp_srgb(), f);
}

// Fonts
// -----

// ctx.font = `${weight} ${size}px system-ui`: the system UI font (SF Pro on
// Apple systems) at the size, its weight axis at the CSS weight (as Chrome
// sets it) and its optical size following the size. textBaseline 'top' puts
// the baseline the normalized OS/2 typo ascent below y, as Chrome does.
typedef struct {
  CTFontRef font;
  double top;
} BpFont;
static int16_t bp_be16(const uint8_t* p) {
  return (int16_t)((p[0] << 8) | p[1]);
}
static BpFont bp_font(double size, double weight, BOOL monospace) {
  static NSMutableDictionary* cache;
  NSString* key = [NSString stringWithFormat:@"%g/%g/%d", size, weight, monospace];
  @synchronized (NSNull.class) {
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSArray* hit = cache[key];
    if (hit) return (BpFont){(__bridge CTFontRef)hit[0], [hit[1] doubleValue]};
  }
  CTFontRef font;
  if (weight >= 1 && weight <= 1000) {
    CTFontRef base = monospace ? CTFontCreateWithName(CFSTR("Menlo"), size, NULL) : CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, size, NULL);
    NSDictionary* attrs = @{(id)kCTFontVariationAttribute: @{@(0x77676874): @(weight)}};
    CTFontDescriptorRef d = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attrs);
    font = CTFontCreateCopyWithAttributes(base, size, NULL, d);
    CFRelease(d);
    CFRelease(base);
  } else {
    // An invalid CSS weight makes the whole font string invalid: the canvas
    // keeps its default font, 10px sans-serif.
    font = CTFontCreateWithName(CFSTR("Helvetica"), 10, NULL);
  }
  double em = CTFontGetSize(font);
  double asc = CTFontGetAscent(font), desc = CTFontGetDescent(font);
  CFDataRef os2 = CTFontCopyTable(font, kCTFontTableOS2, kCTFontTableOptionNoOptions);
  if (os2 && CFDataGetLength(os2) >= 72) {
    const uint8_t* p = CFDataGetBytePtr(os2);
    double ta = bp_be16(p + 68), td = -bp_be16(p + 70);
    if (ta + td > 0) {
      asc = ta;
      desc = td;
    }
  }
  if (os2) CFRelease(os2);
  double top = asc + desc > 0 ? round(asc * em / (asc + desc) * 64) / 64 : em;
  @synchronized (NSNull.class) {
    cache[key] = @[(__bridge_transfer id)font, @(top)];
    NSArray* hit = cache[key];
    return (BpFont){(__bridge CTFontRef)hit[0], [hit[1] doubleValue]};
  }
}

// Images
// ------

// Photo and atlas fills name an image: a data: URL, an http(s) or file URL,
// or a path that the web app serves from its own root, which natively
// resolves against $BEND_ASSETS (a directory or URL) or the bundle's
// Resources. Like the browser's, a paint waits for its images:
// bend_paint_prepare loads them (blocking; call it off the main thread
// before handing the packet to the view). A paint whose image is not loaded
// yet draws without it and, once it arrives, posts BendPaintAssetsChanged.
typedef struct {
  CGImageRef image;
  double width, height;
} BpImage;
@interface BpAsset : NSObject {
  @public
  CGImageRef image;
  double width, height;
  BOOL failed;
}
@end
@implementation BpAsset
- (void)dealloc {
  if (image) CGImageRelease(image);
}
@end
static NSMutableDictionary* bp_assets(void) {
  static NSMutableDictionary* assets;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ assets = [NSMutableDictionary dictionary]; });
  return assets;
}
static NSURL* bp_resolve(NSString* url) {
  NSURL* u = [NSURL URLWithString:url];
  if (u.scheme.length) return u;
  NSString* env = NSProcessInfo.processInfo.environment[@"BEND_ASSETS"];
  NSURL* base = nil;
  if (env.length) base = [NSURL URLWithString:env].scheme.length > 1 ? [NSURL URLWithString:env] : [NSURL fileURLWithPath:env isDirectory:YES];
  if (!base) base = NSBundle.mainBundle.resourceURL ?: [NSURL fileURLWithPath:NSFileManager.defaultManager.currentDirectoryPath isDirectory:YES];
  if (![base.absoluteString hasSuffix:@"/"]) base = [NSURL URLWithString:[base.absoluteString stringByAppendingString:@"/"]];
  while ([url hasPrefix:@"/"]) url = [url substringFromIndex:1];
  NSString* escaped = [url stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
  return [NSURL URLWithString:escaped relativeToURL:base].absoluteURL;
}
static NSData* bp_data_url(NSString* url) {
  NSRange comma = [url rangeOfString:@","];
  if (comma.location == NSNotFound) return nil;
  NSString* meta = [url substringWithRange:NSMakeRange(5, comma.location - 5)];
  NSString* body = [url substringFromIndex:comma.location + 1];
  if ([meta hasSuffix:@";base64"]) return [[NSData alloc] initWithBase64EncodedString:body.stringByRemovingPercentEncoding ?: body options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [body.stringByRemovingPercentEncoding ?: body dataUsingEncoding:NSUTF8StringEncoding];
}
static NSData* bp_fetch(NSURL* u, NSTimeInterval timeout) {
  if ([u.scheme isEqual:@"data"]) return bp_data_url(u.absoluteString);
  if (u.isFileURL) return [NSData dataWithContentsOfURL:u];
  __block NSData* out = nil;
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeout];
  [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData* d, NSURLResponse* r, NSError* e) {
    NSInteger code = [r isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse*)r).statusCode : 200;
    if (!e && code >= 200 && code < 300) out = d;
    dispatch_semaphore_signal(done);
  }] resume];
  dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 1) * NSEC_PER_SEC)));
  return out;
}
static BpAsset* bp_decode(NSData* data) {
  BpAsset* a = [BpAsset new];
  if (!data.length) {
    a->failed = YES;
    return a;
  }
  CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
  if (src && CGImageSourceGetCount(src) > 0) a->image = CGImageSourceCreateImageAtIndex(src, 0, NULL);
  if (src) CFRelease(src);
  if (a->image) {
    a->width = CGImageGetWidth(a->image);
    a->height = CGImageGetHeight(a->image);
    return a;
  }
#if TARGET_OS_OSX
  // SVG (the web's ./asset.svg): AppKit's SVG image rep, rasterized at 4x
  // its intrinsic size; drawing still uses the intrinsic (natural) size.
  NSImage* im = [[NSImage alloc] initWithData:data];
  if (im && im.size.width > 0 && im.size.height > 0 && im.size.width * im.size.height <= BP_SHAPE_LIMIT) {
    size_t w = (size_t)ceil(im.size.width * 4), h = (size_t)ceil(im.size.height * 4);
    CGContextRef c = CGBitmapContextCreate(NULL, w, h, 8, 0, bp_srgb(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    if (c) {
      NSGraphicsContext* g = [NSGraphicsContext graphicsContextWithCGContext:c flipped:NO];
      [NSGraphicsContext saveGraphicsState];
      NSGraphicsContext.currentContext = g;
      [im drawInRect:NSMakeRect(0, 0, w, h) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
      [NSGraphicsContext restoreGraphicsState];
      a->image = CGBitmapContextCreateImage(c);
      CGContextRelease(c);
      a->width = im.size.width;
      a->height = im.size.height;
      return a;
    }
  }
#endif
  a->failed = YES;
  return a;
}
static void bp_store(NSString* url, BpAsset* a) {
  NSMutableDictionary* assets = bp_assets();
  @synchronized (assets) {
    if (assets.count >= 64) [assets removeAllObjects];
    assets[url] = a;
  }
}
static BpAsset* bp_cached(NSString* url) {
  NSMutableDictionary* assets = bp_assets();
  @synchronized (assets) {
    id a = assets[url];
    return [a isKindOfClass:BpAsset.class] ? a : nil;
  }
}
static BpAsset* bp_load(NSString* url) {
  BpAsset* a = bp_cached(url);
  if (a) return a;
  NSURL* u = bp_resolve(url);
  a = bp_decode(u ? bp_fetch(u, 30) : nil);
  if (a->failed) fprintf(stderr, "bend-image-failed %s\n", url.UTF8String);
  bp_store(url, a);
  return a;
}
// While painting: local images load now; remote ones load in the background.
static BpAsset* bp_image(NSString* url) {
  if (!url.length) return nil;
  BpAsset* a = bp_cached(url);
  if (a) return a;
  NSURL* u = bp_resolve(url);
  if (!u || u.isFileURL || [u.scheme isEqual:@"data"]) return bp_load(url);
  NSMutableDictionary* assets = bp_assets();
  @synchronized (assets) {
    if (assets[url]) return nil;
    assets[url] = NSNull.null;
  }
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @synchronized (assets) { [assets removeObjectForKey:url]; }
    bp_load(url);
    dispatch_async(dispatch_get_main_queue(), ^{
      [NSNotificationCenter.defaultCenter postNotificationName:@"BendPaintAssetsChanged" object:nil];
    });
  });
  return nil;
}
NSString* bend_paint_prepare(NSArray* commands) {
  if (!bp_array(commands)) return nil;
  for (id c in commands) {
    if (!bp_array(c) || [c count] != 10 || ![c[0] isEqual:@"shape"] || !bp_array(c[7])) continue;
    NSArray* f = c[7];
    if (f.count > 1 && ([f[0] isEqual:@"photo"] || [f[0] isEqual:@"atlas"]) && bp_string(f[1]) && [f[1] length]) {
      if (bp_load(f[1])->failed) return @"F image could not be loaded";
    }
  }
  return nil;
}

// Paths
// -----

// SVG path data (the symbols' "M12 22V2..."), parsed as Path2D does: up to
// the first error, everything before it kept.
typedef struct {
  const char* p;
  const char* end;
} BpScan;
static void bp_skip(BpScan* s) {
  while (s->p < s->end && (*s->p == ' ' || *s->p == '\t' || *s->p == '\n' || *s->p == '\r' || *s->p == '\f' || *s->p == ',')) s->p++;
}
static BOOL bp_scan_number(BpScan* s, double* out) {
  bp_skip(s);
  const char* q = s->p;
  if (q < s->end && (*q == '+' || *q == '-')) q++;
  const char* d = q;
  while (q < s->end && *q >= '0' && *q <= '9') q++;
  BOOL whole = q > d, part = NO;
  if (q < s->end && *q == '.') {
    const char* f = ++q;
    while (q < s->end && *q >= '0' && *q <= '9') q++;
    part = q > f;
  }
  if (!whole && !part) return NO;
  if (q < s->end && (*q == 'e' || *q == 'E')) {
    const char* e = q + 1;
    if (e < s->end && (*e == '+' || *e == '-')) e++;
    const char* ed = e;
    while (e < s->end && *e >= '0' && *e <= '9') e++;
    if (e > ed) q = e;
  }
  size_t used = 0;
  *out = bp_strtod(s->p, (size_t)(q - s->p), &used);
  s->p = q;
  return isfinite(*out);
}
static BOOL bp_scan_flag(BpScan* s, BOOL* out) {
  bp_skip(s);
  if (s->p < s->end && (*s->p == '0' || *s->p == '1')) {
    *out = *s->p++ == '1';
    return YES;
  }
  return NO;
}
static BOOL bp_scan_numbers(BpScan* s, double* v, int n) {
  for (int i = 0; i < n; i++) if (!bp_scan_number(s, &v[i])) return NO;
  return YES;
}
// An SVG elliptical arc as center-parameterized unit-circle arcs (SVG 1.1 F.6.5).
static void bp_arc(CGMutablePathRef path, const CGAffineTransform* t, double x1, double y1, double rx, double ry, double angle, BOOL large, BOOL sweep, double x2, double y2) {
  if (x1 == x2 && y1 == y2) return;
  rx = fabs(rx);
  ry = fabs(ry);
  if (rx == 0 || ry == 0) {
    CGPathAddLineToPoint(path, t, x2, y2);
    return;
  }
  double phi = fmod(angle, 360) * M_PI / 180, cp = cos(phi), sp = sin(phi);
  double dx = (x1 - x2) / 2, dy = (y1 - y2) / 2;
  double x1p = cp * dx + sp * dy, y1p = -sp * dx + cp * dy;
  double lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    rx *= sqrt(lambda);
    ry *= sqrt(lambda);
  }
  double num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
  double den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
  double coef = (den > 0 ? sqrt(fmax(0, num / den)) : 0) * (large == sweep ? -1 : 1);
  double cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx;
  double cx = cp * cxp - sp * cyp + (x1 + x2) / 2, cy = sp * cxp + cp * cyp + (y1 + y2) / 2;
  double ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry, vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry;
  double start = atan2(uy, ux), delta = atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  if (!sweep && delta > 0) delta -= 2 * M_PI;
  if (sweep && delta < 0) delta += 2 * M_PI;
  CGAffineTransform m = CGAffineTransformMake(rx * cp, rx * sp, -ry * sp, ry * cp, cx, cy);
  if (t) m = CGAffineTransformConcat(m, *t);
  CGPathAddRelativeArc(path, &m, 0, 0, 1, start, delta);
}
static void bp_svg_path(CGMutablePathRef path, const CGAffineTransform* t, NSString* d) {
  const char* text = d.UTF8String;
  BpScan s = {text, text + strlen(text)};
  double cx = 0, cy = 0, sx = 0, sy = 0, qx = 0, qy = 0;
  char cmd = 0, last = 0;
  BOOL open = NO, closed = NO;
  for (;;) {
    bp_skip(&s);
    if (s.p >= s.end) return;
    char c = *s.p;
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
      cmd = c;
      s.p++;
    } else if (!cmd) {
      return;
    } else if (cmd == 'M') {
      cmd = 'L';
    } else if (cmd == 'm') {
      cmd = 'l';
    } else if (cmd == 'Z' || cmd == 'z') {
      return;
    }
    if (!open && cmd != 'M' && cmd != 'm') return;
    BOOL rel = cmd >= 'a';
    double ox = rel ? cx : 0, oy = rel ? cy : 0, v[7];
    if (closed && cmd != 'M' && cmd != 'm' && cmd != 'Z' && cmd != 'z') {
      CGPathMoveToPoint(path, t, cx, cy);
      closed = NO;
    }
    switch (cmd) {
      case 'M': case 'm':
        if (!bp_scan_numbers(&s, v, 2)) return;
        cx = sx = ox + v[0];
        cy = sy = oy + v[1];
        CGPathMoveToPoint(path, t, cx, cy);
        open = YES;
        closed = NO;
        break;
      case 'L': case 'l':
        if (!bp_scan_numbers(&s, v, 2)) return;
        cx = ox + v[0];
        cy = oy + v[1];
        CGPathAddLineToPoint(path, t, cx, cy);
        break;
      case 'H': case 'h':
        if (!bp_scan_numbers(&s, v, 1)) return;
        cx = ox + v[0];
        CGPathAddLineToPoint(path, t, cx, cy);
        break;
      case 'V': case 'v':
        if (!bp_scan_numbers(&s, v, 1)) return;
        cy = oy + v[0];
        CGPathAddLineToPoint(path, t, cx, cy);
        break;
      case 'C': case 'c':
        if (!bp_scan_numbers(&s, v, 6)) return;
        CGPathAddCurveToPoint(path, t, ox + v[0], oy + v[1], ox + v[2], oy + v[3], ox + v[4], oy + v[5]);
        qx = ox + v[2];
        qy = oy + v[3];
        cx = ox + v[4];
        cy = oy + v[5];
        break;
      case 'S': case 's': {
        if (!bp_scan_numbers(&s, v, 4)) return;
        BOOL smooth = last == 'C' || last == 'c' || last == 'S' || last == 's';
        double x1 = smooth ? 2 * cx - qx : cx, y1 = smooth ? 2 * cy - qy : cy;
        CGPathAddCurveToPoint(path, t, x1, y1, ox + v[0], oy + v[1], ox + v[2], oy + v[3]);
        qx = ox + v[0];
        qy = oy + v[1];
        cx = ox + v[2];
        cy = oy + v[3];
        break;
      }
      case 'Q': case 'q':
        if (!bp_scan_numbers(&s, v, 4)) return;
        CGPathAddQuadCurveToPoint(path, t, ox + v[0], oy + v[1], ox + v[2], oy + v[3]);
        qx = ox + v[0];
        qy = oy + v[1];
        cx = ox + v[2];
        cy = oy + v[3];
        break;
      case 'T': case 't': {
        if (!bp_scan_numbers(&s, v, 2)) return;
        BOOL smooth = last == 'Q' || last == 'q' || last == 'T' || last == 't';
        qx = smooth ? 2 * cx - qx : cx;
        qy = smooth ? 2 * cy - qy : cy;
        CGPathAddQuadCurveToPoint(path, t, qx, qy, ox + v[0], oy + v[1]);
        cx = ox + v[0];
        cy = oy + v[1];
        break;
      }
      case 'A': case 'a': {
        BOOL large, sweep;
        if (!bp_scan_numbers(&s, v, 3) || !bp_scan_flag(&s, &large) || !bp_scan_flag(&s, &sweep) || !bp_scan_numbers(&s, v + 3, 2)) return;
        bp_arc(path, t, cx, cy, v[0], v[1], v[2], large, sweep, ox + v[3], oy + v[4]);
        cx = ox + v[3];
        cy = oy + v[4];
        break;
      }
      case 'Z': case 'z':
        CGPathCloseSubpath(path);
        cx = sx;
        cy = sy;
        closed = YES;
        break;
      default:
        return;
    }
    last = cmd;
  }
}
// renderer.js's shapePath: Rounded is a round rect (radius capped at half
// the shorter side); Path is the 24-unit drawing scaled to fit and centered.
static CGMutablePathRef bp_shape_path(NSArray* g, double width, double height) {
  CGMutablePathRef path = CGPathCreateMutable();
  if ([g[0] isEqual:@"rounded"]) {
    double w = [g[1] doubleValue], h = [g[2] doubleValue];
    double r = fmin([g[3] doubleValue], fmin(w / 2, h / 2));
    if (r > 0) CGPathAddRoundedRect(path, NULL, CGRectMake(0, 0, w, h), r, r);
    else CGPathAddRect(path, NULL, CGRectMake(0, 0, w, h));
  } else if ([g[0] isEqual:@"path"]) {
    double scale = fmin(width, height) / 24;
    CGAffineTransform t = CGAffineTransformScale(CGAffineTransformMakeTranslation((width - 24 * scale) / 2, (height - 24 * scale) / 2), scale, scale);
    for (NSArray* p in g[1]) {
      if ([p[0] isEqual:@"path"]) bp_svg_path(path, &t, p[1]);
      else {
        double x = bp_value(p[1]), y = bp_value(p[2]), r = bp_value(p[3]);
        CGPathMoveToPoint(path, &t, x + r, y);
        CGPathAddArc(path, &t, x, y, r, 0, 2 * M_PI, false);
      }
    }
  }
  return path;
}

// Painting
// --------

// The canvas is a bitmap of the frame at the device scale, user space in CSS
// pixels with a top-left origin, as renderer.js's canvas (only denser).
typedef struct {
  CGContextRef c;
  double scale, width, height;
} BpCanvas;

// An image drawn upright into the top-left user space.
static void bp_draw_image(CGContextRef c, CGImageRef image, CGRect r) {
  CGContextSaveGState(c);
  CGContextTranslateCTM(c, r.origin.x, r.origin.y + r.size.height);
  CGContextScaleCTM(c, 1, -1);
  CGContextDrawImage(c, CGRectMake(0, 0, r.size.width, r.size.height), image);
  CGContextRestoreGState(c);
}
static CIContext* bp_ci(void) {
  static CIContext* ci;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    ci = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace: (__bridge id)bp_srgb(), kCIContextOutputColorSpace: (__bridge id)bp_srgb()}];
  });
  return ci;
}
// The backdrop under the shape's box, through filter: blur(r) [saturate(p%)],
// drawn back at the box (renderer.js's glass and blur). The filters run in
// gamma-encoded sRGB, like the browser's.
static BOOL bp_backdrop(BpCanvas* k, double sx, double sy, double width, double height, double blur, double saturation, BOOL saturate) {
  double s = k->scale;
  CGRect px = CGRectIntersection(CGRectIntegral(CGRectMake(sx * s, sy * s, width * s, height * s)),
                                 CGRectMake(0, 0, CGBitmapContextGetWidth(k->c), CGBitmapContextGetHeight(k->c)));
  if (CGRectIsEmpty(px)) return YES;
  CGImageRef all = CGBitmapContextCreateImage(k->c);
  CGImageRef crop = all ? CGImageCreateWithImageInRect(all, px) : NULL;
  if (all) CGImageRelease(all);
  if (!crop) return NO;
  CIImage* in = [CIImage imageWithCGImage:crop];
  CGImageRelease(crop);
  CIImage* out = blur > 0 ? [in imageByApplyingGaussianBlurWithSigma:blur * s] : in;
  if (saturate) {
    double v = saturation / 100;
    CIFilter* m = [CIFilter filterWithName:@"CIColorMatrix"];
    [m setValue:out forKey:kCIInputImageKey];
    [m setValue:[CIVector vectorWithX:0.213 + 0.787 * v Y:0.715 - 0.715 * v Z:0.072 - 0.072 * v W:0] forKey:@"inputRVector"];
    [m setValue:[CIVector vectorWithX:0.213 - 0.213 * v Y:0.715 + 0.285 * v Z:0.072 - 0.072 * v W:0] forKey:@"inputGVector"];
    [m setValue:[CIVector vectorWithX:0.213 - 0.213 * v Y:0.715 - 0.715 * v Z:0.072 + 0.928 * v W:0] forKey:@"inputBVector"];
    [m setValue:[CIVector vectorWithX:0 Y:0 Z:0 W:1] forKey:@"inputAVector"];
    out = m.outputImage;
  }
  if (!out) return NO;
  double pad = ceil(blur * s * 3);
  CGRect r = CGRectInset(in.extent, -pad, -pad);
  CGImageRef done = [bp_ci() createCGImage:out fromRect:r];
  if (!done) return NO;
  bp_draw_image(k->c, done, CGRectMake(px.origin.x / s - sx - pad / s, px.origin.y / s - sy - pad / s, r.size.width / s, r.size.height / s));
  CGImageRelease(done);
  return YES;
}
// A fill style: a solid colour or the vertical gradient renderer.js builds
// (from at 0 and at hold%, to at 1, over the shape's height).
static void bp_fill_area(CGContextRef c, NSArray* fill, double height) {
  if ([fill[0] isEqual:@"solid"]) {
    CGColorRef col = bp_color(fill[1], 1);
    CGContextSetFillColorWithColor(c, col);
    CGColorRelease(col);
    CGContextFillRect(c, CGContextGetClipBoundingBox(c));
    return;
  }
  CGColorRef a = bp_color(fill[1], 1), b = bp_color(fill[2], 1);
  NSArray* colors = @[(__bridge id)a, (__bridge id)a, (__bridge id)b];
  CGFloat stops[3] = {0, [fill[3] doubleValue] / 100, 1};
  CGGradientRef g = CGGradientCreateWithColors(bp_srgb(), (__bridge CFArrayRef)colors, stops);
  CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, height), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
  CGGradientRelease(g);
  CGColorRelease(a);
  CGColorRelease(b);
}
// The browser's canvas puts the baseline on a whole CSS pixel (y + top,
// rounded); CoreGraphics would floor it in its own device space, so the
// baseline is placed on that whole pixel, a hair inside it.
static void bp_text(CGContextRef c, NSArray* g, NSArray* fill, double height, double y) {
  double size = [g[2] doubleValue];
  double weight = [g[3] doubleValue];
  if (size == 0 && weight >= 1 && weight <= 1000) return;
  BpFont f = bp_font(size, weight, g.count > 4 && [g[4] isEqual:@"monospace"]);
  NSDictionary* attrs = @{(id)kCTFontAttributeName: (__bridge id)f.font, (id)kCTForegroundColorFromContextAttributeName: @YES};
  // Canvas draws one line: ASCII whitespace is replaced by spaces.
  NSString* value = g[1];
  for (NSString* ws in @[@"\t", @"\n", @"\r", @"\f"]) value = [value stringByReplacingOccurrencesOfString:ws withString:@" "];
  NSAttributedString* text = [[NSAttributedString alloc] initWithString:value attributes:attrs];
  CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
  CGContextSaveGState(c);
  CGContextSetTextMatrix(c, CGAffineTransformMakeScale(1, -1));
  CGContextSetTextPosition(c, 0, round(y + f.top) - y - 1.0 / 256);
  if (![fill[0] isEqual:@"gradient"]) {
    // fillText is unconditional in renderer.js. Fills other than solid or
    // gradient leave Canvas's default fillStyle (black) in place.
    CGColorRef col = bp_color([fill[0] isEqual:@"solid"] ? fill[1] : @"black", 1);
    CGContextSetFillColorWithColor(c, col);
    CGColorRelease(col);
    CTLineDraw(line, c);
  } else if ([fill[0] isEqual:@"gradient"]) {
    // Gradient glyphs: the glyphs as the clip, the gradient through them.
    CGContextSetTextDrawingMode(c, kCGTextClip);
    CTLineDraw(line, c);
    CGContextSetTextDrawingMode(c, kCGTextFill);
    bp_fill_area(c, fill, height);
  }
  CGContextRestoreGState(c);
  CFRelease(line);
}
// fill[1..] of a photo (cover) or atlas (its source rectangle) into the box.
static void bp_bitmap(CGContextRef c, NSArray* fill, double width, double height) {
  BpAsset* a = bp_image(fill[1]);
  if (!a || a->failed || !a->image || !width || !height) return;
  double nw = a->width, nh = a->height, ks = CGImageGetWidth(a->image) / fmax(1, nw);
  if ([fill[0] isEqual:@"atlas"]) {
    CGRect src = CGRectMake([fill[2] doubleValue], [fill[3] doubleValue], [fill[4] doubleValue], [fill[5] doubleValue]);
    CGRect part = CGRectIntersection(src, CGRectMake(0, 0, nw, nh));
    if (CGRectIsEmpty(part) || src.size.width <= 0 || src.size.height <= 0) return;
    CGImageRef cut = CGImageCreateWithImageInRect(a->image, CGRectMake(part.origin.x * ks, part.origin.y * ks, part.size.width * ks, part.size.height * ks));
    if (!cut) return;
    double fx = width / src.size.width, fy = height / src.size.height;
    bp_draw_image(c, cut, CGRectMake((part.origin.x - src.origin.x) * fx, (part.origin.y - src.origin.y) * fy, part.size.width * fx, part.size.height * fy));
    CGImageRelease(cut);
  } else {
    if (nw <= 0 || nh <= 0) return;
    double scale = fmax(width / nw, height / nh), w = nw * scale, h = nh * scale;
    bp_draw_image(c, a->image, CGRectMake((width - w) / 2, (height - h) / 2, w, h));
  }
}
// A CSS outer shadow of the box (the shape's outline when Rounded, else its
// box): offset y, blur, colour; only outside the outline, as renderer.js's
// evenodd clip makes it. The outline itself is drawn far outside the canvas
// and its shadow offset back, so only the shadow lands.
static void bp_shadow(BpCanvas* k, CGPathRef outline, double sx, double sy, NSArray* e) {
  CGContextRef c = k->c;
  CGColorRef col = bp_color(e[3], 0);
  if (CGColorGetAlpha(col) > 0) {
    CGContextSaveGState(c);
    CGMutablePathRef outside = CGPathCreateMutable();
    CGPathAddRect(outside, NULL, CGRectMake(-sx, -sy, k->width, k->height));
    CGPathAddPath(outside, NULL, outline);
    CGContextAddPath(c, outside);
    CGContextEOClip(c);
    CGPathRelease(outside);
    CGRect box = CGPathGetBoundingBox(outline);
    double away = k->width + box.size.width + 4 * [e[2] doubleValue] + 64 + sx;
    // Shadows live in the bitmap's base space: device pixels, y up.
    CGContextSetShadowWithColor(c, CGSizeMake(away * k->scale, -[e[1] doubleValue] * k->scale), [e[2] doubleValue] * k->scale, col);
    CGContextTranslateCTM(c, -away, 0);
    CGContextAddPath(c, outline);
    CGContextSetFillColorWithColor(c, CGColorGetConstantColor(kCGColorBlack));
    CGContextFillPath(c);
    CGContextRestoreGState(c);
  }
  CGColorRelease(col);
}
static NSArray* bp_find(NSArray* effects, NSString* kind) {
  for (NSArray* e in effects) if ([e[0] isEqual:kind]) return e;
  return nil;
}
static void bp_shape(BpCanvas* k, NSArray* c) {
  CGContextRef cg = k->c;
  double sx = [c[2] doubleValue], sy = [c[3] doubleValue];
  NSArray *g = c[6], *fill = c[7], *stroke = c[8], *effects = c[9];
  BOOL rounded = [g[0] isEqual:@"rounded"], text = [g[0] isEqual:@"text"], path_kind = [g[0] isEqual:@"path"];
  double width = rounded ? [g[1] doubleValue] : [c[4] doubleValue];
  double height = rounded ? [g[2] doubleValue] : [c[5] doubleValue];
  CGContextSaveGState(cg);
  CGContextTranslateCTM(cg, sx, sy);
  CGMutablePathRef path = bp_shape_path(g, width, height);
  NSArray* glass = bp_find(effects, @"glass");
  NSArray* blur = bp_find(effects, @"blur");
  if ((glass || blur) && width && height && width <= 16384 && height <= 16384 && width * height <= BP_SHAPE_LIMIT) {
    CGContextSaveGState(cg);
    if (!text) {
      CGContextAddPath(cg, path);
      CGContextClip(cg);
    }
    BOOL ok = glass ? bp_backdrop(k, sx, sy, width, height, [glass[1] doubleValue], [glass[2] doubleValue], YES)
                    : bp_backdrop(k, sx, sy, width, height, [blur[1] doubleValue], 100, NO);
    if (!ok) bp_unsupported(glass ? @"glass" : @"blur");
    CGContextRestoreGState(cg);
  }
  for (NSArray* e in effects) {
    if (![e[0] isEqual:@"shadow"] || !width || !height) continue;
    CGMutablePathRef outline = CGPathCreateMutable();
    if (rounded) CGPathAddPath(outline, NULL, path);
    else CGPathAddRect(outline, NULL, CGRectMake(0, 0, width, height));
    bp_shadow(k, outline, sx, sy, e);
    CGPathRelease(outline);
  }
  CGContextSaveGState(cg);
  if (glass) CGContextSetAlpha(cg, [glass[5] doubleValue] / 100);
  BOOL paints = [fill[0] isEqual:@"solid"] || [fill[0] isEqual:@"gradient"];
  if (text) {
    bp_text(cg, g, fill, height, sy);
  } else if (paints) {
    if (!CGPathIsEmpty(path)) {
      CGContextAddPath(cg, path);
      CGContextClip(cg);
      bp_fill_area(cg, fill, height);
    }
  } else if ([fill[0] isEqual:@"photo"] || [fill[0] isEqual:@"atlas"]) {
    if (!CGPathIsEmpty(path)) {
      CGContextAddPath(cg, path);
      CGContextClip(cg);
      bp_bitmap(cg, fill, width, height);
    }
  }
  CGContextRestoreGState(cg);
  double sw = [stroke[0] isEqual:@"stroke"] ? bp_js_number(stroke[2]) : 0;
  if (sw > 0 && !text && (!path_kind || fmin(width, height) > 0) && !CGPathIsEmpty(path)) {
    CGContextSaveGState(cg);
    CGColorRef col = bp_color(stroke[1], 1);
    CGContextSetStrokeColorWithColor(cg, col);
    CGColorRelease(col);
    double lw = sw * (path_kind ? fmin(width, height) / 24 : 1);
    CGContextSetLineCap(cg, kCGLineCapRound);
    CGContextSetLineJoin(cg, kCGLineJoinRound);
    if (rounded) {
      // Inside the outline only: twice the width, clipped (renderer.js).
      CGContextAddPath(cg, path);
      CGContextClip(cg);
      lw *= 2;
    }
    CGContextSetLineWidth(cg, lw);
    CGContextAddPath(cg, path);
    CGContextStrokePath(cg);
    CGContextRestoreGState(cg);
  }
  if (glass && !CGPathIsEmpty(path)) {
    CGContextSaveGState(cg);
    CGContextAddPath(cg, path);
    CGContextClip(cg);
    CGFloat hl[8] = {1, 1, 1, [glass[4] doubleValue] / 100, 1, 1, 1, 0};
    CGGradientRef shine = CGGradientCreateWithColorComponents(bp_srgb(), hl, (CGFloat[]){0, 1}, 2);
    CGContextDrawLinearGradient(cg, shine, CGPointMake(0, 0), CGPointMake(0, height / 2), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(shine);
    CGContextRestoreGState(cg);
    CGContextSaveGState(cg);
    CGContextAddPath(cg, path);
    CGContextClip(cg);
    CGColorRef edge = bp_color(glass[6], 1);
    CGContextSetStrokeColorWithColor(cg, edge);
    CGColorRelease(edge);
    CGContextSetLineWidth(cg, 1);
    CGContextAddPath(cg, path);
    CGContextStrokePath(cg);
    CGContextRestoreGState(cg);
  }
  CGPathRelease(path);
  CGContextRestoreGState(cg);
}
// The canvas of a valid packet at a scale: its frame's pixels, or NULL.
static CGImageRef bp_render(NSArray* commands, double scale) {
  CGSize frame = bend_paint_size(commands);
  if (frame.width <= 0 || frame.height <= 0) return NULL;
  // At most 64M device pixels: a denser canvas falls back toward 1x.
  while (scale > 1 && frame.width * frame.height * scale * scale > 67108864.0) scale = fmax(1, scale - 0.5);
  size_t pw = (size_t)ceil(frame.width * scale), ph = (size_t)ceil(frame.height * scale);
  CGContextRef c = CGBitmapContextCreate(NULL, pw, ph, 8, 0, bp_srgb(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  if (!c) return NULL;
  CGContextTranslateCTM(c, 0, ph);
  CGContextScaleCTM(c, scale, -scale);
  CGContextSetInterpolationQuality(c, kCGInterpolationDefault);
  BpCanvas k = {c, scale, frame.width, frame.height};
  for (NSArray* x in commands) {
    NSString* kind = x[0];
    if ([kind isEqual:@"shape"]) bp_shape(&k, x);
    else if ([kind isEqual:@"clear"]) CGContextClearRect(c, CGRectMake(0, 0, frame.width, frame.height));
    else if (![kind isEqual:@"frame"] && ![kind isEqual:@"region"]) bp_unsupported(kind);
  }
  CGImageRef image = CGBitmapContextCreateImage(c);
  CGContextRelease(c);
  return image;
}
static atomic_int bp_dark;
void bend_paint_set_dark(BOOL enabled) {
  atomic_store(&bp_dark, enabled ? 1 : 0);
}
static void bp_paint(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height, BOOL background, BOOL validated) {
  if (!cg) return;
  @autoreleasepool {
    CGAffineTransform d = CGContextGetUserSpaceToDeviceSpaceTransform(cg);
    double scale = sqrt(fabs(d.a * d.d - d.b * d.c));
    if (!(scale >= 1)) scale = 1;
    if (scale > 4) scale = 4;
    CGContextSaveGState(cg);
    if (background) {
      CGContextSetFillColorWithColor(cg, CGColorGetConstantColor(atomic_load(&bp_dark) ? kCGColorBlack : kCGColorWhite));
      CGContextFillRect(cg, CGRectMake(0, 0, width, height));
    }
    NSString* error = validated ? nil : bend_paint_check(commands);
    if (error) {
      bp_once("bend-paint-invalid", error);
    } else {
      CGImageRef canvas = bp_render(commands, scale);
      if (canvas) {
        CGSize frame = bend_paint_size(commands);
        CGContextSetInterpolationQuality(cg, kCGInterpolationNone);
        bp_draw_image(cg, canvas, CGRectMake(0, 0, frame.width, frame.height));
        CGImageRelease(canvas);
      }
    }
    CGContextRestoreGState(cg);
  }
}
void bend_paint(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height) {
  bp_paint(cg, commands, width, height, YES, NO);
}
void bend_paint_overlay(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height) {
  bp_paint(cg, commands, width, height, NO, NO);
}
// UIKit clips a previously validated packet into a screen-sized viewport.
// Its derived shapes can begin above or left of that viewport.
void bend_paint_clipped(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height) {
  bp_paint(cg, commands, width, height, YES, YES);
}
void bend_paint_clipped_overlay(CGContextRef cg, NSArray* commands, CGFloat width, CGFloat height) {
  bp_paint(cg, commands, width, height, NO, YES);
}
// The paint as a PNG (BEND_SNAPSHOT, tests): width x height points (the
// frame's size when zero) at a scale.
BOOL bend_paint_png(NSArray* commands, CGFloat width, CGFloat height, CGFloat scale, NSString* path) {
  CGSize frame = bend_paint_size(commands);
  if (width <= 0 || height <= 0) {
    width = frame.width;
    height = frame.height;
  }
  if (width <= 0 || height <= 0 || !(scale > 0)) return NO;
  size_t pw = (size_t)ceil(width * scale), ph = (size_t)ceil(height * scale);
  CGContextRef c = CGBitmapContextCreate(NULL, pw, ph, 8, 0, bp_srgb(), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
  if (!c) return NO;
  CGContextTranslateCTM(c, 0, ph);
  CGContextScaleCTM(c, scale, -scale);
  bend_paint(c, commands, width, height);
  CGImageRef image = CGBitmapContextCreateImage(c);
  CGContextRelease(c);
  BOOL ok = NO;
  CGImageDestinationRef dst = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], CFSTR("public.png"), 1, NULL);
  if (dst && image) {
    CGImageDestinationAddImage(dst, image, NULL);
    ok = CGImageDestinationFinalize(dst);
  }
  if (dst) CFRelease(dst);
  if (image) CGImageRelease(image);
  return ok;
}
