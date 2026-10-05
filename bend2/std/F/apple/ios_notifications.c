#import <UserNotifications/UserNotifications.h>

static NSString* const ios_notifications_enabled = @"dot-notifications-enabled";
static NSString* const ios_notifications_prompted = @"dot-notifications-prompted";
static NSString* const ios_notifications_device = @"dot-notifications-device";

static BOOL ios_notification_payload(NSDictionary* userInfo) {
  id dot = userInfo[@"dot"];
  if (![dot isKindOfClass:NSDictionary.class]) return NO;
  id event = dot[@"eventId"], thread = dot[@"threadId"], kind = dot[@"kind"];
  return [event isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:event] != nil &&
    [thread isKindOfClass:NSString.class] && [thread length] > 0 && [thread length] <= 160 &&
    [@[@"completed", @"attention"] containsObject:kind ?: @""];
}

@interface BendIOSNotifications : NSObject <UNUserNotificationCenterDelegate, NSURLSessionTaskDelegate>
@property(strong) NSString* token;
@property(strong) NSString* device;
@property(strong) NSString* environment;
@property(strong) NSString* registrationError;
@property(strong) NSURLSession* session;
@property BOOL checkingPrompt;
- (void)active;
- (void)settings:(UIViewController*)controller;
- (void)registered:(NSData*)token;
- (void)registrationFailed;
@end

static BendIOSNotifications* ios_notifications;

