//
//  TLGXApp.swift
//  TLGX
//
//  Created by wangjie on 2026/4/23.
//

import SwiftUI

@main
struct TLGXApp: App {
    @StateObject private var notifications = NotificationDelegate.shared

    init() {
        // Install the notification delegate as early as possible so that
        // taps on cold-start notifications are delivered to us.
        NotificationDelegate.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notifications)
        }
    }
}
