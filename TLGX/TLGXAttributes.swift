//
//  TLGXAttributes.swift
//  TLGX
//
//  Shared Live Activity attributes between the app and the widget extension.
//

import ActivityKit
import Foundation

struct TLGXAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
    }

    var name: String
}
