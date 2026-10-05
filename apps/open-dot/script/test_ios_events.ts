import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

// Compile the actual Foundation-only queue from the UIKit host, not a model.
const host = readFileSync(resolve(import.meta.dir, '../../../bend2/std/F/apple/ios_shell.c'), 'utf8');
const start = host.indexOf('#define IOS_LIMIT ');
const end = host.indexOf('static NSNumber* ios_port(');
if (start < 0 || end <= start) throw Error('Native event queue source boundaries changed.');
const directory = mkdtempSync(join(tmpdir(), 'dot-ios-events-'));
try {
  const source = join(directory, 'events.m');
  writeFileSync(source, `#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
${host.slice(start, end)}
static void check(BOOL value, const char* message) {
  if (!value) { fprintf(stderr, "%s\\n", message); exit(1); }
}
static void tick(NSString* session, unsigned elapsed) {
  ios_action(@{@"action":@"voice", @"data":@{@"session":session,
    @"mode":@"message", @"phase":@"elapsed", @"elapsedMs":@(elapsed)}});
}
static NSString* next(void) {
  check(ios_events.count > 0, "expected queued event");
  unsigned status = 0; char* text = ios_event(&status);
  NSString* result = @(text); free(text);
  check(status == 1, "event must be delivered"); return result;
}
int main(void) { @autoreleasepool {
  ios_events = [NSMutableArray new]; ios_read = [NSMutableDictionary new];
  for (unsigned i = 0; i < 3000; ++i) tick(@"recording-1", i * 100);
  ios_deliver(@"button · Send voice message", nil, 0);
  ios_action(@{@"action":@"voice", @"data":@{@"session":@"recording-1",
    @"mode":@"message", @"phase":@"recorded", @"clipId":@"retained-clip"}});
  check(ios_events.count == 3, "meter backlog swallowed Send or recording completion");
  check([next() containsString:@"299900"], "latest meter value was not retained");
  check([next() isEqual:@"button · Send voice message"], "Send must precede completion");
  check([next() containsString:@"retained-clip"], "recorded clip event was lost");

  tick(@"recording-1", 100); ios_deliver(@"button · Stop recording", nil, 0);
  tick(@"recording-1", 200); tick(@"recording-1", 300);
  tick(@"recording-2", 400);
  check(ios_events.count == 4, "coalescing crossed a control or session boundary");
  check([next() containsString:@"100"], "pre-click meter moved");
  check([next() isEqual:@"button · Stop recording"], "Stop moved behind a meter");
  check([next() containsString:@"300"], "adjacent post-click meters not coalesced");
  check([next() containsString:@"recording-2"], "distinct physical session merged");

  tick(@"recording-2", 450);
  ios_action(@{@"action":@"voice", @"data":@{@"session":@"recording-2",
    @"mode":@"call", @"phase":@"elapsed", @"elapsedMs":@460}});
  check(ios_events.count == 2, "different voice modes were merged");
  next(); next();

  ios_deliver(@"draft one", @"Message", 1); ios_deliver(@"draft two", @"Message", 2);
  tick(@"recording-2", 500); ios_deliver(@"button · Cancel", nil, 0);
  check([next() isEqual:@"draft two"], "text edit coalescing regressed");
  check(ios_has_read(@"Message", 2), "text edit acknowledgment regressed");
  check([next() containsString:@"500"], "meter missing after text edit");
  check([next() isEqual:@"button · Cancel"], "Cancel was lost");
  puts("Native voice meter saturation, control ordering, and edit acknowledgment passed.");
} }
`);
  const executable = join(directory, 'events');
  execFileSync('xcrun', ['clang', '-x', 'objective-c', '-fobjc-arc', '-framework', 'Foundation', source, '-o', executable], { stdio: 'inherit' });
  execFileSync(executable, [], { stdio: 'inherit' });
} finally {
  rmSync(directory, { recursive: true, force: true });
}
