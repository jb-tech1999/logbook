//
//  logbookApp.swift
//  logbook
//
//  Created by Jandre Badenhorst on 2025/12/25.
//

import SwiftUI
import SwiftData

@main
struct logbookApp: App {
    private let sharedContainer = AppModelContainer.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    let context = ModelContext(sharedContainer)
                    AppDashboardMetricsService.buildAndPersist(using: context)
                }
        }
        .modelContainer(sharedContainer)
    }
}
