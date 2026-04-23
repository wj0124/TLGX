//
//  TLGXAttributes.swift
//  TLGXWidget
//
//  NOTE: Mirror of the file in the main app target so the widget extension
//  can decode the shared ActivityAttributes type.
//

import ActivityKit
import Foundation

struct TLGXAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
    }

    var name: String
}
