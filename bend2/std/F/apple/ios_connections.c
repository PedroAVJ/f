// Configured HTTPS connections share a renderer, never a pending-send namespace.
static void ios_connection_keys(NSDictionary* connection) {
  ios_connection_id = connection[@"id"];
  ios_origin = [NSURL URLWithString:connection[@"origin"]];
  NSString* primary = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendOrigin"];
  NSURL* primaryURL = [NSURL URLWithString:primary ?: @""];
  if ([ios_origin.host.lowercaseString isEqual:primaryURL.host.lowercaseString] && [ios_port(ios_origin) isEqual:ios_port(primaryURL)]) ios_storage_scope = @"";
  else {
    NSData* bytes = [ios_origin.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, hash);
    NSMutableString* scope = [NSMutableString string];
    for (unsigned i = 0; i < sizeof(hash); ++i) [scope appendFormat:@"%02x", hash[i]];
    ios_storage_scope = scope;
  }
  ios_pending_key = ios_scoped_key(@"dot-pending-request");
  ios_audio_draft_key = ios_scoped_key(@"bend-audio-draft");
  ios_image_draft_key = ios_scoped_key(@"bend-image-draft");
  ios_file_draft_key = ios_scoped_key(@"bend-file-draft");
  ios_notifications_enabled = ios_scoped_key(@"dot-notifications-enabled");
  ios_notifications_prompted = ios_scoped_key(@"dot-notifications-prompted");
  ios_notifications_device = ios_scoped_key(@"dot-notifications-device");
}

static void ios_connections_init(void) {
  id configured = [NSBundle.mainBundle objectForInfoDictionaryKey:@"BendConnections"];
  NSMutableArray* valid = [NSMutableArray array];
  NSMutableSet* identifiers = [NSMutableSet set];
  NSMutableSet* origins = [NSMutableSet set];
  if ([configured isKindOfClass:NSArray.class] && [configured count] <= 64) for (id item in configured) {
    if (![item isKindOfClass:NSDictionary.class]) continue;
    NSString* identifier = item[@"id"], *name = item[@"name"], *subtitle = item[@"subtitle"], *origin = item[@"origin"];
    if (![identifier isKindOfClass:NSString.class] || !identifier.length || identifier.length > 64 ||
        [identifier rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"].invertedSet].location != NSNotFound ||
        ![name isKindOfClass:NSString.class] || !name.length || name.length > 80 ||
        ![subtitle isKindOfClass:NSString.class] || subtitle.length > 200 || ![origin isKindOfClass:NSString.class]) continue;
    NSURL* url = [NSURL URLWithString:origin];
    if (![url.scheme.lowercaseString isEqual:@"https"] || !url.host.length || url.user.length || url.password.length ||
        (url.path.length && ![url.path isEqual:@"/"]) || url.query.length || url.fragment.length ||
        [identifiers containsObject:identifier] || [origins containsObject:origin]) continue;
    [identifiers addObject:identifier]; [origins addObject:origin];
    [valid addObject:@{@"id":identifier, @"name":name, @"subtitle":subtitle, @"origin":origin}];
  }
  if (!valid.count && ios_origin.host.length) {
    NSString* name = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"";
    [valid addObject:@{@"id":@"default", @"name":name, @"subtitle":@"", @"origin":ios_origin.absoluteString}];
  }
  ios_connections = [valid copy];
  NSString* selected = [NSUserDefaults.standardUserDefaults stringForKey:@"bend-selected-connection"];
  NSDictionary* connection = valid.firstObject;
  for (NSDictionary* item in valid) if ([item[@"id"] isEqual:selected]) connection = item;
  if (connection) ios_connection_keys(connection);
}

static char* ios_connection_request(NSString* text, unsigned* status) {
  id spec = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if (![spec isKindOfClass:NSDictionary.class] || ![@[@"catalog", @"select"] containsObject:spec[@"action"] ?: @""])
    return ios_dup(@"invalid connection request");
  __block NSString* problem = nil;
  __block NSString* output = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    if ([spec[@"action"] isEqual:@"select"]) {
      NSDictionary* selected = nil;
      for (NSDictionary* item in ios_connections) if ([item[@"id"] isEqual:spec[@"dotId"]]) selected = item;
      if (!selected) { problem = @"unknown connection"; return; }
      NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
      if (![selected[@"id"] isEqual:ios_connection_id]) {
        if (atomic_load(&ios_active) > 1 || ios_voice.recorder || ios_voice.callConnected || ios_voice.finishing ||
            ios_voice.player.playing || ios_voice.speaker.speaking || ios_voice.engine.running || ios_voice.fileTask ||
            [@[@"loading", @"authorizing"] containsObject:ios_voice.phase ?: @""] ||
            ios_image.picker || ios_image.camera || ios_image.loading || ios_image.activeLoads.count ||
            ios_file.selecting || ios_file.loading ||
            [defaults dictionaryForKey:ios_pending_key] || [defaults dictionaryForKey:ios_audio_draft_key] ||
            [defaults dictionaryForKey:ios_image_draft_key] || [defaults dictionaryForKey:ios_file_draft_key]) {
          problem = @"finish or discard pending media before switching connections"; return;
        }
        [defaults setObject:selected[@"id"] forKey:@"bend-selected-connection"];
        if (![defaults synchronize] || ![[defaults stringForKey:@"bend-selected-connection"] isEqual:selected[@"id"]]) {
          problem = @"connection selection could not be saved"; return;
        }
        [ios_controller.view endEditing:YES];
        for (BendIOSEditor* field in ios_controller.fields.allValues) [field removeFromSuperview];
        ios_controller.fields = [NSMutableDictionary dictionary];
        ios_controller.restoredPending = NO;
        ios_controller.hasConversation = NO; ios_controller.connectionList = NO; ios_controller.messageDetail = NO;
        ios_controller.savedConversationOffset = CGPointZero;
        NSString* token = ios_notifications.token;
        [ios_notifications.session invalidateAndCancel];
        ios_connection_keys(selected);
        ios_notifications = [BendIOSNotifications new]; ios_notifications.token = token;
        [ios_voice stopAll];
        ++ios_image.generation; [ios_image.loading cancel];
        ++ios_file.generation;
        ios_voice = nil; ios_image = nil; ios_file = nil;
        ios_boot_pending = [[defaults dictionaryForKey:ios_pending_key] copy];
      }
      pthread_mutex_lock(&ios_lock);
      [ios_events removeAllObjects]; [ios_read removeAllObjects];
      pthread_mutex_unlock(&ios_lock);
      ios_session_prefix = NSUUID.UUID.UUIDString;
      ios_action(@{@"action":@"session", @"value":ios_session_prefix});
    }
    NSMutableArray* dots = [NSMutableArray array];
    for (NSDictionary* item in ios_connections) [dots addObject:@{@"id":item[@"id"], @"name":item[@"name"], @"subtitle":item[@"subtitle"]}];
    output = ios_json(@{@"dots":dots, @"selectedDotId":ios_connection_id ?: @"", @"session":ios_session_prefix ?: @""});
  });
  *status = problem ? 2 : 1;
  return ios_dup(problem ?: output);
}
