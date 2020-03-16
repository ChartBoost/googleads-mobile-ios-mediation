#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>

typedef NS_ENUM(NSInteger, GADMoPubErrorCode) {
  /// The MoPub SDK sent a failure callback.
  GADMoPubErrorSDKFailureCallback = 100,
  /// An ad is already loaded for this network configuration.
  GADMoPubErrorAdAlreadyLoaded = 101,
  /// There was an error loading data from the network.
  GADMoPubErrorLoadingImages = 102,
  /// Missing server parameters.
  GADMoPubErrorInvalidServerParameters = 103
};

@interface GADMediationAdapterMoPub : NSObject <GADMediationAdapter>

@end
