//
//  AppearanceMode.swift
//  TLGX
//
//  User-controlled light/dark mode override. Persists locally (per device)
//  via @AppStorage; intentionally NOT synced through iCloud since users
//  often want different appearances on different devices.
//

import SwiftUI
import UIKit
import Combine

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "跟随系统")
        case .light:  return String(localized: "浅色")
        case .dark:   return String(localized: "深色")
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }

    /// `nil` 表示跟随系统。仅作内部判断使用，不要直接传给
    /// `preferredColorScheme(_:)`（见 `AppAppearanceModifier`）。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// `@AppStorage` 的 key 常量，集中管理避免拼错。
enum AppearanceStorageKey {
    static let mode = "appearance.mode"
}

// MARK: - 真实系统主题

/// 暴露**真实系统主题**（不受任何 `preferredColorScheme` /
/// `UIWindow.overrideUserInterfaceStyle` 影响）。
///
/// 关键原理：`UIScreen.main.traitCollection.userInterfaceStyle` 反映
/// 的是设备的"显示与亮度"设置，window 级别的 override 不会改变它。
/// 之前用 `@Environment(\.colorScheme)` 读到的值会被自己的 override
/// 污染（窗口已被强制 dark → env 读到 dark → "跟随系统"再次解析成
/// dark，永远回不去），所以必须改用 UIScreen。
@MainActor
final class SystemAppearance: ObservableObject {
    static let shared = SystemAppearance()

    @Published private(set) var scheme: ColorScheme

    private init() {
        self.scheme = Self.read()
        // 系统主题改变（用户在系统设置里切换）通常发生在 App 退到后台
        // 之后；回到前台时刷新一次足够覆盖绝大多数场景。
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func refresh() {
        let next = Self.read()
        if next != scheme { scheme = next }
    }

    private static func read() -> ColorScheme {
        let style = UIScreen.main.traitCollection.userInterfaceStyle
        return style == .dark ? .dark : .light
    }
}

// MARK: - View modifier

/// 应用当前用户选择的外观偏好。
///
/// 三个关键约束：
/// 1. **永远**给 `preferredColorScheme(_:)` 传**显式** `ColorScheme`。
///    传 nil 会让 sheet hosting window 卡在上一次的 override。
/// 2. **永远**保持视图输出类型稳定（不用 if/else），否则在主题切换时
///    sheet 等节点的身份会失效、被销毁重建（"sheet 闪一下消失再弹出"）。
/// 3. "跟随系统"通过 `SystemAppearance.shared.scheme` 解析成显式值；
///    这个值取自 `UIScreen.main.traitCollection`，**不会**被我们自己
///    在窗口上施加的 override 污染。
private struct AppAppearanceModifier: ViewModifier {
    @AppStorage(AppearanceStorageKey.mode) private var raw = AppearanceMode.system.rawValue
    @ObservedObject private var system = SystemAppearance.shared

    func body(content: Content) -> some View {
        let mode = AppearanceMode(rawValue: raw) ?? .system
        let resolved = mode.colorScheme ?? system.scheme
        content.preferredColorScheme(resolved)
    }
}

extension View {
    /// App 根视图，以及每个 sheet / fullScreenCover 的根视图都要套一层。
    func appAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}
