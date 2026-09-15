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

import Foundation
import GoogleMobileAds
import UIKit

final class Util {

  private enum MediationConfigurationSettingKey: String {
    case sourceId = "source_id"
    case placementId = "placement_id"
  }

  /// Prints the message with `BidMachineAdapter` prefix.
  static func log(_ message: String) {
    #if DEBUG
      print("BidMachineAdapter: \(message)")
    #endif
  }

  /// Returns a NSError object with the provided information.
  static func error(withDomain domain: String, code: Int, description: String) -> NSError {
    return NSError(
      domain: domain, code: code,
      userInfo: [
        NSLocalizedDescriptionKey: description,
        NSLocalizedFailureReasonErrorKey: description,
      ])
  }

  /// Retrieves a publisher ID from the provided mediation server configuration.
  ///
  /// - Throws: BidMachineAdapterError.serverConfigurationMissingPublisherId if the configuration
  /// contains no publisher ID.
  /// - Returns: A publisher ID from the configuration. If more than one ID was found, the it
  /// returns one random ID with printed warning message.
  static func sourceId(from config: MediationServerConfiguration) throws(BidMachineAdapterError)
    -> String
  {
    let sourceIdSet = Set<String>(
      config.credentials.compactMap {
        $0.settings[MediationConfigurationSettingKey.sourceId.rawValue] as? String
      })

    guard let sourceId = sourceIdSet.randomElement() else {
      throw BidMachineAdapterError(
        errorCode: .serverConfigurationMissingPublisherId,
        description: "The server configuration is missing an source ID.")
    }

    if sourceIdSet.count > 1 {
      log("Found more than one source ID in the server configuration. Using \(sourceId)")
    }

    return sourceId
  }

  /// Resolves the banner size signals are collected with.
  ///
  /// Google provides no usable size for some banner units: fluid and multi-size units reach signal
  /// collection with an invalid size. A width of 0 in the bid token leaves the exchange nothing to
  /// auction on, so such requests are made with the screen width instead. A missing height stays
  /// 0, which BidMachine treats as unrestricted.
  ///
  /// - Returns: The provided size when it is valid and has a positive width, otherwise a size with
  /// the screen width and the provided height, or 0 when there is none.
  @MainActor
  static func biddingBannerAdSize(from adSize: AdSize?) -> AdSize {
    if let adSize, isAdSizeValid(size: adSize), adSize.size.width > 0, adSize.size.height >= 0 {
      return adSize
    }
    let height = adSize.map { isAdSizeValid(size: $0) ? max(0, $0.size.height) : 0 } ?? 0
    return adSizeFor(cgSize: CGSize(width: UIScreen.main.bounds.width, height: height))
  }

  /// The banner size an RTB load is made with: the screen width, the height left open.
  ///
  /// Google sizes the load request from the ad unit's primary size, not from the size the bid
  /// declared, while the payload describes the creative the exchange actually built. The BidMachine
  /// SDK holds the payload to the load request - the payload may be no wider - so a multi-size unit
  /// whose primary size is narrower than the creative would refuse every payload. Requesting the
  /// screen width lets any payload that fits the screen load; the ad is still laid out in the view
  /// Google provides.
  @MainActor
  static func bannerLoadAdSize() -> AdSize {
    return adSizeFor(cgSize: CGSize(width: UIScreen.main.bounds.width, height: 0))
  }

  /// Retrieves a placement ID from the provided mediation ad configuration.
  ///
  /// The placement ID is an optional setting. BidMachine uses it to attribute the request in its
  /// reporting, so it is forwarded whenever the publisher configured one, but its absence is not
  /// an error and must not fail the ad load.
  ///
  /// - Returns: A placement ID from the configuration, or nil if the configuration contains none.
  static func placementId(from config: MediationAdConfiguration) -> String? {
    return config.credentials.settings[MediationConfigurationSettingKey.placementId.rawValue]
      as? String
  }

  /// Retrieves a placement ID from the provided RTB parameters.
  ///
  /// Uses the first credential found. The ad unit may have multiple mediation groups, each with a
  /// different BidMachine placement ID, and the actual mediation group is resolved only after
  /// signal collection is completed. So the credentials may contain multiple different placement
  /// IDs at this point.
  ///
  // TODO: Update the API to take a list of placement IDs during signal collection once the
  // BidMachine SDK supports it.
  /// - Returns: A placement ID from the parameters, or nil if the parameters contain none.
  static func placementId(from params: RTBRequestParameters) -> String? {
    return params.configuration.credentials.first?.settings[
      MediationConfigurationSettingKey.placementId.rawValue] as? String
  }

  /// Retrieves an ad format from the provided RTB parameters.
  ///
  /// - Throws: BidMachineAdapterError.invalidRTBRequestParameters if the parameters contain no ad format.
  /// - Returns: An ad format from the configuration.
  static func adFormat(
    from params: RTBRequestParameters
  ) throws(BidMachineAdapterError) -> AdFormat {
    // Returns the first ad format found because the other crendentials should
    // have the same ad format.
    guard let adFormat = params.configuration.credentials.first?.format else {
      throw BidMachineAdapterError(
        errorCode: .invalidRTBRequestParameters,
        description:
          "Failed to collect signals because the configuration is missing the crendentials.")
    }

    return adFormat
  }

  /// Retrieves the root view controller of the current key window. If it is not available, returns
  /// nil.
  @MainActor static func rootViewController() -> UIViewController? {
    var viewController: UIViewController?
    // If failed to find the closest view controller, then find the app's root
    // view controller
    if #available(iOS 13.0, *) {
      let activeScene =
        UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .first(where: { $0 is UIWindowScene }) as? UIWindowScene

      let keyWindow = activeScene?.windows.first(where: { $0.isKeyWindow })
      viewController = keyWindow?.rootViewController
    } else {
      viewController = UIApplication.shared.keyWindow?.rootViewController
    }

    return viewController
  }

}
