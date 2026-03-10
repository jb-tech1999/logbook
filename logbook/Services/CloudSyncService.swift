// import Foundation
// import SwiftData

// struct CloudSyncPayload: Encodable {
//     let generatedAt: Date
//     let users: [CloudUser]
//     let cars: [CloudCar]
//     let logs: [CloudLogEntry]
// }

// struct CloudUser: Encodable {
//     let email: String
//     let displayName: String
//     let usesBiometrics: Bool
//     let sessionToken: String?
//     let lastSignIn: Date?
//     let createdAt: Date
// }

// struct CloudCar: Encodable {
//     let registration: String
//     let make: String
//     let model: String
//     let year: Int
//     let nickname: String?
//     let ownerEmail: String?
//     let createdAt: Date
// }

// struct CloudLogEntry: Encodable {
//     let date: Date
//     let speedometerKm: Double
//     let distanceKm: Double
//     let fuelLiters: Double
//     let fuelSpend: Double
//     let garageName: String?
//     let garageSubtitle: String?
//     let garageLatitude: Double?
//     let garageLongitude: Double?
//     let garageMapItemIdentifier: String?
//     let createdAt: Date
//     let userEmail: String?
//     let carRegistration: String?
// }

// enum CloudSyncError: Error {
//     case invalidResponse
//     case serverError(statusCode: Int, body: String?)
// }

// final class CloudSyncService {
//     static let defaultEndpoint = URL(string: "https://example.com/api/logbook/sync")!

//     private let session: URLSession

//     init(session: URLSession = .shared) {
//         self.session = session
//     }

//     func pushAllData(
//         modelContext: ModelContext,
//         endpoint: URL = CloudSyncService.defaultEndpoint,
//         authToken: String? = nil
//     ) async throws {
//         let payload = try await MainActor.run { try buildPayload(modelContext: modelContext) }

//         var request = URLRequest(url: endpoint)
//         request.httpMethod = "POST"
//         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//         if let authToken {
//             request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
//         }

//         let encoder = JSONEncoder()
//         encoder.dateEncodingStrategy = .iso8601
//         request.httpBody = try encoder.encode(payload)

//         let (data, response) = try await session.data(for: request)
//         guard let httpResponse = response as? HTTPURLResponse else {
//             throw CloudSyncError.invalidResponse
//         }

//         guard (200...299).contains(httpResponse.statusCode) else {
//             let body = String(data: data, encoding: .utf8)
//             throw CloudSyncError.serverError(statusCode: httpResponse.statusCode, body: body)
//         }
//     }

//     @MainActor
//     private func buildPayload(modelContext: ModelContext) throws -> CloudSyncPayload {
//         let users = try modelContext.fetch(FetchDescriptor<User>())
//         let cars = try modelContext.fetch(FetchDescriptor<Car>())
//         let logs = try modelContext.fetch(FetchDescriptor<LogEntry>())

//         return CloudSyncPayload(
//             generatedAt: .now,
//             users: users.map { user in
//                 CloudUser(
//                     email: user.email,
//                     displayName: user.displayName,
//                     usesBiometrics: user.usesBiometrics,
//                     sessionToken: user.sessionToken,
//                     lastSignIn: user.lastSignIn,
//                     createdAt: user.createdAt
//                 )
//             },
//             cars: cars.map { car in
//                 CloudCar(
//                     registration: car.registration,
//                     make: car.make,
//                     model: car.model,
//                     year: car.year,
//                     nickname: car.nickname,
//                     ownerEmail: car.owner?.email,
//                     createdAt: car.createdAt
//                 )
//             },
//             logs: logs.map { entry in
//                 CloudLogEntry(
//                     date: entry.date,
//                     speedometerKm: entry.speedometerKm,
//                     distanceKm: entry.distanceKm,
//                     fuelLiters: entry.fuelLiters,
//                     fuelSpend: entry.fuelSpend,
//                     garageName: entry.garageName,
//                     garageSubtitle: entry.garageSubtitle,
//                     garageLatitude: entry.garageLatitude,
//                     garageLongitude: entry.garageLongitude,
//                     garageMapItemIdentifier: entry.garageMapItemIdentifier,
//                     createdAt: entry.createdAt,
//                     userEmail: entry.user?.email,
//                     carRegistration: entry.car?.registration
//                 )
//             }
//         )
//     }
// }
