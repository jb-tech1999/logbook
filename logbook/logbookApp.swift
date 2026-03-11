//
//  logbookApp.swift
//  logbook
//
//  Created by Jandre Badenhorst on 2025/12/25.
//

import SwiftUI
import SwiftData
import UIKit
import CarPlay

// MARK: - App Delegate for CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {
    var tripTrackingService: TripTrackingService?
    var modelContext: ModelContext?
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        } else {
            let config = UISceneConfiguration(
                name: "Default Configuration",
                sessionRole: connectingSceneSession.role
            )
            return config
        }
    }
}

// MARK: - Main App

@main
struct logbookApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tripTrackingService = TripTrackingService()
    
    private let sharedContainer = AppModelContainer.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripTrackingService)  // Make available to all views
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    let context = ModelContext(sharedContainer)
                    
                    // Set up trip tracking service
                    await MainActor.run {
                        tripTrackingService.setModelContext(context)
                        appDelegate.tripTrackingService = tripTrackingService
                        appDelegate.modelContext = context
                    }
                    
                    // Update widget metrics
                    AppDashboardMetricsService.buildAndPersist(using: context)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Wire CarPlaySceneDelegate when it gets created
                    Task { @MainActor in
                        if let carPlayScene = UIApplication.shared.connectedScenes.first(where: { $0 is CPTemplateApplicationScene }),
                           let carPlayDelegate = carPlayScene.delegate as? CarPlaySceneDelegate {
                            carPlayDelegate.tripTrackingService = tripTrackingService
                            carPlayDelegate.modelContext = appDelegate.modelContext
                        }
                    }
                }
        }
        .modelContainer(sharedContainer)
    }
    
    // MARK: - Deep Link Handling
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "logbook" else { return }
        
        switch url.host {
        case "stopTrip":
            print("🔗 Deep link: Stop trip")
            tripTrackingService.stopTracking()
            
        case "dashboard":
            print("🔗 Deep link: Open dashboard")
            // ContentView will handle navigation to dashboard tab
            
        default:
            print("⚠️ Unknown deep link: \(url)")
        }
    }
}

