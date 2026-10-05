// Native audio transport for Bend. Recording produces a retained M4A clip;
// call transcripts and playback completion return to the Bend conversation.
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

#define IOS_AUDIO_LIMIT (16u << 20)
#define IOS_AUDIO_SECONDS 300
static NSString* ios_audio_draft_key = @"bend-audio-draft";

static NSString* ios_audio_words(NSString* english, NSString* spanish) {
  return [NSLocale.preferredLanguages.firstObject.lowercaseString hasPrefix:@"es"] ? spanish : english;
}

static BOOL ios_clip_id(NSString* value) {
  return [value isKindOfClass:NSString.class] &&
    [[NSUUID alloc] initWithUUIDString:value] != nil;
}

static BOOL ios_audio_cache_id(NSString* value) {
  if (ios_clip_id(value)) return YES;
  if (![value isKindOfClass:NSString.class] || value.length != 64) return NO;
  NSCharacterSet* allowed = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
  return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}

static NSLocale* ios_speech_locale(NSString* requested) {
  NSLocale* locale = [NSLocale localeWithLocaleIdentifier:requested ?: NSLocale.preferredLanguages.firstObject ?: @"en-US"];
  NSSet<NSLocale*>* supported = SFSpeechRecognizer.supportedLocales;
  NSString* normalized = [locale.localeIdentifier stringByReplacingOccurrencesOfString:@"_" withString:@"-"].lowercaseString;
  for (NSLocale* candidate in supported)
    if ([[candidate.localeIdentifier stringByReplacingOccurrencesOfString:@"_" withString:@"-"].lowercaseString isEqual:normalized]) return candidate;
  NSString* primary = [locale.languageCode isEqual:@"es"] ? @"es-MX" : [locale.languageCode isEqual:@"en"] ? @"en-US" : nil;
  for (NSLocale* candidate in supported) if ([candidate.localeIdentifier isEqual:primary]) return candidate;
  NSArray* ordered = [supported.allObjects sortedArrayUsingComparator:^NSComparisonResult(NSLocale* a, NSLocale* b) {
    return [a.localeIdentifier compare:b.localeIdentifier];
  }];
  for (NSLocale* candidate in ordered) if ([candidate.languageCode isEqual:locale.languageCode]) return candidate;
  return locale;
}

static NSURL* ios_audio_file(NSString* clip, BOOL partial) {
  if (partial ? !ios_clip_id(clip) : !ios_audio_cache_id(clip)) return nil;
  NSURL* directory = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
    inDomains:NSUserDomainMask].firstObject;
  directory = ios_scoped_directory(directory);
  directory = [directory URLByAppendingPathComponent:@"BendAudio" isDirectory:YES];
  NSError* error = nil;
  if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
    attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:&error]) return nil;
  NSString* name = [clip stringByAppendingString:partial ? @".partial.m4a" : @".m4a"];
  return [directory URLByAppendingPathComponent:name isDirectory:NO];
}

static BOOL ios_audio_draft(NSDictionary* metadata) {
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  @synchronized(defaults) {
    [defaults setObject:metadata forKey:ios_audio_draft_key];
    return [defaults synchronize] && [[defaults dictionaryForKey:ios_audio_draft_key] isEqual:metadata];
  }
}

