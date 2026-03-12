import Foundation
import MapKit
import CoreLocation
import Contacts

struct GarageSuggestion: Identifiable, Hashable {
    static func == (lhs: GarageSuggestion, rhs: GarageSuggestion) -> Bool {
        // Prefer a stable external identifier if present
        if let l = lhs.mapItemIdentifier, let r = rhs.mapItemIdentifier {
            return l == r
        }
        // Fall back to comparing core fields
        return lhs.name == rhs.name &&
        lhs.subtitle == rhs.subtitle &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
    
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let mapItemIdentifier: String?
    
    func hash(into hasher: inout Hasher) {
        if let id = mapItemIdentifier {
            hasher.combine(id)
        } else {
            hasher.combine(name)
            hasher.combine(subtitle)
            hasher.combine(coordinate.latitude)
            hasher.combine(coordinate.longitude)
        }
    }
}

final class GarageService {
    func nearbyGarages(
        around coordinate: CLLocationCoordinate2D,
        within radius: CLLocationDistance = 1_000
    ) async throws -> [GarageSuggestion] {
        try await searchGarages(matching: "gas station", near: coordinate, within: radius)
    }

    func searchGarages(
        matching query: String,
        near coordinate: CLLocationCoordinate2D?,
        within radius: CLLocationDistance = 1_000
    ) async throws -> [GarageSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.pointOfInterestFilter = MKPointOfInterestFilter(
            including: [.gasStation, .automotiveRepair]
        )

        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radius,
                longitudinalMeters: radius
            )
        }

        let response = try await MKLocalSearch(request: request).start()
        let userLocation = coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }

        let sortedItems = response.mapItems.sorted { lhs, rhs in
            guard let anchor = userLocation else {
                return (lhs.name ?? "") < (rhs.name ?? "")
            }

            // Modern API: Use item.location instead of deprecated item.placemark.location
            let lhsDistance = lhs.location.distance(from: anchor)
            let rhsDistance = rhs.location.distance(from: anchor)
            return lhsDistance < rhsDistance
        }

        return sortedItems.prefix(20).map { item in
            // Modern iOS 26 API: Use item.address and item.addressRepresentations
            var subtitle = ""
            
            // Try shortAddress first (more concise), then fullAddress
            if let address = item.address {
                subtitle = address.shortAddress ?? address.fullAddress
                
                #if DEBUG
                print("🗺️ Garage: \(item.name ?? "Unknown")")
                print("  Short Address: \(address.shortAddress ?? "nil")")
                print("  Full Address: \(address.fullAddress)")
                print("  Using subtitle: \(subtitle)")
                #endif
            } else if let addressReps = item.addressRepresentations {
                // Fallback: use addressRepresentations for display
                subtitle = addressReps.fullAddress(includingRegion: false, singleLine: true) ?? ""
                
                #if DEBUG
                print("⚠️ No address for: \(item.name ?? "Unknown"), using addressRepresentations")
                print("  Full address: \(subtitle)")
                #endif
            } else {
                #if DEBUG
                print("❌ No address info at all for: \(item.name ?? "Unknown")")
                #endif
            }
            
            // Modern API: Use item.location.coordinate instead of deprecated item.placemark.coordinate
            let coordinate = item.location.coordinate
            
            // Use the proper unique identifier from MKMapItem
            let uniqueId = item.identifier?.rawValue
            
            #if DEBUG
            if let id = uniqueId {
                print("  🆔 Unique ID: \(id)")
            } else {
                print("  ⚠️ No unique ID available")
            }
            #endif
            
            return GarageSuggestion(
                name: item.name ?? "Fuel Station",
                subtitle: subtitle,
                coordinate: coordinate,
                mapItemIdentifier: uniqueId
            )
        }
    }
}
