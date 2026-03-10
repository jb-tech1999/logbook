//
//  logbookwidgetBundle.swift
//  logbookwidget
//
//  Created by Jandre Badenhorst on 2026/03/09.
//

import WidgetKit
import SwiftUI

@main
struct logbookwidgetBundle: WidgetBundle {
    var body: some Widget {
        logbookwidget()
        logbookwidgetControl()
        logbookwidgetLiveActivity()
    }
}
