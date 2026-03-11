import Foundation
import CarPlay
import SwiftData

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
        
        print("🚗 CarPlay connected")
        
        // Start trip tracking when CarPlay connects
        Task { @MainActor in
            guard let service = tripTrackingService else {
                print("⚠️ TripTrackingService not available")
                return
            }
            
            // Get the user's current car (most recent)
            if let context = modelContext {
                let descriptor = FetchDescriptor<Car>(sortBy: [SortDescriptor(\.year, order: .reverse)])
                if let cars = try? context.fetch(descriptor), let currentCar = cars.first {
                    service.startTracking(car: currentCar)
                    print("✅ Trip tracking started for \(currentCar.year) \(currentCar.make) \(currentCar.model)")
                } else {
                    // Start tracking without a specific car
                    service.startTracking()
                    print("✅ Trip tracking started (no car selected)")
                }
            }
        }
        
        // Set up CarPlay template
        let template = createDashboardTemplate()
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        print("🚗 CarPlay disconnected")
        
        // Stop trip tracking when CarPlay disconnects
        Task { @MainActor in
            tripTrackingService?.stopTracking()
            print("✅ Trip tracking stopped")
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
