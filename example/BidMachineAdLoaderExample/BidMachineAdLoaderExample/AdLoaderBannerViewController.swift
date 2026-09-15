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

import AdSupport
import AppTrackingTransparency
import GoogleMobileAds
import UIKit

/// Reproduces a Google Ad Manager integration that never hands the adapter a banner size.
///
/// The Weather Channel loads its feed units through `AdLoader` with both the Ad Manager banner
/// and the native ad type. There is no `BannerView` and no `adSize` on the request: Google asks
/// the delegate for `validBannerSizes(for:)` only after the load has started, which is after it
/// collected bidding signals. The BidMachine adapter therefore sees an invalid size during signal
/// collection and, before adapter 3.7.3.0, requested an adaptive banner of width 0. The
/// BidMachine SDK holds every bid payload to that width, so the exchange won and the banner never
/// rendered.
///
/// The target's `GAD_APPLICATION_IDENTIFIER` build setting carries the publisher's Ad Manager app
/// ID and `adUnitID` their feed unit, so Google serves the same mediation configuration the app
/// gets. Run on a device whose IDFA is allowlisted for BidMachine test bidders and watch the
/// console for `BidMachineAdapter:` lines: the size the adapter collects signals with is the
/// whole story.
final class AdLoaderBannerViewController: UIViewController {

  /// The Weather Channel's feed unit. Google's publisher settings for the app register it twice,
  /// once as a banner unit with BidMachine placement `NjVlNjIxNjlkNDFGZTQ6Og` as an SDK bidder and
  /// once as a native unit without BidMachine, which is what the two ad types below hit.
  private let adUnitID = "/7646/app_iphone_us/thr_display/feed/feed_1"

  /// The sizes The Weather Channel's feed unit reports, in the order Google forwards them.
  /// 240x133 leads, so it is the size Google puts on the bid request and hands the adapter at load
  /// time; 320x50 is in the list.
  private static let weatherFeedSizes: [CGSize] = [
    CGSize(width: 240, height: 133), CGSize(width: 300, height: 100),
    CGSize(width: 292, height: 30), CGSize(width: 300, height: 250),
    CGSize(width: 240, height: 120), CGSize(width: 320, height: 50),
    CGSize(width: 336, height: 280), CGSize(width: 300, height: 57),
    CGSize(width: 320, height: 100), CGSize(width: 300, height: 50),
    CGSize(width: 375, height: 50), CGSize(width: 220, height: 90),
    CGSize(width: 300, height: 31), CGSize(width: 250, height: 250),
    CGSize(width: 234, height: 60),
  ]

  /// What `validBannerSizes(for:)` answers. The first entry is the primary size: Google puts it on
  /// the bid request and sizes the adapter's load request from it, whatever the bid declares.
  /// Picked with the Sizes button, or at launch with `-sizes <case name>`.
  private enum SizeSet: String, CaseIterable {
    case weatherFeed, bannerFirst, mrecFirst, bannerOnly, mrecOnly, anchoredAdaptive, inlineAdaptive

    var title: String {
      switch self {
      case .weatherFeed: return "Weather feed: 240x133 first, 15 sizes"
      case .bannerFirst: return "320x50 first, then the feed sizes"
      case .mrecFirst: return "300x250 first, then the feed sizes"
      case .bannerOnly: return "320x50 only"
      case .mrecOnly: return "300x250 only"
      case .anchoredAdaptive: return "Anchored adaptive, screen width"
      case .inlineAdaptive: return "Inline adaptive, screen width"
      }
    }

    @MainActor
    var adSizes: [AdSize] {
      let feed = weatherFeedSizes.map { adSizeFor(cgSize: $0) }
      let width = UIScreen.main.bounds.width
      switch self {
      case .weatherFeed: return feed
      case .bannerFirst: return [AdSizeBanner] + feed.filter { !isAdSizeEqualToSize(size1: $0, size2: AdSizeBanner) }
      case .mrecFirst:
        return [AdSizeMediumRectangle]
          + feed.filter { !isAdSizeEqualToSize(size1: $0, size2: AdSizeMediumRectangle) }
      case .bannerOnly: return [AdSizeBanner]
      case .mrecOnly: return [AdSizeMediumRectangle]
      case .anchoredAdaptive: return [currentOrientationAnchoredAdaptiveBanner(width: width)]
      case .inlineAdaptive: return [currentOrientationInlineAdaptiveBanner(width: width)]
      }
    }
  }

  private var sizeSet =
    UserDefaults.standard.string(forKey: "sizes").flatMap(SizeSet.init(rawValue:)) ?? .weatherFeed

