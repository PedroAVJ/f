import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const source = readFileSync(resolve(import.meta.dir, '../../../bend2/std/F/apple/ios_notifications.c'), 'utf8');
const start = source.indexOf('static BOOL ios_notification_payload(');
const end = source.indexOf('@interface BendIOSNotifications', start);
if (start < 0 || end < start) throw Error('Notification validation source boundary changed.');
const directory = mkdtempSync(join(tmpdir(), 'dot-ios-notifications-'));
try {
  const file = join(directory, 'notifications.m'), executable = join(directory, 'notifications');
  writeFileSync(file, `#import <Foundation/Foundation.h>
#include <stdio.h>
${source.slice(start, end)}
int main(void) { @autoreleasepool {
  NSString* event = @"be910e35-0c45-47aa-acd2-dc81414d14c4";
  if (!ios_notification_payload(@{@"dot":@{@"eventId":event,@"threadId":@"one",@"kind":@"completed"}})) return 1;
  if (!ios_notification_payload(@{@"dot":@{@"eventId":event,@"threadId":@"one",@"kind":@"attention"}})) return 2;
  if (ios_notification_payload(@{@"dot":@{@"eventId":@"bad",@"threadId":@"one",@"kind":@"completed"}})) return 3;
  if (ios_notification_payload(@{@"dot":@{@"eventId":event,@"threadId":@"",@"kind":@"completed"}})) return 4;
  if (ios_notification_payload(@{@"dot":@{@"eventId":event,@"threadId":@"one",@"kind":@"open-url"}})) return 5;
  if (ios_notification_payload(@{@"dot":@"not an object"})) return 6;
  puts("Native notification payload validation passed.");
} }
`);
  execFileSync('xcrun', ['clang', '-x', 'objective-c', '-fobjc-arc', '-framework', 'Foundation', file, '-o', executable], { stdio: 'inherit' });
  execFileSync(executable, [], { stdio: 'inherit' });
} finally { rmSync(directory, { recursive: true, force: true }); }
