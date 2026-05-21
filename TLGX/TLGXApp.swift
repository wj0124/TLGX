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

        // Wire up iCloud key-value sync. Safe to call when the user is
        // signed out of iCloud — NSUbiquitousKeyValueStore just no-ops.
        ReminderCloudSync.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notifications)
        }
    }
}