  private var adLoader: AdLoader?
  private var bannerView: AdManagerBannerView?
  private var hasRequestedTracking = false
  private let statusLabel = UILabel()
  private let adContainer = UIView()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "AdLoader banner"
    view.backgroundColor = .systemBackground
    layout()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasRequestedTracking else { return }
    hasRequestedTracking = true
    requestTrackingAuthorizationThenLoad()
  }

  /// Asks for tracking authorization before the first request, so a real device sends its IDFA:
  /// BidMachine test bidders and the exchange's per-IFA logging are both keyed on it. The prompt
  /// only appears while the status is undetermined; the IDFA is printed so it can be pasted into a
  /// Rollouts allocation. A simulator always reports a zero IDFA.
  private func requestTrackingAuthorizationThenLoad() {
    let proceed: (ATTrackingManager.AuthorizationStatus) -> Void = { [weak self] status in
      let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
      print("[AdLoaderExample] tracking authorization \(status.rawValue), IDFA \(idfa)")
      DispatchQueue.main.async { self?.load() }
    }
    switch ATTrackingManager.trackingAuthorizationStatus {
    case .notDetermined:
      ATTrackingManager.requestTrackingAuthorization(completionHandler: proceed)
    case let status:
      proceed(status)
    }
  }

  private func load() {
    statusLabel.text = "Loading \(adUnitID)\nSizes: \(sizeSet.title)"
    bannerView?.removeFromSuperview()
    bannerView = nil

    // Mirrors the publisher: an ad loader with the Ad Manager banner and native ad types, a plain
    // request, and no size anywhere on it.
    let adLoader = AdLoader(
      adUnitID: adUnitID,
      rootViewController: self,
      adTypes: [.adManagerBanner, .native],
      options: nil)
    adLoader.delegate = self
    self.adLoader = adLoader
    adLoader.load(AdManagerRequest())
  }

  private func layout() {
    statusLabel.numberOfLines = 0
    statusLabel.font = .preferredFont(forTextStyle: .footnote)
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    adContainer.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(statusLabel)
    view.addSubview(adContainer)

    let reload = UIBarButtonItem(
      title: "Reload", style: .plain, target: self, action: #selector(reloadTapped))
    let sizes = UIBarButtonItem(
      title: "Sizes", style: .plain, target: self, action: #selector(sizesTapped))
    navigationItem.rightBarButtonItems = [reload, sizes]

    NSLayoutConstraint.activate([
      statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
      adContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
      adContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
    ])
  }

  @objc private func reloadTapped() {
    load()
  }

  /// Picks what the next loads answer to `validBannerSizes(for:)`, then reloads.
  @objc private func sizesTapped() {
    let sheet = UIAlertController(title: "Sizes to offer Google", message: nil, preferredStyle: .actionSheet)
    for option in SizeSet.allCases {
      let mark = option == sizeSet ? "✓ " : ""
      sheet.addAction(
        UIAlertAction(title: mark + option.title, style: .default) { [weak self] _ in
          self?.sizeSet = option
          self?.load()
        })
    }
    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.last
    present(sheet, animated: true)
  }

  private func show(_ text: String) {
    print("[AdLoaderExample] \(text)")
    statusLabel.text = text
  }
}

extension AdLoaderBannerViewController: AdManagerBannerAdLoaderDelegate {

  func validBannerSizes(for adLoader: AdLoader) -> [NSValue] {
    // Google asks for this after `load` returned, so signal collection already happened without
    // any of these sizes.
    let sizes = sizeSet.adSizes
    let listed = sizes.map { "\(Int($0.size.width))x\(Int($0.size.height))" }.joined(separator: " ")
    print("[AdLoaderExample] validBannerSizes asked; returning \(sizes.count) sizes: \(listed)")
    return sizes.map { nsValue(for: $0) }
  }

  func adLoader(_ adLoader: AdLoader, didReceive bannerView: AdManagerBannerView) {
    let size = bannerView.adSize.size
    show("Banner received: \(Int(size.width))x\(Int(size.height)) from \(bannerView.responseInfo?.loadedAdNetworkResponseInfo?.adNetworkClassName ?? "unknown network")")
    bannerView.translatesAutoresizingMaskIntoConstraints = false
    adContainer.addSubview(bannerView)
    NSLayoutConstraint.activate([
      bannerView.topAnchor.constraint(equalTo: adContainer.topAnchor),
      bannerView.bottomAnchor.constraint(equalTo: adContainer.bottomAnchor),
      bannerView.leadingAnchor.constraint(equalTo: adContainer.leadingAnchor),
      bannerView.trailingAnchor.constraint(equalTo: adContainer.trailingAnchor),
    ])
    self.bannerView = bannerView
  }

  func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
    show("Load failed: \(error.localizedDescription)")
  }
}

extension AdLoaderBannerViewController: NativeAdLoaderDelegate {

  func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
    show("Native ad received from \(nativeAd.responseInfo.loadedAdNetworkResponseInfo?.adNetworkClassName ?? "unknown network"); nothing to render here")
  }
}
