//
//  AppIconManager.swift
//  TLGX
//
//  Lightweight wrapper around `UIApplication.setAlternateIconName` plus a
//  declarative list of icons rendered in the Settings picker. The actual
//  PNG resources live at the top of the bundle (declared in Info.plist's
//  `CFBundleIcons` / `CFBundleIcons~ipad`), so all this layer does is
//  remember which key is currently active and trigger the system swap.
//

import SwiftUI
import UIKit
import Combine

/// One installable app icon variant. `key == nil` means the primary icon
/// defined in `Assets.xcassets/AppIcon.appiconset`.
struct AppIconOption: Identifiable, Hashable {
    /// Stable identifier used both for the SwiftUI `ForEach` and the
    /// alternate-icon key passed to UIKit.
    let key: String?
    let displayName: String
    let subtitle: String
    /// Name of a bundled PNG used for the preview thumbnail. For the primary
    /// icon this is resolved at runtime from the bundle metadata, so we leave
    /// it `nil` and let the manager fall back to that lookup.
    let previewAssetName: String?

    var id: String { key ?? "__primary__" }
    var isPrimary: Bool { key == nil }
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()

    /// All options shown in the picker. The order here is the order users see.
    let options: [AppIconOption] = [
        AppIconOption(
            key: nil,
            displayName: "经典黑",
            subtitle: "默认 · 黑底黄字",
            previewAssetName: nil
        ),
        AppIconOption(
            key: "IconLightBlue",
            displayName: "晨光蓝",
            subtitle: "白底深蓝 · 清爽醒目",
            previewAssetName: "IconLightBlue"
        ),
    ]

    /// The currently-applied icon key, mirrored to `@Published` so SwiftUI
    /// pickers update immediately after a switch.
    @Published private(set) var currentKey: String?

    /// `true` when the device supports alternate icons at all (some legacy
    /// configurations, e.g. App Clips, return `false`).
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    private init() {
        self.currentKey = UIApplication.shared.alternateIconName
    }

    /// Apply the icon for `option`. No-ops when the requested icon is already
    /// active (avoids the system "已更换图标" alert in that case).
    func apply(_ option: AppIconOption) async throws {
        let target = option.key
        let current = UIApplication.shared.alternateIconName
        guard target != current else {
            // Keep our published mirror honest even on a no-op.
            self.currentKey = current
            return
        }
        try await UIApplication.shared.setAlternateIconName(target)
        self.currentKey = UIApplication.shared.alternateIconName
    }

    /// UIImage preview for the picker. For alternate icons we load the
    /// bundled PNG directly; for the primary icon we read `CFBundleIcons`
    /// to find whatever filename Xcode generated from the asset catalog.
    func previewImage(for option: AppIconOption) -> UIImage? {
        if let asset = option.previewAssetName, let img = UIImage(named: asset) {
            return img
        }
        return Self.primaryIconImage()
    }

    private static func primaryIconImage() -> UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let last = files.last,
            let image = UIImage(named: last)
        else {
            return UIImage(named: "AppIcon")
        }
        return image
    }
}
