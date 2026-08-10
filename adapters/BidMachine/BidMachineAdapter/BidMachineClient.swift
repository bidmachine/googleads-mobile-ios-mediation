// Copyright 2025 Google LLC.
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

import BidMachine
import GoogleMobileAds
import UIKit

/// Factory that creates Client.
final class BidMachineClientFactory {

  private init() {}

  #if DEBUG
    /// This property will be returned by |createClient| function if set in Debug mode.
    nonisolated(unsafe) static var debugClient: BidMachineClient?
  #endif

  static func createClient() -> BidMachineClient {
    #if DEBUG
      return debugClient ?? BidMachineClientImpl()
    #else
      return BidMachineClientImpl()
    #endif
  }

}

protocol BidMachineClient: NSObject {

  /// Returns a version string of BidMachine SDK.
  func version() -> String

  /// Initializes the BidMachine SDK.
  func initialize(with sourceId: String, isCOPPA: Bool?)

  /// Collects the signals  for the specified ad format.
  func collectSignals(
    for adFormat: GoogleMobileAds.AdFormat, size: AdSize?, placementId: String?,
    completionHandler: @escaping (String?) -> Void)
    throws

  /// Loads a waterfall  banner ad.
  func loadWaterfallBannerAd(
    size: AdSize, placementId: String?, delegate: BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void)
    throws

