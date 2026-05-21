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
    }

    var reminderID: String
    /// When the Live Activity was started; drives the elapsed-time subtitle.
    var startedAt: Date
}
