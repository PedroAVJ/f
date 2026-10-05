import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const host = readFileSync(resolve(import.meta.dir, '../../f/bend2/std/F/apple/ios_shell.c'), 'utf8');
const start = host.indexOf('static char* ios_canvas(');
const end = host.indexOf('char* bend_native_request(', start);
if (start < 0 || end <= start) throw Error('Native canvas source boundaries changed.');
const directory = mkdtempSync(join(tmpdir(), 'dot-ios-refresh-'));
try {
  const source = join(directory, 'refresh.m');
  writeFileSync(source, `#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
@interface TestController : NSObject
@property BOOL reading;
@property unsigned paints;
@property(strong) NSArray* commands;
- (BOOL)canRefreshConversation;
- (void)apply:(NSArray*)commands;
@end
@implementation TestController
- (BOOL)canRefreshConversation { return !self.reading; }
- (void)apply:(NSArray*)commands { self.commands = commands; self.paints++; }
@end
static TestController* ios_controller;
static BOOL startReadingDuringPreparation;
static char* ios_dup(NSString* text) { return strdup(text.UTF8String); }
static NSString* bend_paint_check(id commands) { return nil; }
static NSArray* ios_content_projection(NSArray* commands) { return commands; }
static NSString* bend_paint_prepare(id commands) {
  if (startReadingDuringPreparation) dispatch_sync(dispatch_get_main_queue(), ^{
    ios_controller.reading = YES;
  });
  return nil;
}
${host.slice(start, end)}
static void check(BOOL value, const char* message) {
  if (!value) { fprintf(stderr, "%s\\n", message); exit(1); }
}
int main(void) { @autoreleasepool {
  ios_controller = [TestController new];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ @autoreleasepool {
    const char* first = "[[\\"frame\\",390,1000]]";
    const char* next = "[[\\"frame\\",390,2000]]";
    unsigned status; char* result = ios_canvas(first, (unsigned)strlen(first), &status, NO);
    free(result); check(status == 1, "initial paint failed");
    startReadingDuringPreparation = YES;
    result = ios_canvas(next, (unsigned)strlen(next), &status, YES);
    check(status == 3 && strcmp(result, "conversation refresh deferred") == 0,
      "scrolling begun during candidate preparation did not defer refresh");
    free(result);
    check(ios_controller.paints == 1 && [ios_controller.commands[0][2] intValue] == 1000,
      "deferred refresh changed displayed commands or content extent");
    startReadingDuringPreparation = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{ ios_controller.reading = NO; });
    result = ios_canvas(next, (unsigned)strlen(next), &status, YES); free(result);
    check(status == 1 && ios_controller.paints == 2, "refresh did not resume at bottom");
    dispatch_sync(dispatch_get_main_queue(), ^{ ios_controller.reading = YES; });
    result = ios_canvas(first, (unsigned)strlen(first), &status, NO); free(result);
    check(status == 1 && ios_controller.paints == 3, "manual navigation was deferred");
    result = ios_canvas("{", 1, &status, YES); free(result);
    check(status == 2, "invalid canvas was mistaken for scroll deferral");
    puts("Native refresh commit, delayed scrolling, resume, and manual navigation passed.");
    exit(0);
  }});
  dispatch_main();
} }
`);
  const executable = join(directory, 'refresh');
  execFileSync('xcrun', ['clang', '-x', 'objective-c', '-fobjc-arc', '-framework', 'Foundation', source, '-o', executable], { stdio: 'inherit' });
  execFileSync(executable, [], { stdio: 'inherit', timeout: 10000 });
} finally {
  rmSync(directory, { recursive: true, force: true });
}