  /// Loads a RTB banner ad.
  func loadRTBBannerAd(
    with bidResponse: String, size: AdSize, placementId: String?, delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Loads a RTB interstitial ad.
  func loadRTBInterstitialAd(
    with bidResponse: String, placementId: String?, delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Loads a waterfall interstitial ad.
  func loadWaterfallInterstitialAd(
    placementId: String?, delegate: BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Presents the loaded interstitial ad.
  func present(_ interstitialAd: BidMachineInterstitial?, from viewController: UIViewController)
    throws(BidMachineAdapterError)

  /// Loads a waterfall rewarded ad.
  func loadWaterfallRewardedAd(
    placementId: String?, delegate: BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Loads a RTB rewarded ad.
  func loadRTBRewardedAd(
    with bidResponse: String, placementId: String?, delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Presents the loaded rewarded ad.
  func present(_ rewardedAd: BidMachineRewarded?, from viewController: UIViewController)
    throws(BidMachineAdapterError)

  /// Loads a waterfall native ad.
  func loadWaterfallNativeAd(
    placementId: String?, delegate: BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void) throws

  /// Loads a RTB native ad.
  func loadRTBNativeAd(
    with bidResponse: String, placementId: String?, delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void) throws
}

final class BidMachineClientImpl: NSObject, BidMachineClient {

  private static let watermarkExtraKey = "google_watermark"

  private var bidMachineBanner: BidMachineBanner?
  private var bidMachineInterstitial: BidMachineInterstitial?
  private var bidMachineRewarded: BidMachineRewarded?
  private var bidMachineNative: BidMachineNative?

  func version() -> String {
    return BidMachineSdk.sdkVersion
  }

  /// Creates a BidMachine placement for the provided legacy placement format, forwarding the
  /// publisher's placement ID when one was configured in the ad unit's mediation settings.
  ///
  /// BidMachine reports on the placement ID, so it must be set on every placement the adapter
  /// creates - for bid token collection as well as for ad requests.
  ///
  /// Used by the waterfall ad loading paths only.
  private static func placement(for format: PlacementFormat, placementId: String?) throws
    -> BidMachinePlacement
  {
    return try BidMachineSdk.shared.placement(from: format) { builder in
      if let placementId {
        builder.withPlacementId(placementId)
      }
    }
  }

  /// Creates a BidMachine placement for the provided ad format, forwarding the publisher's
  /// placement ID when one was configured in the ad unit's mediation settings.
  ///
  /// Used by the bidding paths: signal collection and RTB ad loading.
  private static func placement(for adFormat: BidMachine.AdFormat, placementId: String?) throws
    -> BidMachinePlacement
  {
    return try BidMachineSdk.shared.placement(adFormat) { builder in
      if let placementId {
        builder.withPlacementId(placementId)
      }
    }
  }

  func initialize(with sourceId: String, isCOPPA: Bool?) {
    if let isCOPPA {
      BidMachineSdk.shared.regulationInfo.populate {
        $0.withCOPPA(isCOPPA)
      }
    }

    BidMachineSdk.shared.initializeSdk(sourceId)
  }

  func collectSignals(
    for adFormat: GoogleMobileAds.AdFormat, size: AdSize?, placementId: String?,
    completionHandler: @escaping (String?) -> Void
  ) throws {
    let bidMachineAdFormat = try adFormat.toBiddingAdFormat(size: size)
    let placement = try Self.placement(for: bidMachineAdFormat, placementId: placementId)
    BidMachineSdk.shared.token(placement: placement) { token in
      completionHandler(token)
    }
  }

  func loadWaterfallBannerAd(
    size: AdSize,
    placementId: String?,
    delegate: any BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let bannerFormat = try size.toWaterfallPlacementFormat()
    let placement = try Self.placement(for: bannerFormat, placementId: placementId)
    loadBannerAd(
      with: nil, placement: placement, delegate: delegate, watermark: nil,
      completionHandler: completionHandler)
  }

  func loadRTBBannerAd(
    with bidResponse: String,
    size: AdSize,
    placementId: String?,
    delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let bannerFormat = size.toBiddingAdFormat()
    let placement = try Self.placement(for: bannerFormat, placementId: placementId)
    loadBannerAd(
      with: bidResponse, placement: placement, delegate: delegate, watermark: watermark,
      completionHandler: completionHandler)
  }

  private func loadBannerAd(
    with bidResponse: String?,
    placement: BidMachinePlacement,
    delegate: BidMachineAdDelegate,
    watermark: String?,
    completionHandler: @escaping (NSError?) -> Void
  ) {
    let request = BidMachineSdk.shared.auctionRequest(placement: placement) { builder in
      if let bidResponse {
        builder.withPayload(bidResponse)
      }
    }

    BidMachineSdk.shared.banner(request: request) { [weak self] bidMachineBanner, error in
      guard let bidMachineBanner, error == nil else {
        let error = error as? NSError
        completionHandler(error)
        return
      }
      self?.bidMachineBanner = bidMachineBanner
      Task {
        @MainActor in
        bidMachineBanner.delegate = delegate
        if let watermark {
          bidMachineBanner.rendererConfiguration.extras[Self.watermarkExtraKey] = watermark
        }
        bidMachineBanner.controller = Util.rootViewController()
        bidMachineBanner.loadAd()
      }
    }
  }
  func loadWaterfallInterstitialAd(
    placementId: String?,
    delegate: any BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: PlacementFormat.interstitial, placementId: placementId)
    loadInterstitialAd(
      with: nil, placement: placement, delegate: delegate, watermark: nil,
      completionHandler: completionHandler)
  }

  func loadRTBInterstitialAd(
    with bidResponse: String,
    placementId: String?,
    delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: BidMachine.AdFormat.interstitial, placementId: placementId)
    loadInterstitialAd(
      with: bidResponse, placement: placement, delegate: delegate, watermark: watermark,
      completionHandler: completionHandler)
  }

  private func loadInterstitialAd(
    with bidResponse: String?,
    placement: BidMachinePlacement,
    delegate: BidMachineAdDelegate,
    watermark: String?,
    completionHandler: @escaping (NSError?) -> Void
  ) {
    let request = BidMachineSdk.shared.auctionRequest(placement: placement) { builder in
      if let bidResponse {
        builder.withPayload(bidResponse)
      }
    }

    BidMachineSdk.shared.interstitial(request: request) { [weak self] interstitialAd, error in
      guard let interstitialAd, error == nil else {
        completionHandler(error as? NSError)
        return
      }
      self?.bidMachineInterstitial = interstitialAd

      interstitialAd.delegate = delegate
      if let watermark {
        interstitialAd.rendererConfiguration.extras[Self.watermarkExtraKey] = watermark
      }
      interstitialAd.loadAd()
    }
  }

  func present(_ interstitialAd: BidMachineInterstitial?, from viewController: UIViewController)
    throws(BidMachineAdapterError)
  {
    guard let interstitialAd, interstitialAd.canShow else {
      throw BidMachineAdapterError(
        errorCode: .adNotReadyForPresentation,
        description: "Interstitial ad is not ready for presentation.")
    }
    interstitialAd.controller = viewController
    interstitialAd.presentAd()
  }

  func loadWaterfallRewardedAd(
    placementId: String?,
    delegate: any BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: PlacementFormat.rewarded, placementId: placementId)
    loadRewardedAd(
      with: nil, placement: placement, delegate: delegate, watermark: nil,
      completionHandler: completionHandler)
  }

  func loadRTBRewardedAd(
    with bidResponse: String,
    placementId: String?,
    delegate: BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: BidMachine.AdFormat.rewarded, placementId: placementId)
    loadRewardedAd(
      with: bidResponse, placement: placement, delegate: delegate, watermark: watermark,
      completionHandler: completionHandler)
  }

  private func loadRewardedAd(
    with bidResponse: String?,
    placement: BidMachinePlacement,
    delegate: BidMachineAdDelegate,
    watermark: String?,
    completionHandler: @escaping (NSError?) -> Void
  ) {
    let request = BidMachineSdk.shared.auctionRequest(placement: placement) { builder in
      if let bidResponse {
        builder.withPayload(bidResponse)
      }
    }

    BidMachineSdk.shared.rewarded(request: request) { [weak self] rewardedAd, error in
      guard let rewardedAd, error == nil else {
        completionHandler(error as? NSError)
        return
      }
      self?.bidMachineRewarded = rewardedAd

      rewardedAd.delegate = delegate
      if let watermark {
        rewardedAd.rendererConfiguration.extras[Self.watermarkExtraKey] = watermark
      }
      rewardedAd.loadAd()
    }
  }

  func present(_ rewardedAd: BidMachineRewarded?, from viewController: UIViewController)
    throws(BidMachineAdapterError)
  {
    guard let rewardedAd, rewardedAd.canShow else {
      throw BidMachineAdapterError(
        errorCode: .adNotReadyForPresentation,
        description: "RTB rewarded ad is not ready for presentation.")
    }
    rewardedAd.controller = viewController
    rewardedAd.presentAd()
  }

  func loadWaterfallNativeAd(
    placementId: String?,
    delegate: any BidMachineAdDelegate,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: PlacementFormat.native, placementId: placementId)
    loadNativeAd(
      with: nil, placement: placement, delegate: delegate, watermark: nil,
      completionHandler: completionHandler)
  }