static void ios_audio_acknowledged(NSDictionary* pending) {
  if (!ios_clip_id(pending[@"clipId"])) return;
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
  NSDictionary* draft = [defaults dictionaryForKey:ios_audio_draft_key];
  if (![draft[@"clipId"] isEqual:pending[@"clipId"]]) return;
  if ([pending[@"processing"] isEqual:@"server"]) {
    [defaults removeObjectForKey:ios_audio_draft_key];
    return;
  }
  NSString* transcript = [pending[@"transcript"] isKindOfClass:NSString.class] ? pending[@"transcript"] : @"";
  if (![transcript stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) {
    // Storage acknowledgment does not mean the provider received context.
    // Retain the clip and the original receipt ID for a transcription retry.
    NSMutableDictionary* retry = [draft mutableCopy];
    for (NSString* key in @[@"requestId", @"threadId", @"provider"])
      if ([pending[key] isKindOfClass:NSString.class]) retry[key] = pending[key];
    ios_audio_draft(retry);
  } else [defaults removeObjectForKey:ios_audio_draft_key];
}

@interface BendIOSVoice : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate,
  AVSpeechSynthesizerDelegate>
@property(copy) NSString* session;
@property(copy) NSString* mode;
@property(copy) NSString* phase;
@property(copy) NSString* clip;
@property(copy) NSString* locale;
@property(strong) AVAudioRecorder* recorder;
@property(strong) AVAudioPlayer* player;
@property(strong) AVAudioEngine* engine;
@property(strong) SFSpeechRecognizer* recognizer;
@property(strong) SFSpeechAudioBufferRecognitionRequest* recognition;
@property(strong) SFSpeechRecognitionTask* task;
@property(strong) AVSpeechSynthesizer* speaker;
@property(strong) AVSpeechUtterance* utterance;
@property(strong) NSTimer* endpoint;
@property(strong) NSTimer* callTimer;
@property(strong) NSTimer* recordingTimer;
@property(strong) SFSpeechRecognitionTask* fileTask;
@property(strong) SFSpeechRecognizer* fileRecognizer;
@property(copy) NSString* transcript;
@property NSUInteger generation;
@property NSUInteger captureGeneration;
@property NSTimeInterval lastTextAt;
@property NSTimeInterval lastSoundAt;
@property NSTimeInterval listenStartedAt;
@property NSTimeInterval callStartedAt;
@property NSTimeInterval recordStartedAt;
@property BOOL callConnected;
@property BOOL serverTranscription;
@property BOOL tapInstalled;
@property BOOL muted;
@property BOOL loudspeaker;
@property BOOL finishing;
@property BOOL awaitingReply;
- (NSString*)command:(NSDictionary*)command;
- (void)background;
@end

static BendIOSVoice* ios_voice;

@implementation BendIOSVoice
- (instancetype)init {
  self = [super init];
  if (self) {
    _speaker = [AVSpeechSynthesizer new]; _speaker.delegate = self;
    _phase = @"idle"; _loudspeaker = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)
      name:AVAudioSessionInterruptionNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(routeChanged:)
      name:AVAudioSessionRouteChangeNotification object:nil];
  }
  return self;
}
- (NSDictionary*)state:(NSString*)phase extra:(NSDictionary*)extra {
  NSMutableDictionary* state = [@{@"session":self.session ?: @"", @"mode":self.mode ?: @"",
    @"phase":phase ?: self.phase, @"muted":@(self.muted), @"speaker":@(self.loudspeaker),
    @"text":@"", @"error":@""} mutableCopy];
  if ([self.mode isEqual:@"call"]) state[@"elapsedMs"] = @(self.callStartedAt > 0 ?
    (unsigned)floor((NSProcessInfo.processInfo.systemUptime - self.callStartedAt) * 1000) : 0);
  else if (self.recorder && self.recordStartedAt > 0) state[@"elapsedMs"] =
    @((unsigned)floor((NSProcessInfo.processInfo.systemUptime - self.recordStartedAt) * 1000));
  if (extra) [state addEntriesFromDictionary:extra];
  // Clip metadata can carry a saved phase/session, but physical events belong
  // to the current controller and the transition that emitted them.
  state[@"session"] = self.session ?: @""; state[@"mode"] = self.mode ?: @"";
  state[@"phase"] = phase ?: self.phase;
  return state;
}
- (void)emit:(NSString*)phase extra:(NSDictionary*)extra {
  self.phase = phase;
  ios_action(@{@"action":@"voice", @"data":[self state:phase extra:extra]});
}
- (void)deactivate {
  [AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:NULL];
}
- (void)cancelCapture {
  ++self.captureGeneration;
  [self.endpoint invalidate]; self.endpoint = nil;
  [self.engine stop];
  if (self.tapInstalled) { [self.engine.inputNode removeTapOnBus:0]; self.tapInstalled = NO; }
  [self.recognition endAudio]; [self.task cancel];
  self.task = nil; self.recognition = nil; self.recognizer = nil; self.engine = nil;
  self.finishing = NO;
}
- (void)cancelRecording {
  [self.recordingTimer invalidate]; self.recordingTimer = nil;
  AVAudioRecorder* recorder = self.recorder; self.recorder = nil;
  recorder.delegate = nil; [recorder stop];
  if (recorder.url) [NSFileManager.defaultManager removeItemAtURL:recorder.url error:NULL];
}
- (void)stopAll {
  ++self.generation;
  [self.callTimer invalidate]; self.callTimer = nil;
  [self.fileTask cancel]; self.fileTask = nil;
  self.fileRecognizer = nil;
  [self cancelCapture]; [self cancelRecording];
  self.player.delegate = nil; [self.player stop]; self.player = nil;
  self.utterance = nil; [self.speaker stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
  [self deactivate];
}
- (void)failed:(NSString*)message {
  [self stopAll];
  [self emit:@"error" extra:@{@"error":message ?: ios_audio_words(@"Audio is unavailable.", @"Audio no disponible.")}];
}
- (BOOL)configure:(BOOL)voice error:(NSError**)error {
  AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionAllowBluetoothHFP;
  if (self.loudspeaker) options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
  return [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayAndRecord
    mode:voice ? AVAudioSessionModeVoiceChat : AVAudioSessionModeDefault options:options error:error] &&
    [AVAudioSession.sharedInstance setActive:YES error:error];
}
- (void)microphone:(NSUInteger)generation completion:(void (^)(void))completion {
  if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSMicrophoneUsageDescription"] length]) {
    [self failed:ios_audio_words(@"This build is missing its microphone permission description.", @"Falta el permiso del micrófono en esta compilación.")]; return;
  }
  [AVAudioApplication requestRecordPermissionWithCompletionHandler:^(BOOL granted) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation) return;
      if (!granted) [self failed:ios_audio_words(@"Allow microphone access in Settings to send audio and call.", @"Permite el micrófono en Ajustes para enviar audio y llamar.")];
      else completion();
    });
  }];
}
- (void)beginRecording {
  NSError* error = nil;
  NSURL* path = ios_audio_file(self.clip, YES);
  if (!path || ![self configure:NO error:&error]) {
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not prepare recording.", @"No se pudo preparar la grabación.")]; return;
  }
  self.recorder = [[AVAudioRecorder alloc] initWithURL:path settings:@{
    AVFormatIDKey:@(kAudioFormatMPEG4AAC), AVSampleRateKey:@44100, AVNumberOfChannelsKey:@1,
    AVEncoderBitRateKey:@64000, AVEncoderAudioQualityKey:@(AVAudioQualityHigh)} error:&error];
  self.recorder.delegate = self;
  self.recorder.meteringEnabled = self.serverTranscription;
  if (!self.recorder || ![self.recorder prepareToRecord] || ![self.recorder recordForDuration:IOS_AUDIO_SECONDS]) {
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not start the microphone.", @"No se pudo iniciar el micrófono.")]; return;
  }
  self.recordStartedAt = NSProcessInfo.processInfo.systemUptime;
  self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:(self.serverTranscription ? 0.1 : 1) target:self selector:@selector(recordTick:) userInfo:nil repeats:YES];
  [self emit:@"recording" extra:@{@"clipId":self.clip}];
}
- (void)recordTick:(NSTimer*)timer {
  [self.recorder updateMeters];
  float power = [self.recorder averagePowerForChannel:0];
  NSUInteger level = (NSUInteger)roundf(fmaxf(0, fminf(100, (power + 60) * (100.0f / 60))));
  ios_action(@{@"action":@"voice", @"data":[self state:@"elapsed" extra:@{@"clipId":self.clip ?: @"", @"level":@(level)}]});
}
- (void)finishRecording:(AVAudioRecorder*)recorder success:(BOOL)success {
  if (recorder != self.recorder) return;
  [self.recordingTimer invalidate]; self.recordingTimer = nil;
  self.recorder = nil; recorder.delegate = nil; [recorder stop];
  NSURL* path = ios_audio_file(self.clip, NO);
  NSError* error = nil;
  NSNumber* size = nil;
  [recorder.url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
  if (!success || !size || size.unsignedLongLongValue > IOS_AUDIO_LIMIT ||
    ![NSFileManager.defaultManager moveItemAtURL:recorder.url toURL:path error:&error]) {
    [NSFileManager.defaultManager removeItemAtURL:recorder.url error:NULL];
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not save the voice message.", @"No se pudo guardar el mensaje de voz.")]; return;
  }
  AVAudioPlayer* probe = [[AVAudioPlayer alloc] initWithContentsOfURL:path error:&error];
  if (!probe || !isfinite(probe.duration) || probe.duration <= 0) {
    [NSFileManager.defaultManager removeItemAtURL:path error:NULL];
    [self failed:error.localizedDescription ?: ios_audio_words(@"The recording contains no audio.", @"La grabación no contiene audio.")]; return;
  }
  [self deactivate];
  NSDictionary* metadata = @{@"clipId":self.clip, @"durationMs":@((unsigned)ceil(probe.duration * 1000)),
    @"mimeType":@"audio/mp4", @"transcript":@"", @"session":self.session,
    @"mode":@"message", @"phase":@"recorded", @"transcriptionStatus":@"pending"};
  if (!ios_audio_draft(metadata)) { [self failed:ios_audio_words(@"The audio is saved, but its draft could not be saved.", @"El audio está guardado, pero no se pudo guardar su borrador.")]; return; }
  if (self.serverTranscription) [self emit:@"recorded" extra:metadata];
  else [self transcribeFile:path metadata:metadata];
}
- (void)transcribeFile:(NSURL*)file metadata:(NSDictionary*)metadata {
  // The M4A is already durable. Speech supplies optional provider context;
  // denying or losing recognition never discards the voice message itself.
  NSUInteger generation = self.generation;
  [self emit:@"transcribing" extra:metadata];
  if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSSpeechRecognitionUsageDescription"] length]) {
    NSMutableDictionary* result = [metadata mutableCopy]; result[@"transcriptionStatus"] = @"missing";
    ios_audio_draft(result); [self emit:@"recorded" extra:result]; return;
  }
  __block BOOL finished = NO;
  void (^complete)(NSString*, NSString*) = ^(NSString* transcript, NSString* problem) {
    if (finished || generation != self.generation) return;
    finished = YES;
    SFSpeechRecognitionTask* task = self.fileTask; self.fileTask = nil; [task cancel];
    self.fileRecognizer = nil;
    NSMutableDictionary* result = [metadata mutableCopy];
    result[@"transcript"] = transcript ?: @"";
    result[@"transcriptionStatus"] = transcript.length ? @"ready" : @"missing";
    if (problem.length) result[@"transcriptionError"] = problem;
    else [result removeObjectForKey:@"transcriptionError"];
    if (!ios_audio_draft(result)) result[@"transcriptionError"] = ios_audio_words(@"The audio is saved, but its draft could not be updated.", @"El audio está guardado, pero no se pudo actualizar su borrador.");
    [self emit:@"recorded" extra:result];
  };
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (finished || generation != self.generation) return;
      if (status != SFSpeechRecognizerAuthorizationStatusAuthorized) {
        complete(@"", ios_audio_words(@"The audio is saved; transcription permission was not granted.", @"El audio está guardado; no se autorizó su transcripción.")); return;
      }
      NSString* locale = self.locale ?: NSLocale.preferredLanguages.firstObject ?: NSLocale.currentLocale.localeIdentifier;
      SFSpeechRecognizer* recognizer = [[SFSpeechRecognizer alloc] initWithLocale:ios_speech_locale(locale)];
      if (!recognizer.available) { complete(@"", ios_audio_words(@"The audio is saved; transcription is unavailable.", @"El audio está guardado; la transcripción no está disponible.")); return; }
      self.fileRecognizer = recognizer;
      SFSpeechURLRecognitionRequest* request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:file];
      request.shouldReportPartialResults = NO;
      if (recognizer.supportsOnDeviceRecognition) request.requiresOnDeviceRecognition = YES;
      self.fileTask = [recognizer recognitionTaskWithRequest:request resultHandler:^(SFSpeechRecognitionResult* result, NSError* problem) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (result.final) {
            NSString* text = result.bestTranscription.formattedString ?: @"";
            if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] <= 65536) complete(text, nil);
            else complete(@"", ios_audio_words(@"The audio is saved; its transcript exceeds the send limit.", @"El audio está guardado; su transcripción supera el límite de envío."));
          } else if (problem) complete(@"", problem.localizedDescription);
        });
      }];
    });
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    complete(@"", ios_audio_words(@"The audio is saved; transcription timed out.", @"El audio está guardado; la transcripción no terminó a tiempo."));
  });
}
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder*)recorder successfully:(BOOL)success {
  [self finishRecording:recorder success:success];
}
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder*)recorder error:(NSError*)error {
  if (recorder == self.recorder) [self failed:error.localizedDescription];
}
- (void)playData:(NSData*)data generation:(NSUInteger)generation {
  if (self.generation != generation) return;
  NSError* error = nil;
  if (!data.length || data.length > IOS_AUDIO_LIMIT ||
    ![AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:&error] ||
    ![AVAudioSession.sharedInstance setActive:YES error:&error]) {
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not open the audio.", @"No se pudo abrir el audio.")]; return;
  }
  self.player = [[AVAudioPlayer alloc] initWithData:data error:&error]; self.player.delegate = self;
  if (!self.player || !isfinite(self.player.duration) || self.player.duration <= 0 ||
    self.player.duration > IOS_AUDIO_SECONDS + 1 || ![self.player prepareToPlay] || ![self.player play]) {
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not play the voice message.", @"No se pudo reproducir el mensaje de voz.")]; return;
  }
  [self emit:@"playing" extra:@{@"clipId":self.clip ?: @"", @"durationMs":@((unsigned)ceil(self.player.duration * 1000))}];
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)success {
  if (player != self.player) return;
  self.player = nil; [self deactivate];
  [self emit:success ? @"played" : @"error" extra:success ? nil : @{@"error":ios_audio_words(@"Playback ended with an error.", @"La reproducción terminó con un error.")}];
}
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer*)player error:(NSError*)error {
  if (player == self.player) [self failed:error.localizedDescription];
}
- (void)finishListening {
  if (![self.phase isEqual:@"listening"] || self.finishing) return;
  self.finishing = YES;
  [self.endpoint invalidate]; self.endpoint = nil;
  [self.engine stop];
  if (self.tapInstalled) { [self.engine.inputNode removeTapOnBus:0]; self.tapInstalled = NO; }
  [self.recognition endAudio];
  NSUInteger generation = self.captureGeneration;
  // Recognition normally supplies a final result after endAudio; retain the
  // last acknowledged words if that callback is lost rather than dropping a turn.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    if (generation == self.captureGeneration && self.finishing) [self finishTranscript];
  });
}
- (void)finishTranscript {
  NSString* text = [self.transcript stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [self cancelCapture];
  if (text.length) { self.awaitingReply = YES; [self emit:@"transcript" extra:@{@"text":text}]; }
  else if (!self.muted) [self beginListening];
}
- (void)endpointTick:(NSTimer*)timer {
  NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
  if (self.transcript.length && now - self.lastTextAt >= 1.6 && now - self.lastSoundAt >= 1.2) [self finishListening];
  else if (now - self.listenStartedAt >= 50) [self finishListening];
}
- (void)beginListening {
  if (![self.mode isEqual:@"call"]) return;
  if (self.muted) { [self emit:@"muted" extra:nil]; return; }
  self.awaitingReply = NO;
  [self cancelCapture];
  self.transcript = @"";
  self.recognizer = [[SFSpeechRecognizer alloc] initWithLocale:ios_speech_locale(self.locale)];
  if (!self.recognizer || !self.recognizer.available) {
    [self failed:ios_audio_words(@"Speech recognition is unavailable right now.", @"El reconocimiento de voz no está disponible en este momento.")]; return;
  }
  NSError* error = nil;
  if (![self configure:YES error:&error]) { [self failed:error.localizedDescription]; return; }
  self.engine = [AVAudioEngine new];
  AVAudioInputNode* input = self.engine.inputNode;
  // Voice processing is physical echo/noise treatment, not conversation state.
  if (![input setVoiceProcessingEnabled:YES error:&error]) {
    [self failed:error.localizedDescription ?: ios_audio_words(@"Could not prepare call audio.", @"No se pudo preparar el audio de la llamada.")]; return;
  }
  AVAudioFormat* format = [input outputFormatForBus:0];
  if (format.sampleRate <= 0 || format.channelCount == 0) {
    [self failed:ios_audio_words(@"No microphone is available for the call.", @"No hay un micrófono disponible para la llamada.")]; return;
  }
  SFSpeechAudioBufferRecognitionRequest* recognition = [SFSpeechAudioBufferRecognitionRequest new];
  recognition.shouldReportPartialResults = YES;
  recognition.taskHint = SFSpeechRecognitionTaskHintDictation;
  if (self.recognizer.supportsOnDeviceRecognition) recognition.requiresOnDeviceRecognition = YES;
  self.recognition = recognition;
  NSUInteger generation = self.captureGeneration;
  self.task = [self.recognizer recognitionTaskWithRequest:recognition
    resultHandler:^(SFSpeechRecognitionResult* result, NSError* problem) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.captureGeneration) return;
      if (result.bestTranscription.formattedString.length) {
        NSString* words = result.bestTranscription.formattedString;
        if (![words isEqual:self.transcript]) {
          self.transcript = words; self.lastTextAt = NSProcessInfo.processInfo.systemUptime;
        }
      }
      if (result.final || (problem && self.finishing && self.transcript.length)) [self finishTranscript];
      else if (problem) [self failed:problem.localizedDescription];
    });
  }];
  if (!self.task) { [self failed:ios_audio_words(@"Could not start call speech recognition.", @"No se pudo iniciar el reconocimiento de la llamada.")]; return; }
  __block unsigned meter = 0;
  [input installTapOnBus:0 bufferSize:1024 format:format block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
    [recognition appendAudioPCMBuffer:buffer];
    if (++meter % 4 == 0 && buffer.floatChannelData && buffer.frameLength) {
      float* samples = buffer.floatChannelData[0];
      double energy = 0; unsigned count = 0;
      for (unsigned i = 0; i < buffer.frameLength; i += 16) { energy += samples[i] * samples[i]; ++count; }
      if (count && sqrt(energy / count) > 0.005) dispatch_async(dispatch_get_main_queue(), ^{
        if (generation == self.captureGeneration) self.lastSoundAt = NSProcessInfo.processInfo.systemUptime;
      });
    }
  }];
  self.tapInstalled = YES;
  [self.engine prepare];
  if (![self.engine startAndReturnError:&error]) { [self failed:error.localizedDescription]; return; }
  if (!self.callConnected) {
    self.callConnected = YES; self.callStartedAt = NSProcessInfo.processInfo.systemUptime;
    [self emit:@"connected" extra:nil];
    self.callTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(callTick:) userInfo:nil repeats:YES];
  }
  self.listenStartedAt = self.lastTextAt = self.lastSoundAt = NSProcessInfo.processInfo.systemUptime;
  [self emit:@"listening" extra:nil];
  self.endpoint = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(endpointTick:) userInfo:nil repeats:YES];
}
- (void)callTick:(NSTimer*)timer {
  ios_action(@{@"action":@"voice", @"data":[self state:@"elapsed" extra:nil]});
}
- (void)authorizeCall:(NSUInteger)generation {
  if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"NSSpeechRecognitionUsageDescription"] length]) {
    [self failed:ios_audio_words(@"This build is missing its speech recognition permission description.", @"Falta el permiso de reconocimiento de voz en esta compilación.")]; return;
  }
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation) return;
      if (status != SFSpeechRecognizerAuthorizationStatusAuthorized)
        [self failed:ios_audio_words(@"Allow speech recognition in Settings to call Near.", @"Permite el reconocimiento de voz en Ajustes para llamar a Near.")];
      else [self beginListening];
    });
  }];
}
- (void)speechSynthesizer:(AVSpeechSynthesizer*)speaker didFinishSpeechUtterance:(AVSpeechUtterance*)utterance {
  if (utterance != self.utterance) return;
  self.utterance = nil;
  [self emit:@"spoken" extra:nil];
}
- (void)speechSynthesizer:(AVSpeechSynthesizer*)speaker didCancelSpeechUtterance:(AVSpeechUtterance*)utterance {
  if (utterance != self.utterance) return;
  self.utterance = nil;
  [self emit:@"spoken" extra:nil];
}
- (void)interrupted:(NSNotification*)notification {
  if (!NSThread.isMainThread) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self interrupted:notification]; }); return;
  }
  if ([notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue] != AVAudioSessionInterruptionTypeBegan) return;
  if (self.recorder) [self finishRecording:self.recorder success:YES];
  else if ([self.mode isEqual:@"call"]) [self failed:ios_audio_words(@"The call was interrupted by other system audio.", @"La llamada se interrumpió por otro audio del sistema.")];
  else if ([self.mode isEqual:@"playback"]) { [self stopAll]; [self emit:@"played" extra:nil]; }
}
- (void)routeChanged:(NSNotification*)notification {
  if (!NSThread.isMainThread) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self routeChanged:notification]; }); return;
  }
  if ([notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue] == AVAudioSessionRouteChangeReasonOldDeviceUnavailable &&
    [self.phase isEqual:@"listening"]) [self failed:ios_audio_words(@"The microphone connection changed. Start the call again.", @"La conexión del micrófono cambió. Vuelve a iniciar la llamada.")];
}
- (void)background {
  if (self.recorder) [self finishRecording:self.recorder success:YES];
  if ([self.mode isEqual:@"call"]) { [self stopAll]; [self emit:@"ended" extra:nil]; }
  else if ([self.mode isEqual:@"playback"]) { [self stopAll]; [self emit:@"played" extra:nil]; }
}
- (NSString*)command:(NSDictionary*)command {
  BOOL activeCall = [self.mode isEqual:@"call"] && ![@[@"ended", @"error"] containsObject:self.phase];
  NSString* session = self.session;
  NSString* problem = [self performCommand:command];
  // A failed control must not leave capture hidden behind an error sheet.
  // Old session tokens cannot interrupt a later physical call.
  if (problem && activeCall && [command[@"session"] isEqual:session]) [self failed:problem];
  return problem;
}
- (NSString*)performCommand:(NSDictionary*)command {
  NSString* action = command[@"action"], *session = command[@"session"];
  if (![action isKindOfClass:NSString.class] || ![session isKindOfClass:NSString.class] ||
    session.length == 0 || session.length > 128) return ios_audio_words(@"Audio requires an action and a valid session.", @"Audio requiere una acción y una sesión válida.");
  if (([action isEqual:@"play"] && !ios_audio_cache_id(command[@"clipId"])) ||
    ([action isEqual:@"transcribe"] && !ios_clip_id(command[@"clipId"])))
    return ios_audio_words(@"The voice message has no valid identifier.", @"El mensaje de voz no tiene un identificador válido.");
  id locale = command[@"locale"];
  if ([action isEqual:@"call"] && locale && (![locale isKindOfClass:NSString.class] || [locale length] > 64))
    return ios_audio_words(@"The call language is invalid.", @"Idioma de llamada no válido.");
  if ([action isEqual:@"record"] || [action isEqual:@"call"] || [action isEqual:@"play"] || [action isEqual:@"transcribe"]) {
    if ((self.recorder || self.fileTask || [self.phase isEqual:@"authorizing"] || [self.phase isEqual:@"transcribing"] ||
      [self.mode isEqual:@"call"]) && ![@[@"ended", @"error"] containsObject:self.phase])
      return ios_audio_words(@"Finish the recording or call before starting other audio.", @"Finaliza la grabación o llamada antes de iniciar otro audio.");
    if ([action isEqual:@"transcribe"]) {
      NSString* clip = command[@"clipId"], *requestId = command[@"requestId"];
      if (requestId && (![requestId isKindOfClass:NSString.class] || requestId.length > 160))
        return ios_audio_words(@"The audio request identifier is invalid.", @"El identificador del envío de audio no es válido.");
      NSDictionary* pending = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key];
      if ([pending[@"clipId"] isEqual:clip])
        return ios_audio_words(@"Sending is pending; retry delivery before changing its transcript.", @"El envío está pendiente; reinténtalo antes de cambiar su transcripción.");
      NSURL* file = ios_audio_file(clip, NO);
      NSNumber* size = nil; [file getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
      if (!size || !size.unsignedLongLongValue || size.unsignedLongLongValue > IOS_AUDIO_LIMIT)
        return ios_audio_words(@"The retained recording is missing or too large.", @"La grabación guardada no existe o supera el límite.");
      NSError* error = nil;
      AVAudioPlayer* probe = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&error];
      if (!probe || !isfinite(probe.duration) || probe.duration <= 0 || probe.duration > IOS_AUDIO_SECONDS + 1)
        return error.localizedDescription ?: ios_audio_words(@"The retained recording is invalid.", @"La grabación guardada no es válida.");
      NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_audio_draft_key];
      NSMutableDictionary* metadata = [draft[@"clipId"] isEqual:clip] ? [draft mutableCopy] : [NSMutableDictionary dictionary];
      metadata[@"session"] = session; metadata[@"mode"] = @"message"; metadata[@"phase"] = @"recorded";
      metadata[@"clipId"] = clip; metadata[@"durationMs"] = @((unsigned)ceil(probe.duration * 1000));
      metadata[@"mimeType"] = @"audio/mp4"; metadata[@"transcriptionStatus"] = @"pending";
      if (!metadata[@"transcript"]) metadata[@"transcript"] = @"";
      if (requestId.length) metadata[@"requestId"] = requestId;
      [metadata removeObjectForKey:@"transcriptionError"];
      if (!ios_audio_draft(metadata)) return ios_audio_words(@"Could not save the transcription retry.", @"No se pudo guardar el reintento de transcripción.");
      [self stopAll]; self.session = session; self.mode = @"message"; self.clip = clip; self.locale = nil;
      [self transcribeFile:file metadata:metadata]; return nil;
    }
    [self stopAll]; self.session = session; self.muted = NO; self.loudspeaker = YES;
    self.callStartedAt = 0; self.callConnected = NO; self.awaitingReply = NO;
    if ([action isEqual:@"record"]) {
      self.mode = @"message"; self.clip = NSUUID.UUID.UUIDString; self.locale = nil;
      self.serverTranscription = [command[@"transcription"] isEqual:@"server"];
      [self emit:@"authorizing" extra:nil];
      NSUInteger generation = self.generation;
      [self microphone:generation completion:^{ [self beginRecording]; }];
    } else if ([action isEqual:@"call"]) {
      self.mode = @"call"; self.locale = [locale length] ? locale : NSLocale.preferredLanguages.firstObject ?: NSLocale.currentLocale.localeIdentifier;
      [self emit:@"authorizing" extra:nil];
      NSUInteger generation = self.generation;
      [self microphone:generation completion:^{ [self authorizeCall:generation]; }];
    } else {
      NSString* clip = command[@"clipId"], *href = command[@"url"];
      if (!ios_audio_cache_id(clip)) return ios_audio_words(@"The voice message has no valid identifier.", @"El mensaje de voz no tiene un identificador válido.");
      self.mode = @"playback"; self.clip = clip;
      NSURL* file = ios_audio_file(clip, NO);
      NSData* data = [NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:NULL];
      NSUInteger generation = self.generation;
      if (data) [self playData:data generation:generation];
      else {
        NSURL* url = [href isKindOfClass:NSString.class] ? [NSURL URLWithString:href relativeToURL:ios_origin].absoluteURL : nil;
        if (!ios_same_origin(url) || ![url.path isEqual:[@"/api/audio/" stringByAppendingString:clip]] ||
          url.query.length || url.fragment.length) return ios_audio_words(@"Audio must belong to the Dot server.", @"El audio debe pertenecer al servidor de Dot.");
        [self emit:@"loading" extra:nil];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
          unsigned status = 2;
          NSData* got = ios_audio_download(url, &status);
          dispatch_async(dispatch_get_main_queue(), ^{
            if (self.generation != generation) return;
            if (status == 1) {
              [got writeToURL:file options:NSDataWritingAtomic error:NULL];
              [self playData:got generation:generation];
            } else [self failed:ios_audio_words(@"Could not download the voice message.", @"No se pudo descargar el mensaje de voz.")];
          });
        });
      }
    }
    return nil;
  }
  if (![session isEqual:self.session]) return ios_audio_words(@"The audio session has ended.", @"La sesión de audio ya terminó.");
  if ([action isEqual:@"record-stop"]) {
    if (![self.mode isEqual:@"message"] || !self.recorder) return ios_audio_words(@"No recording is active.", @"No hay una grabación activa.");
    [self finishRecording:self.recorder success:YES];
  } else if ([action isEqual:@"record-cancel"]) {
    NSDictionary* draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_audio_draft_key];
    BOOL preview = [self.mode isEqual:@"playback"] && ios_clip_id(self.clip) && [draft[@"clipId"] isEqual:self.clip];
    if (![self.mode isEqual:@"message"] && !preview) return ios_audio_words(@"No recording is active.", @"No hay una grabación activa.");
    NSDictionary* pending = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_pending_key];
    if ([pending[@"clipId"] isEqual:self.clip]) return ios_audio_words(@"Sending is pending; keep the audio for retry.", @"El envío está pendiente; conserva el audio para reintentar.");
    [self stopAll]; [self emit:@"cancelled" extra:nil];
    if ([draft[@"clipId"] isEqual:self.clip]) {
      [NSUserDefaults.standardUserDefaults removeObjectForKey:ios_audio_draft_key];
      [NSUserDefaults.standardUserDefaults synchronize];
      [NSFileManager.defaultManager removeItemAtURL:ios_audio_file(self.clip, NO) error:NULL];
    }
  } else if ([action isEqual:@"play-stop"]) {
    if (![self.mode isEqual:@"playback"]) return ios_audio_words(@"No voice message is playing.", @"No se está reproduciendo un mensaje de voz.");
    [self stopAll];
    [self emit:@"played" extra:nil];
  } else if ([action isEqual:@"end"]) {
    [self stopAll]; [self emit:@"ended" extra:nil];
  } else if (![self.mode isEqual:@"call"]) return ios_audio_words(@"This action requires an active call.", @"Esta acción requiere una llamada activa.");
  else if ([action isEqual:@"listen"]) {
    if ([@[@"ended", @"error"] containsObject:self.phase])
      return ios_audio_words(@"The call has ended.", @"La llamada terminó.");
    if (!self.utterance) [self beginListening];
  } else if ([action isEqual:@"mute"]) {
    self.muted = YES; [self cancelCapture]; [self emit:@"muted" extra:nil];
  } else if ([action isEqual:@"unmute"]) {
    self.muted = NO;
    if (!self.utterance && !self.awaitingReply) [self beginListening];
    else [self emit:self.utterance ? @"speaking" : @"waiting" extra:nil];
  } else if ([action isEqual:@"speaker"]) {
    id enabled = command[@"enabled"];
    if (![enabled isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)enabled) != CFBooleanGetTypeID())
      return ios_audio_words(@"Speaker requires a Boolean value.", @"Altavoz requiere un valor booleano.");
    self.loudspeaker = [enabled boolValue];
    NSError* error = nil;
    if (![self configure:YES error:&error]) return error.localizedDescription ?:
      ios_audio_words(@"Could not configure call audio.", @"No se pudo configurar el audio de la llamada.");
    [self emit:self.phase extra:nil];
  } else if ([action isEqual:@"speak"]) {
    NSString* text = command[@"text"];
    if (![text isKindOfClass:NSString.class] || !text.length || text.length > 65536) return ios_audio_words(@"The voice reply is invalid.", @"Respuesta de voz no válida.");
    [self cancelCapture]; self.utterance = nil; [self.speaker stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    NSError* error = nil;
    if (![self configure:YES error:&error]) return error.localizedDescription ?:
      ios_audio_words(@"Could not configure call audio.", @"No se pudo configurar el audio de la llamada.");
    self.utterance = [AVSpeechUtterance speechUtteranceWithString:text];
    self.utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:self.locale];
    [self emit:@"speaking" extra:nil]; [self.speaker speakUtterance:self.utterance];
  } else return ios_audio_words(@"The audio action is unknown.", @"Acción de audio desconocida.");
  return nil;
}
@end

