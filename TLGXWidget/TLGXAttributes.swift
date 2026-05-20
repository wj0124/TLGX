//
//  TLGXAttributes.swift
//  TLGXWidget
//
//  Mirror of the file in the main app target.
//

import ActivityKit
import Foundation

struct TLGXAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var emoji: String
    }

    var reminderID: String
}
