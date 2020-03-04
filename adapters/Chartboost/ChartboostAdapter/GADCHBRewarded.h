//
//  GADCHBRewarded.h
//  Adapter
//
//  Created by Daniel Barros on 03/03/2020.
//  Copyright © 2020 Google. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#if __has_include(<Chartboost/Chartboost+Mediation.h>)
#import <Chartboost/Chartboost+Mediation.h>
#else
#import "Chartboost+Mediation.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface GADCHBRewarded : NSObject <GADMediationRewardedAd>
- (instancetype)initWithLocation:(NSString *)location
                       mediation:(CHBMediation *)mediation
                 adConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
               completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler;
- (void)destroy;
- (void)load;
@end

NS_ASSUME_NONNULL_END