static void ios_voice_restore(void) {
  NSDictionary* metadata = [NSUserDefaults.standardUserDefaults dictionaryForKey:ios_audio_draft_key];
  NSString* session = metadata[@"session"];
  if (!ios_clip_id(metadata[@"clipId"]) || ![session isKindOfClass:NSString.class] || !session.length ||
    ![metadata[@"durationMs"] isKindOfClass:NSNumber.class] || ![metadata[@"transcript"] isKindOfClass:NSString.class] ||
    ![NSFileManager.defaultManager fileExistsAtPath:ios_audio_file(metadata[@"clipId"], NO).path]) return;
  if (!ios_voice) ios_voice = [BendIOSVoice new];
  // A restored clip belongs to the new physical session; the pending request
  // keeps its original receipt ID independently for transport reconciliation.
  session = ios_session_prefix.length ? ios_session_prefix : session;
  ios_voice.session = session; ios_voice.mode = @"message"; ios_voice.phase = @"recorded"; ios_voice.clip = metadata[@"clipId"];
  NSMutableDictionary* restored = [metadata mutableCopy];
  restored[@"session"] = session; restored[@"phase"] = @"recorded";
  ios_audio_draft(restored); restored[@"restored"] = @YES;
  ios_action(@{@"action":@"voice", @"data":[ios_voice state:@"recorded" extra:restored]});
}

static char* ios_voice_request(NSString* text, unsigned* status) {
  NSDictionary* command = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if (![command isKindOfClass:NSDictionary.class]) return ios_dup(@"audio takes a JSON command");
  __block NSString* problem = nil;
  dispatch_sync(dispatch_get_main_queue(), ^{
    if (!ios_voice) ios_voice = [BendIOSVoice new];
    problem = [ios_voice command:command];
  });
  *status = problem ? 2 : 1;
  return ios_dup(problem ?: @"");
}
