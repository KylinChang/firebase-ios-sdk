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

#import "AppDelegate.h"
#import "FirebaseCore.h"
#import "FirebaseFirestore.h"

@interface AppDelegate ()

@property(weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // create a firestore db
  NSString *filePath = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info"
                                                       ofType:@"plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:filePath];
  [FIRApp configureWithOptions:options];
  FIRFirestore *db = [FIRFirestore firestore];

  // do the timestamp fix
  FIRFirestoreSettings *settings = db.settings;
  settings.timestampsInSnapshotsEnabled = true;
  db.settings = settings;

  // create a doc
  FIRDocumentReference *docRef = [[db collectionWithPath:@"junk"] documentWithPath:@"test_doc"];
  NSDictionary *data = @{@"msg" : @"hello"};

  [docRef setData:data
       completion:^(NSError *_Nullable error) {
         if (error != nil) {
           NSLog(@"created error: %@", error);
         } else {
           NSLog(@"Yay!");
         }
       }];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  // Insert code here to tear down your application
}

@end
