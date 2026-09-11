// Copyright 2026 BidMachine.
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

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    enableBidMachineLogging()
    MobileAds.shared.start { status in
      for (adapter, state) in status.adapterStatusesByClassName {
        print("[AdLoaderExample] adapter \(adapter): \(state.state.rawValue) \(state.description)")
      }
    }
    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }

  /// Turns on every BidMachine log the SDK offers before the adapter initialises it. The public
  /// switches cover the SDK, bids, events, the creative sanitizer and adapters; the feature flags
  /// open the internal categories (analytics, adaptive rendering, MRAID, state groups, GAM,
  /// database) that are otherwise driven by the server.
  private func enableBidMachineLogging() {
    BidMachineSdk.shared.populate { builder in
      builder
        .withLoggingMode(true)
        .withBidLoggingMode(true)
        .withEventLoggingMode(true)
        .withSanitizerLoggingMode(true)
    }
    BidMachineSdk.shared.withAdaptersLoggingMode(true)
    for feature in [
      "analyticsLog", "adaptiveLog", "adaptiveMraidLog", "adaptiveStateGroupsLog", "gamLog",
      "dgamLog", "databaseLog", "demoLogs", "adaptiveStackTrace",
    ] {
      BidMachineSdk.shared.installFeature(feature, true)
    }
  }
}
