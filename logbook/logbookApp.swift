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
import OSLog

private let appLogger = Logger(subsystem: "com.jb-tech.logbook", category: "App")

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
    @State private var tripTrackingService = TripTrackingService()
    
    private let sharedContainer = AppModelContainer.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            if let container = sharedContainer {
                ContentView()
                    .environment(tripTrackingService)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .task {
                        let context = ModelContext(container)
                        
                        await MainActor.run {
                            tripTrackingService.setModelContext(context)
                            appDelegate.tripTrackingService = tripTrackingService
                            appDelegate.modelContext = context
                        }
                        
                        AppDashboardMetricsService.buildAndPersist(using: context)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        Task { @MainActor in
                            if let carPlayScene = UIApplication.shared.connectedScenes.first(where: { $0 is CPTemplateApplicationScene }),
                               let carPlayDelegate = carPlayScene.delegate as? CarPlaySceneDelegate {
                                carPlayDelegate.tripTrackingService = tripTrackingService
                                carPlayDelegate.modelContext = appDelegate.modelContext
                            }
                        }
                    }
                    .modelContainer(container)
            } else {
                // SwiftData container failed to initialize — show recovery UI
                DataRecoveryView()
            }
        }
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

// MARK: - Data Recovery View

struct DataRecoveryView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Data Error")
                .font(.title.bold())

            Text("Unable to initialize the app's data storage. Please close and reopen the app. If the problem persists, contact support.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button("Open Settings") {
                    appLogger.error("User opened Settings from DataRecoveryView after model container failure")
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
                .buttonStyle(.borderedProminent)

                Text("You can also force close the app and reopen it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Data error screen")
        .accessibilityHint("Provides recovery actions when the app cannot initialize local data storage")
    }
}