@implementation BendIOSNotifications
- (instancetype)init {
  if (!(self = [super init])) return nil;
  self.device = [NSUserDefaults.standardUserDefaults stringForKey:ios_notifications_device];
  if (![[NSUUID alloc] initWithUUIDString:self.device ?: @""]) {
    self.device = NSUUID.UUID.UUIDString;
    [NSUserDefaults.standardUserDefaults setObject:self.device forKey:ios_notifications_device];
  }
  self.environment = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendAPNSEnvironment"] ?: @"";
  NSURLSessionConfiguration* config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 10;
  config.waitsForConnectivity = NO;
  self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
  UNUserNotificationCenter.currentNotificationCenter.delegate = self;
  return self;
}
- (BOOL)spanish { return [NSLocale.preferredLanguages.firstObject.lowercaseString hasPrefix:@"es"]; }
- (NSString*)text:(NSString*)english spanish:(NSString*)spanish { return self.spanish ? spanish : english; }
- (BOOL)pushBuild { return [@[@"development", @"production"] containsObject:self.environment]; }
- (void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task
  willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request
  completionHandler:(void (^)(NSURLRequest*))complete { complete(nil); }
- (void)request:(NSString*)path body:(NSDictionary*)body completion:(void (^)(NSDictionary*))completion {
  NSURL* url = [NSURL URLWithString:path relativeToURL:ios_origin].absoluteURL;
  if (!ios_same_origin(url)) { if (completion) completion(nil); return; }
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
  if (body) {
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:ios_origin.absoluteString forHTTPHeaderField:@"Origin"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
  }
  [[self.session dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
    NSHTTPURLResponse* http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse*)response : nil;
    id result = !error && http.statusCode >= 200 && http.statusCode < 300 && data.length <= 16384
      ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (completion) completion([result isKindOfClass:NSDictionary.class] ? result : nil);
  }] resume];
}
- (void)registerDevice:(BOOL)enabled {
  if (enabled && (!self.token.length || !self.pushBuild)) return;
  NSMutableDictionary* body = [@{@"deviceId":self.device, @"enabled":@(enabled)} mutableCopy];
  if (enabled) [body addEntriesFromDictionary:@{@"token":self.token, @"environment":self.environment,
    @"language":self.spanish ? @"es" : @"en"}];
  [self request:@"/api/notifications/device" body:body completion:^(NSDictionary* result) {
    self.registrationError = result ? nil : [self text:@"Couldn’t connect notifications. Reopen Dot to retry."
      spanish:@"No se pudieron conectar las notificaciones. Vuelve a abrir Dot para reintentar."];
  }];
}
- (void)active {
  [UNUserNotificationCenter.currentNotificationCenter setBadgeCount:0 withCompletionHandler:nil];
  [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
    dispatch_async(dispatch_get_main_queue(), ^{
      BOOL allowed = settings.authorizationStatus == UNAuthorizationStatusAuthorized || settings.authorizationStatus == UNAuthorizationStatusProvisional;
      if ([NSUserDefaults.standardUserDefaults boolForKey:ios_notifications_enabled] && allowed && self.pushBuild)
        [UIApplication.sharedApplication registerForRemoteNotifications];
      else [self registerDevice:NO];
      if (self.pushBuild && settings.authorizationStatus == UNAuthorizationStatusNotDetermined &&
          ![NSUserDefaults.standardUserDefaults boolForKey:ios_notifications_prompted] && !self.checkingPrompt) {
        self.checkingPrompt = YES;
        [self request:@"/api/notifications/status" body:nil completion:^(NSDictionary* remote) {
          self.checkingPrompt = NO;
          if ([remote[@"configured"] boolValue] && [remote[@"available"] boolValue] &&
              UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
              ![NSUserDefaults.standardUserDefaults boolForKey:ios_notifications_prompted]) {
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:ios_notifications_prompted];
            [self enable];
          }
        }];
      }
    });
  }];
}
- (void)registered:(NSData*)token {
  const unsigned char* bytes = token.bytes;
  NSMutableString* value = [NSMutableString stringWithCapacity:token.length * 2];
  for (NSUInteger index = 0; index < token.length; index++) [value appendFormat:@"%02x", bytes[index]];
  self.token = value; self.registrationError = nil;
  if ([NSUserDefaults.standardUserDefaults boolForKey:ios_notifications_enabled]) [self registerDevice:YES];
}
- (void)registrationFailed {
  self.registrationError = [self text:@"Background notifications could not connect. Reopen Dot to retry."
    spanish:@"No se pudieron conectar las notificaciones. Vuelve a abrir Dot para reintentar."];
}
- (void)enable {
  [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
    completionHandler:^(BOOL granted, NSError* error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [NSUserDefaults.standardUserDefaults setBool:granted forKey:ios_notifications_enabled];
        if (granted) [self active]; else [self registerDevice:NO];
      });
    }];
}
- (void)settings:(UIViewController*)controller {
  [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self request:@"/api/notifications/status" body:nil completion:^(NSDictionary* remote) {
        if (controller.presentedViewController) return;
        BOOL enabled = [NSUserDefaults.standardUserDefaults boolForKey:ios_notifications_enabled];
        BOOL denied = settings.authorizationStatus == UNAuthorizationStatusDenied;
        NSString* message = [self text:@"Get an alert when Near’s reply is ready or Dot needs your attention. No alerts while you’re using Dot."
          spanish:@"Recibe un aviso cuando la respuesta de Near esté lista o Dot necesite tu atención. Sin avisos mientras usas Dot."];
        if (!self.pushBuild || (remote && ![remote[@"configured"] boolValue]))
          message = [message stringByAppendingFormat:@"\n\n%@", [self text:@"Background delivery isn’t configured for this build yet."
            spanish:@"Los avisos en segundo plano aún no están configurados para esta versión."]];
        else if (self.registrationError || ![remote[@"available"] boolValue])
          message = [message stringByAppendingFormat:@"\n\n%@", self.registrationError ?: [self text:@"Open Dot couldn’t reach the notification service."
            spanish:@"Dot no pudo conectar con el servicio de notificaciones."]];
        UIAlertController* sheet = [UIAlertController alertControllerWithTitle:[self text:@"Notifications" spanish:@"Notificaciones"]
          message:message preferredStyle:UIAlertControllerStyleAlert];
        if (denied) [sheet addAction:[UIAlertAction actionWithTitle:[self text:@"Open Settings" spanish:@"Abrir Ajustes"] style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
          [UIApplication.sharedApplication openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
        }]];
        else [sheet addAction:[UIAlertAction actionWithTitle:enabled ? [self text:@"Turn Off" spanish:@"Desactivar"] : [self text:@"Allow Notifications" spanish:@"Permitir notificaciones"]
          style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
            if (enabled) {
              [NSUserDefaults.standardUserDefaults setBool:NO forKey:ios_notifications_enabled];
              [self registerDevice:NO];
              [UIApplication.sharedApplication unregisterForRemoteNotifications];
              [UNUserNotificationCenter.currentNotificationCenter removeAllDeliveredNotifications];
            } else [self enable];
          }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[self text:@"Close" spanish:@"Cerrar"] style:UIAlertActionStyleCancel handler:nil]];
        [controller presentViewController:sheet animated:YES completion:nil];
      }];
    });
  }];
}
- (void)userNotificationCenter:(UNUserNotificationCenter*)center willPresentNotification:(UNNotification*)notification
  withCompletionHandler:(void (^)(UNNotificationPresentationOptions))complete {
  // Foreground replies are already visible in the conversation.
  complete(UNNotificationPresentationOptionNone);
}
- (void)userNotificationCenter:(UNUserNotificationCenter*)center didReceiveNotificationResponse:(UNNotificationResponse*)response
  withCompletionHandler:(void (^)(void))complete {
  if ([response.actionIdentifier isEqual:UNNotificationDefaultActionIdentifier] && ios_notification_payload(response.notification.request.content.userInfo))
    ios_action(@{@"action":@"notification-open"});
  complete();
}
@end
