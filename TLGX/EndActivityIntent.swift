//
//  EndActivityIntent.swift
//  TLGX (also member of TLGXWidgetExtension via project exception)
//
//  Lets the Live Activity lock-screen / Dynamic Island banner end the running
//  activity in-place, without launching the app.
//

import ActivityKit
import AppIntents

struct EndActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束实时活动"

    @Parameter(title: "Reminder ID")
    var reminderID: String

    init() {
        self.reminderID = ""
    }

    init(reminderID: String) {
        self.reminderID = reminderID
    }

    func perform() async throws -> some IntentResult {
        for activity in Activity<TLGXAttributes>.activities
        where activity.attributes.reminderID == reminderID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