  func loadRTBNativeAd(
    with bidResponse: String,
    placementId: String?,
    delegate: any BidMachineAdDelegate,
    watermark: String,
    completionHandler: @escaping (NSError?) -> Void
  ) throws {
    let placement = try Self.placement(
      for: BidMachine.AdFormat.native, placementId: placementId)
    loadNativeAd(
      with: bidResponse, placement: placement, delegate: delegate, watermark: watermark,
      completionHandler: completionHandler)
  }

  private func loadNativeAd(
    with bidResponse: String?,
    placement: BidMachinePlacement,
    delegate: any BidMachineAdDelegate,
    watermark: String?,
    completionHandler: @escaping (NSError?) -> Void

  ) {
    let request = BidMachineSdk.shared.auctionRequest(placement: placement) { builder in
      if let bidResponse {
        builder.withPayload(bidResponse)
      }
    }

    BidMachineSdk.shared.native(request: request) { [weak self] nativeAd, error in
      guard let nativeAd, error == nil else {
        completionHandler(error as? NSError)
        return
      }
      self?.bidMachineNative = nativeAd

      completionHandler(nil)
      nativeAd.delegate = delegate
      if let watermark {
        nativeAd.rendererConfiguration.extras[Self.watermarkExtraKey] = watermark
      }
      nativeAd.loadAd()
    }
  }

}

extension GoogleMobileAds.AdFormat {

  fileprivate func toBiddingAdFormat(size: AdSize?) throws(BidMachineAdapterError)
    -> BidMachine.AdFormat
  {
    switch self {
    case .banner:
      // A missing size is not an error: an adaptive banner with no size restriction is
      // requested instead.
      return size?.toBiddingAdFormat() ?? .bannerAdaptive(width: 0, maxHeight: 0)
    case .interstitial: return .interstitial
    case .rewarded: return .rewarded
    case .native: return .native
    default:
      throw BidMachineAdapterError(
        errorCode: .invalidRTBRequestParameters,
        description: "Unsupported ad format. Provided format: \(self).")
    }
  }

}

extension GoogleMobileAds.AdSize {

  /// Maps an ad size to a BidMachine placement format for waterfall requests.
  /// Uses Google's helper to find the closest valid standard size.
  fileprivate func toWaterfallPlacementFormat() throws(BidMachineAdapterError) -> PlacementFormat {
    let closestAdSize = closestValidSizeForAdSizes(
      original: self,
      possibleAdSizes: [
        nsValue(for: AdSizeBanner), nsValue(for: AdSizeMediumRectangle),
        nsValue(for: AdSizeLeaderboard),
      ])

    if isAdSizeEqualToSize(size1: closestAdSize, size2: AdSizeBanner) {
      return .banner320x50
    } else if isAdSizeEqualToSize(size1: closestAdSize, size2: AdSizeMediumRectangle) {
      return .banner300x250
    } else if isAdSizeEqualToSize(size1: closestAdSize, size2: AdSizeLeaderboard) {
      return .banner728x90
    } else {
      throw BidMachineAdapterError(
        errorCode: .unsupportedBannerSize, description: "Unsupported banner size.")
    }
  }

  /// Maps an ad size to a BidMachine ad format for bidding requests.
  ///
  /// The requested size is always passed to BidMachine as an adaptive banner with the requested
  /// width and maximum height, and the server picks the creative size. A dimension of 0 means
  /// that dimension is not restricted.
  fileprivate func toBiddingAdFormat() -> BidMachine.AdFormat {
    return .bannerAdaptive(
      width: UInt32(max(0, self.size.width)), maxHeight: UInt32(max(0, self.size.height)))
  }
}
