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
    }

    var reminderID: String
}
