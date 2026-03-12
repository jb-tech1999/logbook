import Foundation
import CarPlay
import SwiftData
import OSLog

private let carPlayLogger = Logger(subsystem: "com.jb-tech.logbook", category: "CarPlay")

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    var interfaceController: CPInterfaceController?
    var tripTrackingService: TripTrackingService?
    var modelContext: ModelContext?
    
    // MARK: - CPTemplateApplicationSceneDelegate
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        carPlayLogger.info("CarPlay connected")
        
        // Start trip tracking when CarPlay connects
        Task { @MainActor in
            guard let service = tripTrackingService else {
                carPlayLogger.error("TripTrackingService not available during CarPlay connect")
                return
            }
            
            // Get the user's current car (most recent)
            if let context = modelContext {
                let descriptor = FetchDescriptor<Car>(sortBy: [SortDescriptor(\.year, order: .reverse)])
                do {
                    let cars = try context.fetch(descriptor)
                    if let currentCar = cars.first {
                        service.startTracking(car: currentCar)
                        carPlayLogger.info("Trip tracking started for current vehicle")
                    } else {
                        service.startTracking()
                        carPlayLogger.info("Trip tracking started without a selected vehicle")
                    }
                } catch {
                    carPlayLogger.error("Failed to fetch cars on CarPlay connect: \(error)")
                    service.startTracking()
                    carPlayLogger.warning("Started trip tracking without a selected vehicle after car fetch failure")
                }
            } else {
                service.startTracking()
                carPlayLogger.warning("ModelContext unavailable on CarPlay connect — started trip tracking without vehicle context")
            }
        }
        
        // Set up CarPlay template
        let template = createDashboardTemplate()
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        carPlayLogger.info("CarPlay disconnected")

        Task { @MainActor in
            tripTrackingService?.stopTracking()
            carPlayLogger.info("Trip tracking stopped after CarPlay disconnect")
        }

        self.interfaceController = nil
    }
    
    // MARK: - Private Methods
    
    private func createDashboardTemplate() -> CPInformationTemplate {
        let items: [CPInformationItem] = [
            CPInformationItem(title: "Status", detail: "Trip tracking active"),
            CPInformationItem(title: "Info", detail: "Your trip is being recorded automatically")
        ]
        
        let template = CPInformationTemplate(title: "Logbook", layout: .leading, items: items, actions: [])
        return template
    }
}
