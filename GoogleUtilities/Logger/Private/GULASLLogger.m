/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "GULASLLogger.h"

#import <asl.h>

#import "GULAppEnvironmentUtil.h"
#import "GULLogger+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface GULASLLogger () {
  GULLoggerLevel _logLevel;
}

@property(nonatomic) aslclient aslClient;
@property(nonatomic) dispatch_queue_t dispatchQueue;

@end

@implementation GULASLLogger

@synthesize version = _version;
@synthesize forcedDebug = _forcedDebug;

- (instancetype)init {
  self = [super init];
  if (self) {
    _forcedDebug = NO;
    _logLevel = GULLoggerLevelNotice;
    _version = @"";
    _dispatchQueue = dispatch_queue_create("GULLoggerQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_dispatchQueue,
                              dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
  }
  return self;
}

- (void)initializeLogger {
  dispatch_sync(self.dispatchQueue, ^{
    if (!self.aslClient) {
      // TODO(bstpierre): Omit this check once os_log is used for these cases.
      NSInteger majorOSVersion = [[GULAppEnvironmentUtil systemVersion] integerValue];
      uint32_t aslOptions = ASL_OPT_STDERR;  // Older iOS versions need this flag.
#if TARGET_OS_SIMULATOR
      // The iOS 11 simulator doesn't need the ASL_OPT_STDERR flag.
      if (majorOSVersion >= 11) {
        aslOptions = 0;
      }
#else
      // Devices running iOS 10 or higher don't need the ASL_OPT_STDERR flag.
      if (majorOSVersion >= 10) {
        aslOptions = 0;
      }
#endif  // TARGET_OS_SIMULATOR

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
      self.aslClient = asl_open(NULL, kGULLoggerClientFacilityName, aslOptions);
      asl_set_filter(self.aslClient, ASL_FILTER_MASK_UPTO(ASL_LEVEL_NOTICE));
#pragma clang diagnostic pop
    }
  });
}

- (void)dealloc {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
  asl_release(self.aslClient);
#pragma clang diagnostic pop
}

- (void)setLogLevel:(GULLoggerLevel)logLevel {
  if (logLevel < GULLoggerLevelMin || logLevel > GULLoggerLevelMax) {
    GULLogError(kGULLoggerName, NO, @"I-COR000023", @"Invalid logger level, %ld", (long)logLevel);
  }

  // We should not raise the logger level if we are running from App Store.
  if (logLevel >= GULLoggerLevelNotice && [GULAppEnvironmentUtil isFromAppStore]) {
    return;
  }
  self.logLevel = logLevel;
}

- (GULLoggerLevel)logLevel {
  return _logLevel;
}

- (void)forceDebug {
  // We should not enable debug mode if we're running from App Store.
  if (![GULAppEnvironmentUtil isFromAppStore]) {
    self.forcedDebug = YES;
    self.logLevel = GULLoggerLevelDebug;
  }
}

- (BOOL)isLoggableLevel:(GULLoggerLevel)logLevel {
  return [GULLogger loggerSystem:self shouldLogMessageOfLevel:logLevel];
}

- (void)printToSTDERR {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
  asl_add_log_file(self.aslClient, STDERR_FILENO);
#pragma clang diagnostic pop
}

- (void)logWithLevel:(GULLoggerLevel)level
         withService:(GULLoggerService)service
            isForced:(BOOL)forced
            withCode:(NSString *)messageCode
         withMessage:(NSString *)message, ... {
  [self initializeLogger];
  // Skip logging this if the level isn't to be logged unless it's forced.
  if (![self isLoggableLevel:level] && !forced) {
    return;
  }

  const char *logMsg = [GULLogger messageFromLogger:self
                                        withService:service
                                               code:messageCode
                                            message:message].UTF8String;
  dispatch_async(self.dispatchQueue, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
    asl_log(self.aslClient, NULL, level, "%s", logMsg);
#pragma clang diagnostic pop
  });
}

@end

NS_ASSUME_NONNULL_END
