// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADMAdapterChartboostSingleton.h"

#import "GADMAdapterChartboostConstants.h"
#import "GADMAdapterChartboostDataProvider.h"
#import "GADMAdapterChartboostUtils.h"
#import "GADMChartboostError.h"

@interface GADMAdapterChartboostSingleton () <ChartboostDelegate>

@end

@implementation GADMAdapterChartboostSingleton {

  /// Hash Map to hold all rewarded adapter delegates.
  NSMapTable<NSString *, id<GADMAdapterChartboostDataProvider, ChartboostDelegate>>
      *_rewardedAdapterDelegates;

  /// Concurrent dispatch queue.
  dispatch_queue_t _queue;

  /// Chartboost SDK init state.
  GADMAdapterChartboostInitState _initState;

  /// An array of completion handlers to be called once the Chartboost SDK is initialized.
  NSMutableArray<ChartboostInitCompletionHandler> *_completionHandlers;
}

#pragma mark - Singleton Initializers

+ (nonnull GADMAdapterChartboostSingleton *)sharedInstance {
  static GADMAdapterChartboostSingleton *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GADMAdapterChartboostSingleton alloc] init];
  });
  return sharedInstance;
}

- (nonnull instancetype)init {
  self = [super init];
  if (self) {
    _rewardedAdapterDelegates = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                                                      valueOptions:NSPointerFunctionsWeakMemory];
    _queue = dispatch_queue_create("com.google.admob.chartboost_adapter_singleton",
                                   DISPATCH_QUEUE_SERIAL);
    _completionHandlers = [[NSMutableArray alloc] init];
  }
  return self;
}

