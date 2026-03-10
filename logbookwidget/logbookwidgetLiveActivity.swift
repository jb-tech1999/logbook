//
//  logbookwidgetLiveActivity.swift
//  logbookwidget
//
//  Created by Jandre Badenhorst on 2026/03/09.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct logbookwidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct logbookwidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: logbookwidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension logbookwidgetAttributes {
    fileprivate static var preview: logbookwidgetAttributes {
        logbookwidgetAttributes(name: "World")
    }
}

extension logbookwidgetAttributes.ContentState {
    fileprivate static var smiley: logbookwidgetAttributes.ContentState {
        logbookwidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: logbookwidgetAttributes.ContentState {
         logbookwidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: logbookwidgetAttributes.preview) {
   logbookwidgetLiveActivity()
} contentStates: {
    logbookwidgetAttributes.ContentState.smiley
    logbookwidgetAttributes.ContentState.starEyes
}
