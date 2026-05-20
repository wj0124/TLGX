//
//  TLGXAttributes.swift
//  TLGX
//
//  Shared between the app and the widget extension.
//

import ActivityKit
import Foundation

struct TLGXAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var emoji: String
        /// Optional secondary line, e.g. "每天 14:00".
        var subtitle: String?
    }

    var reminderID: String
}