// TODO: Substitute start method with completion version and get rid of queues and init states
- (void)startWithAppId:(NSString *)appId
          appSignature:(NSString *)appSignature
     completionHandler:(nonnull ChartboostInitCompletionHandler)completionHandler
{
    appId = [appId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    appSignature = [appSignature stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if (!appId || !appSignature) {
        completionHandler(GADChartboostErrorWithDescription(@"App ID & App Signature cannot be nil."));
        return;
    }
    
    
    
  dispatch_async(_queue, ^{
    switch (self->_initState) {
      case GADMAdapterChartboostInitialized:
        completionHandler(nil);
        break;
      case GADMAdapterChartboostInitializing:
        GADMAdapterChartboostMutableArrayAddObject(self->_completionHandlers, completionHandler);
        break;
      case GADMAdapterChartboostUninitialized:
        GADMAdapterChartboostMutableArrayAddObject(self->_completionHandlers, completionHandler);
        self->_initState = GADMAdapterChartboostInitializing;
        [Chartboost startWithAppId:appId appSignature:appSignature delegate:self];
        [Chartboost setMediation:CBMediationAdMob
              withLibraryVersion:[GADRequest sdkVersion]
                  adapterVersion:kGADMAdapterChartboostVersion];
        [Chartboost setAutoCacheAds:YES];
        break;
    }
  });
}

- (void)setFrameworkWithExtras:(GADMChartboostExtras *)extras
{
    // TODO: Extras is nil if not set by publisher?
    if (extras && [extras isKindOfClass:GADMChartboostExtras.class]) {
        [Chartboost setFramework:extras.framework withVersion:extras.frameworkVersion];
    }
}

- (void)addRewardedAdAdapterDelegate:
    (nonnull id<GADMAdapterChartboostDataProvider, ChartboostDelegate>)adapterDelegate {
  @synchronized(_rewardedAdapterDelegates) {
    GADMAdapterChartboostMapTableSetObjectForKey(_rewardedAdapterDelegates,
                                                 [adapterDelegate getAdLocation], adapterDelegate);
  }
}

- (void)removeRewardedAdAdapterDelegate:
    (nonnull id<GADMAdapterChartboostDataProvider, ChartboostDelegate>)adapterDelegate {
  @synchronized(_rewardedAdapterDelegates) {
    GADMAdapterChartboostMapTableRemoveObjectForKey(_rewardedAdapterDelegates,
                                                    [adapterDelegate getAdLocation]);
  }
}

- (nullable id<GADMAdapterChartboostDataProvider, ChartboostDelegate>)
    getRewardedAdapterDelegateForAdLocation:(NSString *)adLocation {
  @synchronized(_rewardedAdapterDelegates) {
    return [_rewardedAdapterDelegates objectForKey:adLocation];
  }
}

#pragma mark - Rewarded Ads Methods

- (void)configureRewardedAdWithAppID:(nonnull NSString *)appID
                        appSignature:(nonnull NSString *)appSignature
                            delegate:
                                (nonnull id<GADMAdapterChartboostDataProvider, ChartboostDelegate>)
                                    adapterDelegate {
  GADMChartboostExtras *chartboostExtras = [adapterDelegate extras];
  if (chartboostExtras.frameworkVersion && chartboostExtras.framework) {
    [Chartboost setFramework:chartboostExtras.framework
                 withVersion:chartboostExtras.frameworkVersion];
  }

  NSString *adLocation = [adapterDelegate getAdLocation];
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> existingDelegate =
      [self getRewardedAdapterDelegateForAdLocation:adLocation];

  if (existingDelegate) {
    NSError *error = GADChartboostErrorWithDescription(
        @"Already requested an ad for this ad location. Can't make another request.");
    [adapterDelegate didFailToLoadAdWithError:error];
    return;
  }

  [self addRewardedAdAdapterDelegate:adapterDelegate];

  if ([Chartboost hasRewardedVideo:adLocation]) {
    [adapterDelegate didCacheRewardedVideo:adLocation];
  } else {
    [Chartboost cacheRewardedVideo:adLocation];
  }
}

- (void)presentRewardedAdForDelegate:
    (id<GADMAdapterChartboostDataProvider, ChartboostDelegate>)adapterDelegate {
  [Chartboost showRewardedVideo:[adapterDelegate getAdLocation]];
}
- (CHBMediation *)mediation
{
    return [[CHBMediation alloc] initWithType:CBMediationAdMob
                               libraryVersion:[GADRequest sdkVersion]
                               adapterVersion:kGADMAdapterChartboostVersion];}

#pragma mark - Chartboost Delegate mathods

- (void)didInitialize:(BOOL)status {
  if (status) {
    _initState = GADMAdapterChartboostInitialized;
    for (ChartboostInitCompletionHandler completionHandler in _completionHandlers) {
      completionHandler(nil);
    }
  } else {
    _initState = GADMAdapterChartboostUninitialized;
    NSError *error = GADChartboostErrorWithDescription(@"Failed to initialize Chartboost SDK.");
    for (ChartboostInitCompletionHandler completionHandler in _completionHandlers) {
      completionHandler(error);
    }
  }
  [_completionHandlers removeAllObjects];
}

#pragma mark - Chartboost Reward Based Video Ad Delegate Methods

- (void)didDisplayRewardedVideo:(CBLocation)location {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didDisplayRewardedVideo:location];
}

- (void)didCacheRewardedVideo:(CBLocation)location {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didCacheRewardedVideo:location];
}

- (void)didFailToLoadRewardedVideo:(CBLocation)location withError:(CBLoadError)error {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didFailToLoadRewardedVideo:location withError:error];
}

- (void)didDismissRewardedVideo:(CBLocation)location {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didDismissRewardedVideo:location];
}

- (void)didClickRewardedVideo:(CBLocation)location {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didClickRewardedVideo:location];
}

- (void)didCompleteRewardedVideo:(CBLocation)location withReward:(int)reward {
  id<GADMAdapterChartboostDataProvider, ChartboostDelegate> delegate =
      [self getRewardedAdapterDelegateForAdLocation:location];
  [delegate didCompleteRewardedVideo:location withReward:reward];
}

@end
