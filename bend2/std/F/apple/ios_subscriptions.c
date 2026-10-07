// The application supplies sources and endpoint policy; this host only transports JSON.
@interface BendIOSSubscription : NSObject <NSURLSessionTaskDelegate>
@property(copy) NSString* source;
@property(copy) NSString* origin;
@property(strong) NSURL* url;
@property(strong) NSURLSession* session;
@property(strong) NSURLSessionWebSocketTask* task;
@property NSUInteger limit;
@property NSUInteger generation;
@property NSUInteger failures;
@property BOOL stopped;
@property BOOL terminal;
- (void)connect;
- (void)stop;
@end

static NSMutableDictionary<NSString*, BendIOSSubscription*>* ios_subscriptions;
static BOOL ios_subscriptions_paused;

@implementation BendIOSSubscription
- (void)emit:(id)value {
  NSDictionary* event = @{@"action":@"subscription-event", @"source":self.source, @"value":value};
  NSString* text = ios_json(event);
  if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > IOS_LIMIT) {
    self.terminal = YES;
    event = @{@"action":@"subscription-event", @"source":self.source,
      @"value":@{@"type":@"subscription-error", @"error":@"Subscription event exceeds 1 MiB."}};
  }
  ios_action(event);
}
- (void)stop {
  self.stopped = YES; ++self.generation;
  [self.task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
  self.task = nil;
  [self.session invalidateAndCancel]; self.session = nil;
}
- (void)failed:(NSString*)message {
  if (self.stopped || self.terminal) return;
  [self emit:@{@"type":@"subscription-unavailable", @"error":message}];
  [self.task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeGoingAway reason:nil];
  self.task = nil;
  [self.session invalidateAndCancel]; self.session = nil;
  NSUInteger generation = ++self.generation;
  self.failures = MIN(self.failures + 1, 5u);
  NSTimeInterval delay = MIN(30., (double)(1u << self.failures));
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (!self.stopped && !self.terminal && !ios_subscriptions_paused && self.generation == generation) [self connect];
  });
}
- (void)receive:(NSURLSessionWebSocketTask*)task {
  [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage* message, NSError* error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.stopped || self.task != task) return;
      if (error) {
        if (error.code == NSURLErrorDataLengthExceedsMaximum) {
          self.terminal = YES;
          [self emit:@{@"type":@"subscription-error", @"error":@"Subscription event exceeds the configured limit."}];
          [self stop];
        } else [self failed:error.localizedDescription ?: @"Subscription disconnected."];
        return;
      }
      NSData* data = message.type == NSURLSessionWebSocketMessageTypeString
        ? [message.string dataUsingEncoding:NSUTF8StringEncoding] : message.data;
      id value = data.length <= self.limit ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
      if (!value) {
        self.terminal = YES;
        [self emit:@{@"type":@"subscription-error", @"error":@"Subscription returned invalid or oversized JSON."}];
      } else {
        self.failures = 0;
        [self emit:value];
      }
      if (self.terminal) [self stop]; else [self receive:task];
    });
  }];
}
- (void)connect {
  if (self.stopped || self.terminal || ios_subscriptions_paused || self.task) return;
  NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.waitsForConnectivity = NO;
  configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
  self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:NSOperationQueue.mainQueue];
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:self.url];
  [request setValue:self.origin forHTTPHeaderField:@"Origin"];
  self.task = [self.session webSocketTaskWithRequest:request];
  self.task.maximumMessageSize = self.limit;
  [self.task resume]; [self receive:self.task];
}
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task
  willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request
  completionHandler:(void (^)(NSURLRequest*))complete {
  complete(nil);
}
@end

static void ios_subscriptions_clear(void) {
  for (BendIOSSubscription* stream in ios_subscriptions.allValues) [stream stop];
  [ios_subscriptions removeAllObjects];
}

static void ios_subscriptions_pause(BOOL paused) {
  BOOL resumed = ios_subscriptions_paused && !paused;
  ios_subscriptions_paused = paused;
  if (resumed) ios_action(@{@"action":@"subscriptions-resumed"});
  for (BendIOSSubscription* stream in ios_subscriptions.allValues) {
    if (paused) [stream stop];
    else if (!stream.terminal) { stream.stopped = NO; [stream connect]; }
  }
}

static char* ios_subscriptions_request(NSString* text, unsigned* status) {
  id value = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if (![value isKindOfClass:NSDictionary.class]) return ios_dup(@"Subscriptions require a JSON object.");
  id endpoint = value[@"endpoint"], parameter = value[@"parameter"], sources = value[@"sources"], maxBytes = value[@"maxBytes"];
  if (![endpoint isKindOfClass:NSString.class] || ![endpoint hasPrefix:@"/"] || [endpoint hasPrefix:@"//"] ||
      ![parameter isKindOfClass:NSString.class] || ![parameter length] || [parameter length] > 64 ||
      ![sources isKindOfClass:NSArray.class] || [sources count] > 64 ||
      ![maxBytes isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)maxBytes) == CFBooleanGetTypeID() ||
      [maxBytes doubleValue] != (double)[maxBytes unsignedIntegerValue] || [maxBytes unsignedIntegerValue] < 1 || [maxBytes unsignedIntegerValue] > IOS_LIMIT)
    return ios_dup(@"Invalid subscription configuration.");
  NSURL* base = [NSURL URLWithString:endpoint relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(base) || base.query.length || base.fragment.length) return ios_dup(@"Subscriptions require the configured HTTPS origin.");
  NSMutableDictionary* wanted = [NSMutableDictionary dictionary];
  for (id source in sources) {
    if (![source isKindOfClass:NSString.class] || ![source length] || [source length] > 2048) return ios_dup(@"Invalid subscription source.");
    NSURLComponents* url = [NSURLComponents componentsWithURL:base resolvingAgainstBaseURL:YES];
    url.scheme = @"wss";
    url.queryItems = @[[NSURLQueryItem queryItemWithName:parameter value:source]];
    if (!url.URL) return ios_dup(@"Invalid subscription URL.");
    wanted[source] = url.URL;
  }
  __block NSString* origin = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    NSURLComponents* originURL = [NSURLComponents componentsWithURL:ios_origin resolvingAgainstBaseURL:YES];
    originURL.path = @""; originURL.query = nil; originURL.fragment = nil;
    origin = originURL.string;
    if (!ios_subscriptions) ios_subscriptions = [NSMutableDictionary dictionary];
    for (NSString* source in ios_subscriptions.allKeys) {
      BendIOSSubscription* stream = ios_subscriptions[source];
      if (![wanted[source] isEqual:stream.url] || stream.limit != [maxBytes unsignedIntegerValue] || ![stream.origin isEqual:origin]) {
        [stream stop]; [ios_subscriptions removeObjectForKey:source];
      }
    }
    for (NSString* source in wanted) if (!ios_subscriptions[source]) {
      BendIOSSubscription* stream = [BendIOSSubscription new];
      stream.source = source; stream.url = wanted[source]; stream.origin = origin;
      stream.limit = [maxBytes unsignedIntegerValue]; ios_subscriptions[source] = stream;
      [stream connect];
    }
  });
  *status = 1; return ios_dup(@"");
}
