//
//  TLGXAttributes.swift
//  TLGX
//
//  Shared between the app and the widget extension.
//

import ActivityKit
import Foundation

enum DynamicIslandDisplayMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case compact
    case standard
    case detailed

    var id: String { rawValue }

    static let storageKey = "dynamicIsland.displayMode"

    var displayName: String {
        switch self {
        case .compact: return "紧凑"
        case .standard: return "标准"
        case .detailed: return "详细"
        }
    }

    var symbolName: String {
        switch self {
        case .compact: return "circle.lefthalf.filled"
        case .standard: return "rectangle.split.2x1"
        case .detailed: return "text.justify.left"
        }
    }
}

struct TLGXAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var emoji: String
        var islandMode: DynamicIslandDisplayMode

        init(title: String,
             emoji: String,
             islandMode: DynamicIslandDisplayMode = .standard) {
            self.title = title
            self.emoji = emoji
            self.islandMode = islandMode
        }

        private enum CodingKeys: String, CodingKey {
            case title, emoji, islandMode
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = try c.decode(String.self, forKey: .title)
            emoji = try c.decode(String.self, forKey: .emoji)
            islandMode = try c.decodeIfPresent(DynamicIslandDisplayMode.self, forKey: .islandMode) ?? .standard
        }
    }

    var reminderID: String
    /// When the Live Activity was started; drives the elapsed-time subtitle.
    var startedAt: Date
}
