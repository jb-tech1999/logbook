# Logbook 📖🚗

> A personal vehicle logbook for iOS — track fuel, trips, spending, and driving patterns across your entire garage.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Data Models](#data-models)
- [Services](#services)
- [Views](#views)
- [Widgets & Extensions](#widgets--extensions)
- [CarPlay Integration](#carplay-integration)
- [Live Activities & Dynamic Island](#live-activities--dynamic-island)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup & Requirements](#setup--requirements)
- [Deep Links](#deep-links)
- [Known Limitations](#known-limitations)
- [Possible Next Steps](#possible-next-steps)
- [Apple Documentation References](#apple-documentation-references)

---

## Overview

Logbook is a native iOS application built with **SwiftUI** and **SwiftData** that acts as a personal vehicle logbook. It lets drivers record every fill-up, track their routes automatically, analyse fuel economy over time, and see their driving stats on the Home Screen via a WidgetKit widget.

The app is designed around a single-user, multi-vehicle model. One profile can own many cars, and each car accumulates fuel logs and GPS-tracked trips independently.

---

## Features

### 🏠 Dashboard
- Lifetime aggregate stats: total distance, total fuel purchased, total spend
- Average fuel efficiency (km/L), cost per km, and cost per litre
- Per-car summary listing
- Recent log entries at a glance
- Fuel economy trend chart (filterable by week / month / 3 months / year) powered by **Swift Charts**
- Widget snapshot is re-written every time the dashboard loads so the Home Screen widget is always fresh

### 📋 Fuel Logs
- Add, edit, and delete fill-up records
- Fields: date, vehicle, speedometer reading, trip distance, litres filled, amount spent
- Search for the fill-up location by name using **MapKit Local Search**
- Each garage suggestion shows its name **and full address** (using the iOS 26 `MKMapItem.address` API) so you can distinguish between two stations with the same brand
- Searches are scoped to `gasStation` and `automotiveRepair` POI categories within a 20 km radius
- Garage is persisted with its unique `MKMapItem.identifier` so duplicates are filtered correctly across sessions
- Swipe-to-delete and inline edit support

### 🗺️ Garage Map
- Interactive MapKit map showing every gas station you have **previously refuelled at**, derived from your log entries (not a live nearby search)
- Standard / Hybrid / Imagery map style toggle
- Tap any pin to get directions — either open in Apple Maps or draw a turn-by-turn route overlay directly in the app
- Distance from your current location shown in the station list panel
- Panel is collapsible so the map fills the screen while navigating
- Camera automatically frames all your stations when the view loads

### 🚗 Garage (Vehicles)
- Add and manage multiple vehicles (make, model, year, registration, optional nickname)
- User profile banner at the top — edit display name and email inline
- Profile setup sheet shown when no user record exists, guiding first-time users before they can add a car
- Each car displays its log count and total distance

### 🛣️ Trips
- **Start / stop trip recording manually** from the Trips tab at any time
- Select which vehicle to associate with the trip at start time
- Live banner while recording shows real-time distance and current speed
- Trips list shows every completed trip with date, duration, distance, and max/avg speed
- Swipe to delete trips

#### Trip Detail View
- Full-screen interactive map of the route
- **Speed-gradient polyline**: each segment is coloured from 🔴 red (stopped) through 🟡 yellow to 🟢 green (maximum speed for that trip), giving an instant visual read of where you were slow or fast
- Start (green flag) and end (red checkered flag) map annotations
- Speed-over-time chart using **Swift Charts**
- Stats cards: total distance, duration, average speed, max speed
- Share trip summary sheet

### 👤 User Profile
- Local user account (email + display name + password digest)
- Biometric authentication flag stored on the model for future use
- Profile editable from the Garage tab at any time
- `ensureUserRecord` guard on every launch creates a default user if none exists so the app never blocks on an empty database

---

## Architecture

```
logbookApp (SwiftUI App)
    │
    ├── AppDelegate (UIApplicationDelegate)
    │       └── Routes CarPlay scene sessions → CarPlaySceneDelegate
    │
    ├── AppModelContainer
    │       └── Single SwiftData ModelContainer stored in App Group
    │           (group.com.personal.logbook) so widget + app share one store
    │
    ├── TripTrackingService (@MainActor ObservableObject)
    │       └── Injected as @EnvironmentObject into the whole view hierarchy
    │
    └── ContentView
            └── TabView
                    ├── DashboardView
                    ├── GarageMapView
                    ├── TripsView
                    ├── LogsView
                    └── VehiclesView
```

### State Management

| Mechanism | Used For |
|---|---|
| `@Query` (SwiftData) | All persisted data — logs, cars, users, trips |
| `@Environment(\.modelContext)` | Inserting and saving SwiftData records |
| `@EnvironmentObject` | `TripTrackingService` shared across the whole app |
| `@StateObject` | `LocationManager` (owned by `ContentView`) |
| `@ObservedObject` | `LocationManager` passed into child views |
| `@AppStorage` | `isAuthenticated` persisted across launches |
| `@State` | Local UI state within individual views |

### Data Flow: Widget Snapshot

```
User saves a LogEntry
        ↓
AppDashboardMetricsService.buildAndPersist(using: modelContext)
        ↓
Reads LogEntry + User from SwiftData
Computes 11 KPIs
Encodes DashboardMetricsSnapshot (Codable) as JSON
        ↓
Writes to UserDefaults(suiteName: "group.com.personal.logbook")
key: "logbook_widget_snapshot"
        ↓
Calls WidgetCenter.shared.reloadAllTimelines()
        ↓
Widget extension reads WidgetSnapshot.load() from the same App Group
```

---

## Data Models

All models use `@Model` from **SwiftData** and are stored in an App Group container shared with the widget extension.

### `User`
| Field | Type | Notes |
|---|---|---|
| `email` | `String` | `@Attribute(.unique)` |
| `displayName` | `String` | Shown in profile banner and widget |
| `passwordDigest` | `String` | Stored locally — not sent anywhere |
| `usesBiometrics` | `Bool` | Reserved for future Face ID / Touch ID |
| `sessionToken` | `String?` | Optional session management |
| `cars` | `[Car]` | `@Relationship(deleteRule: .cascade)` |
| `logs` | `[LogEntry]` | `@Relationship(deleteRule: .cascade)` |

### `Car`
| Field | Type | Notes |
|---|---|---|
| `make` | `String` | e.g. "Toyota" |
| `model` | `String` | e.g. "Corolla" |
| `year` | `Int` | e.g. 2022 |
| `registration` | `String` | `@Attribute(.unique)` |
| `nickname` | `String?` | Optional friendly name |
| `logs` | `[LogEntry]` | `@Relationship(deleteRule: .cascade)` |

### `LogEntry`
| Field | Type | Notes |
|---|---|---|
| `date` | `Date` | Fill-up date/time |
| `speedometerKm` | `Double` | Odometer reading at fill-up |
| `distanceKm` | `Double` | Distance since last fill-up |
| `fuelLiters` | `Double` | Litres purchased |
| `fuelSpend` | `Double` | Amount paid |
| `garageName` | `String?` | From `MKMapItem.name` |
| `garageSubtitle` | `String?` | Address from `MKMapItem.address.shortAddress` |
| `garageLatitude` | `Double?` | For map pin |
| `garageLongitude` | `Double?` | For map pin |
| `garageMapItemIdentifier` | `String?` | `MKMapItem.identifier.rawValue` — used for deduplication |

### `Trip`
| Field | Type | Notes |
|---|---|---|
| `startDate` | `Date` | Trip start time |
| `endDate` | `Date?` | Nil while active |
| `totalDistance` | `Double` | km — written when trip stops |
| `averageSpeed` | `Double` | km/h — computed from all points |
| `maxSpeed` | `Double` | km/h — tracked in real-time |
| `isActive` | `Bool` | `true` while recording |
| `car` | `Car?` | Optional vehicle association |
| `points` | `[TripPoint]?` | GPS breadcrumbs |

Computed: `duration: TimeInterval?`, `durationFormatted: String`

### `TripPoint`
| Field | Type | Notes |
|---|---|---|
| `timestamp` | `Date` | From `CLLocation.timestamp` |
| `latitude` | `Double` | WGS-84 |
| `longitude` | `Double` | WGS-84 |
| `speed` | `Double` | km/h (converted from m/s via `* 3.6`) |
| `altitude` | `Double?` | Metres above sea level |
| `trip` | `Trip?` | Parent relationship |

Convenience init from `CLLocation`. Computed `coordinate: CLLocationCoordinate2D`.

### `TripLiveActivityAttributes`
ActivityKit `ActivityAttributes` struct for the Live Activity / Dynamic Island.

**Static** (set once at trip start): `carMake`, `carModel`, `carYear`, `tripStartDate`

**Dynamic** (`ContentState`, updated every 2 seconds): `distanceTraveled`, `currentSpeed`, `duration`, `startDate`, `isActive`

---

## Services

### `AppModelContainer`
Bootstraps the single shared `ModelContainer` with schema `[User, Car, LogEntry, Trip, TripPoint]` stored in the App Group container (`groupContainer: .identifier("group.com.personal.logbook")`). Called once at app startup; `fatalError` on failure.

### `SharedModelContainer`
Exposes the constant `appGroupIdentifier = "group.com.personal.logbook"`. Cross-target safe — no SwiftData model references.

### `LocationManager`
Lightweight `CLLocationManager` wrapper (`ObservableObject`) for **UI-facing** location needs (garage map centering, speed display in the log form). Requests `.authorizedWhenInUse`. Published properties: `lastKnownLocation`, `speedKmh`.

### `TripTrackingService`
The core trip-recording engine. `@MainActor` `ObservableObject` injected as `@EnvironmentObject`.

| Constant | Value | Purpose |
|---|---|---|
| `distanceFilter` | 5 m | Only wake GPS if moved ≥ 5 m |
| `minimumDistanceForPoint` | 5 m | Only write a `TripPoint` if moved ≥ 5 m since last save |
| `recordingInterval` | 5 s | Timer interval for `TripPoint` writes |
| `liveActivityUpdateInterval` | 2 s | Timer interval for Dynamic Island refresh |

Key responsibilities:
- Manages `CLLocationManager` lifecycle with `allowsBackgroundLocationUpdates = true` (guarded by `UIBackgroundModes` check to prevent `abort()` crash)
- Creates `Trip` + inserts `TripPoint` records into SwiftData every 5 seconds
- Computes running `distanceTraveled` in real-time on every `didUpdateLocations` callback (not just on point saves)
- Starts / updates / ends the `Activity<TripLiveActivityAttributes>` Live Activity
- Exposes `isTracking`, `currentSpeed`, `distanceTraveled` for the UI

### `GarageService`
Async MapKit search wrapper.

- `nearbyGarages(around:within:)` — 15 km radius, returns up to 20 results
- `searchGarages(matching:near:within:)` — 20 km radius, free-text query
- Uses iOS 26 `MKLocalSearch` with POI filter `[.gasStation, .automotiveRepair]`
- Address built from `MKMapItem.address.shortAddress` (iOS 26) → `MKMapItem.addressRepresentations` fallback
- Unique identifier from `MKMapItem.identifier.rawValue` (not POI category)
- Results sorted by distance from user location using `item.location` (non-deprecated iOS 26 API)

### `AppDashboardMetricsService`
App-only (not in widget target) service that reads `LogEntry` and `User` from SwiftData, computes 11 KPIs, builds a `DashboardMetricsSnapshot`, and calls `snapshot.persist()` which writes to App Group `UserDefaults` and calls `WidgetCenter.shared.reloadAllTimelines()`.

Called from:
- `logbookApp.swift` on every launch (`.task`)
- `DashboardView` whenever the data signature changes (`.task(id: widgetRefreshSignature)`)
- `LogEntryFormView` after every successful save

### `CarPlaySceneDelegate`
`CPTemplateApplicationSceneDelegate` that receives CarPlay connect / disconnect callbacks from the system.

- On `didConnect`: fetches the most recently added `Car` from SwiftData, calls `tripTrackingService.startTracking(car:)`, presents a `CPInformationTemplate` dashboard
- On `didDisconnect`: calls `tripTrackingService.stopTracking()`
- Receives `tripTrackingService` and `modelContext` injected from `AppDelegate` via `logbookApp.swift`

---

## Views

### `ContentView`
Root view. Holds `@AppStorage("isAuthenticated")` which defaults to `true` on fresh install (skipping the sign-in gate). Contains the 5-tab `TabView` and `LocationManager` as a `@StateObject`. Calls `ensureUserRecord` on the `.task` modifier to guarantee a user record always exists.

Tabs:
| Tab | Icon | View |
|---|---|---|
| Dashboard | `speedometer` | `DashboardView` |
| Map | `map` | `GarageMapView` |
| Trips | `map.fill` | `TripsView` |
| Logs | `list.bullet.rectangle` | `LogsView` |
| Garage | `car` | `VehiclesView` |

### `DashboardView`
Scrollable stats overview. Uses `@Query` to observe all `LogEntry`, `Car`, and `User` records reactively. Sections: metrics grid (4 KPI cards), fuel economy trend chart, cars summary, recent logs, footer.

Trend chart uses a `FuelEconomySample` array bucketed by the selected `FuelTrendRange` (week / month / 3 months / year). Falls back to the most recent 12 entries when no data exists in the selected range.

### `LogsView`
`List` of all `LogEntry` records sorted by date descending. Supports inline swipe-to-edit, swipe-to-delete, and an `EditButton` for multi-delete. Presents `LogEntryFormView` as a sheet for add/edit.

### `LogEntryFormView`
`Form`-based add/edit sheet for `LogEntry`.

- Vehicle picker
- Numeric fields for odometer, distance, litres, spend (`.decimalPad`)
- Garage search: type a name → tap Search → results appear as individual `Form` rows (not a `Picker`) so each row has its own independent hit target — fixing the iPhone touch-selection bug where `Picker` with `VStack` labels always triggered the first item
- Each garage row shows name (headline) + address (caption, secondary) + checkmark if selected
- On save: inserts/updates `LogEntry`, calls `AppDashboardMetricsService.buildAndPersist`

### `GarageMapView`
Full-screen `Map` view showing pins for every unique gas station in the user's log history.

- Loads garages from `@Query` on `LogEntry`, deduplicating by `garageMapItemIdentifier` (falling back to coordinates)
- Camera bounding-box calculation to frame all pins on load
- Bottom panel (collapsible) lists stations with name, address, distance
- Tap a pin or list row → alert with "Open in Maps" or "Show Route" options
- Route overlay drawn with `MKDirections` when "Show Route" is chosen
- Map style toggle: Standard / Hybrid / Imagery

### `TripsView`
Trips recording and history screen.

- `Start New Trip` button (blue) → shows car selection sheet → calls `tripTrackingService.startTracking(car:)`
- Active trip banner (red pulsing dot, live distance + speed) shown while `isTracking == true`
- `Stop Trip` button (red) → calls `tripTrackingService.stopTracking()`
- List of completed trips: date, vehicle, duration, distance, avg/max speed badge
- `NavigationStack` with `navigationDestination(item: $selectedTrip)` → `TripDetailView`
- Empty state with `Start New Trip` button included so the call-to-action is always visible

### `TripDetailView`
Detailed view for a single completed or active `Trip`.

- `Map` with `ForEach` over consecutive `TripPoint` pairs, each rendered as a `MapPolyline` coloured by speed relative to the trip's max speed
  - Red (`Color(red:0, green:0, blue:0)` → `Color.red`) for 0 km/h
  - Linear interpolation through yellow to green at max speed
- Speed-gradient legend overlay (bottom-right) showing the colour scale with 0 and max speed labels
- Start / end `Annotation` markers
- Stats cards: distance, duration, avg speed, max speed
- `Chart` (Swift Charts) plotting speed vs. time for each `TripPoint`
- Share sheet exporting a plain-text trip summary

### `VehiclesView`
Vehicle and profile management.

- Profile section at top: shows `User.displayName` + email with edit pencil, or a "Set Up Your Profile" CTA if no user exists
- `ProfileSetupView` sheet for creating or editing the user profile
- Vehicle list with make/model/year/registration/nickname
- `CarFormView` sheet for adding/editing a `Car` (requires a `User` to exist)

---

## Widgets & Extensions

The widget extension (`logbookwidgetExtension`) lives in the `logbookwidget/` folder and is a completely separate process from the main app.

### Home Screen Widget (`logbookwidget`)

Reads `WidgetSnapshot` from `UserDefaults(suiteName: "group.com.personal.logbook")` key `"logbook_widget_snapshot"`. Returns `WidgetSnapshot.empty` (zeroed values, no placeholder emoji) if no data has been written yet.

Timeline refreshes every 15 minutes. `WidgetCenter.shared.reloadAllTimelines()` is also called by the main app on every data change so the widget is never stale.

**Supported families:**

| Family | Content |
|---|---|
| `.systemSmall` | Hero metric: avg km/L (large rounded number) + total distance + last fill-up relative time. `ViewThatFits` degrades gracefully at large Dynamic Type. |
| `.systemMedium` | 2 × 2 `HStack` grid of KPI tiles: distance, fuel, spend, efficiency |
| `.systemLarge` | Full dashboard: 2 × 2 KPI grid + cost/km, cost/L, log count pills + last fill-up detail with garage name and vehicle label |
| `.accessoryCircular` | Lock Screen / StandBy gauge showing km/L (0–20 scale) |
| `.accessoryRectangular` | Lock Screen bar: distance • km/L • total spend |

Each tile is a `KPITile` view with `fixedHeight: 56` (large widget) so `RoundedRectangle` backgrounds never clip. All text has `.lineLimit(1)` + `.minimumScaleFactor(0.6)` to prevent wrapping. Manual `.padding()` inside widget views is avoided; `containerBackground` provides system-correct insets.

### Live Activity / Dynamic Island (`TripLiveActivity`)

`ActivityConfiguration(for: TripLiveActivityAttributes.self)` registered in the widget bundle alongside the Home Screen widget.

**Dynamic Island presentations:**

| Region | Content |
|---|---|
| Compact leading | 📍 distance (km) |
| Compact trailing | speed (km/h) |
| Minimal | Location icon only |
| Expanded leading | Distance with icon |
| Expanded trailing | Speed with icon |
| Expanded center | Car name + elapsed timer |
| Expanded bottom | **Stop Trip** button (`Link` → `logbook://stopTrip`) |

**Lock Screen / banner**: Shows trip status, elapsed timer, distance, speed, vehicle info. Tapping opens the app.

Live Activity starts when `tripTrackingService.startTracking()` is called (iOS will prompt for permission on first start). Updates every 2 seconds via a `Timer`. Ends with a 60-second stale-content policy when `tripTrackingService.stopTracking()` is called.

---

## CarPlay Integration

The app registers a `CPTemplateApplicationScene` in `Info.plist` and routes it to `CarPlaySceneDelegate` via `AppDelegate`.

When CarPlay connects:
1. `CarPlaySceneDelegate.templateApplicationScene(_:didConnect:)` fires
2. Fetches most recent `Car` from SwiftData
3. Calls `tripTrackingService.startTracking(car:)` — trip recording begins automatically, no driver interaction needed
4. Presents a minimal `CPInformationTemplate` ("Trip tracking active")

When CarPlay disconnects:
1. `CarPlaySceneDelegate.templateApplicationScene(_:didDisconnect:)` fires
2. Calls `tripTrackingService.stopTracking()` — trip is saved to SwiftData

**Entitlement required:** `com.apple.developer.carplay-information`
This entitlement works for development builds but requires Apple approval before App Store distribution. Request at [https://developer.apple.com/contact/carplay/](https://developer.apple.com/contact/carplay/).

---

## Live Activities & Dynamic Island

Live Activities are enabled via `NSSupportsLiveActivities = YES` in build settings (both Debug and Release). The permission prompt is shown by iOS the first time `Activity.request(...)` is called — the app does not check `areActivitiesEnabled` before calling this, which is intentional (checking before requesting prevents the system prompt from appearing).

Requires iOS 16.1+. Dynamic Island requires iPhone 14 Pro or later. Older devices receive the Lock Screen / banner presentation only.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI (iOS 26 target) |
| Persistence | SwiftData |
| Location | Core Location (`CLLocationManager`) |
| Maps | MapKit (`Map`, `MKLocalSearch`, `MKDirections`) |
| Charts | Swift Charts |
| Widgets | WidgetKit |
| Live Activities | ActivityKit |
| CarPlay | CarPlay framework (`CPTemplateApplicationScene`) |
| Concurrency | Swift Concurrency (`async/await`, `Task`, `@MainActor`) |
| Cross-process data | `UserDefaults(suiteName:)` App Group |
| Deep linking | Custom URL scheme `logbook://` |

---

## Project Structure

```
logbook/
├── logbook/                        # Main app target
│   ├── logbookApp.swift            # App entry point, AppDelegate, CarPlay wiring
│   ├── ContentView.swift           # Root TabView, auth gate
│   ├── Info.plist                  # CarPlay scene manifest
│   ├── logbook.entitlements        # App Groups + CarPlay entitlement
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Car.swift
│   │   ├── LogEntry.swift
│   │   ├── Trip.swift
│   │   ├── TripPoint.swift
│   │   └── TripLiveActivityAttributes.swift
│   ├── Services/
│   │   ├── AppModelContainer.swift       # SwiftData container bootstrap
│   │   ├── SharedModelContainer.swift    # App Group ID constant (cross-target)
│   │   ├── LocationService.swift         # UI-facing CLLocationManager wrapper
│   │   ├── TripTrackingService.swift     # Background GPS trip recorder
│   │   ├── GarageService.swift           # MapKit Local Search wrapper
│   │   ├── AppDashboardMetricsService.swift  # Widget snapshot builder
│   │   ├── DashboardMetricsProvider.swift    # Snapshot storage (cross-target)
│   │   └── CarPlaySceneDelegate.swift    # CarPlay scene handler
│   ├── Views/
│   │   ├── DashboardView.swift
│   │   ├── LogsView.swift
│   │   ├── LogEntryFormView.swift
│   │   ├── GarageMapView.swift
│   │   ├── TripsView.swift
│   │   ├── TripDetailView.swift
│   │   ├── VehiclesView.swift
│   │   └── CarFormView.swift
│   └── Widgets/
│       ├── DashboardWidget.swift         # (unused — see logbookwidget/)
│       └── DashboardWidgetBundle.swift   # (unused — see logbookwidget/)
│
├── logbookwidget/                  # Widget extension target
│   ├── logbookwidgetBundle.swift   # @main WidgetBundle
│   ├── logbookwidget.swift         # Home Screen widget (Small/Medium/Large/Accessory)
│   └── TripLiveActivity.swift      # Live Activity + Dynamic Island
│
└── logbook.xcodeproj/
```

---

## Setup & Requirements

### System Requirements
- **Xcode 16+** (iOS 26 SDK)
- **iOS 16.1+** for Live Activities
- **iOS 16.2+** recommended
- **iPhone 14 Pro+** for Dynamic Island
- **Physical device** required for background location tracking (simulator works for development)

### First-Time Xcode Setup

1. **App Group** — both targets must have the same App Group capability:
   - Target: `logbook` → Signing & Capabilities → App Groups → `group.com.personal.logbook` ✅
   - Target: `logbookwidgetExtension` → same → `group.com.personal.logbook` ✅

2. **Build Settings** — main app target:
   - `GENERATE_INFOPLIST_FILE = NO`
   - `INFOPLIST_FILE = logbook/Info.plist`
   - `NSSupportsLiveActivities = YES` (in both Debug and Release)
   - `UIBackgroundModes = location`

3. **CarPlay Entitlement** — already present in `logbook.entitlements`. Works for development. Requires Apple approval for App Store.

4. **Clean build after any entitlement change:** ⌘⇧K → ⌘R

### Running the App

1. Open `logbook.xcodeproj`
2. Select the **logbook** scheme (not `logbookwidgetExtension`)
3. Select your device or simulator
4. ⌘R

On first launch the app creates a default user record automatically. Go to the **Garage** tab to set up your profile and add a vehicle before logging.

---

## Deep Links

The app registers the `logbook://` URL scheme. Handled in `logbookApp.handleDeepLink(_:)`.

| URL | Action |
|---|---|
| `logbook://stopTrip` | Stops the active trip (used by Dynamic Island Stop button) |
| `logbook://dashboard` | Opens the app to the Dashboard tab (used by widget tap) |

---

## Known Limitations

| Area | Limitation |
|---|---|
| **Authentication** | Local only — no server-side auth. Password stored as plain string (not hashed). Credentials hardcoded in `ContentView` as default `@State` values. |
| **Accessibility** | Most interactive elements lack `.accessibilityLabel` and `.accessibilityHint`. VoiceOver navigation is incomplete. |
| **CarPlay UI** | CarPlay screen shows only a static information template. No live updating of stats while the trip is in progress. |
| **Trip association** | Trips started via CarPlay are linked to the most recently added car, not necessarily the car being driven. |
| **Cloud sync** | `CloudSyncService` is present but fully commented out — no iCloud or remote sync. |
| **No unit tests** | No `XCTest` or Swift Testing targets. |
| **Multiple users** | The data model supports multiple `User` records but the UI always uses `users.first`. |

---

## Possible Next Steps

### High Priority
- [ ] **Secure credential storage** — move password to Keychain; remove hardcoded defaults from `ContentView`
- [ ] **Accessibility pass** — add `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue` to all interactive elements; test with VoiceOver
- [ ] **Error handling** — replace `fatalError` in `AppModelContainer` with a recovery screen; show user-facing error alerts for SwiftData failures
- [ ] **`@Relationship` on `Trip.points`** — add explicit `deleteRule: .cascade` and `inverse:` to prevent orphaned `TripPoint` records

### Features
- [ ] **iCloud sync** — enable `CloudKitDatabase` in `ModelConfiguration` for automatic cross-device sync (one line change in `AppModelContainer`)
- [ ] **Fuel price tracking** — add a `pricePerLitre` field to `LogEntry` and chart price trends over time
- [ ] **Multiple currencies** — `LogEntry.fuelSpend` is a raw `Double`; add a `currencyCode` field
- [ ] **Trip auto-detection** — use `CLActivityType.automotiveNavigation` significant-change monitoring to start/stop trips without CarPlay
- [ ] **CarPlay live dashboard** — update the `CPInformationTemplate` every 5 seconds with live distance and speed while a trip is recording
- [ ] **Reminders** — `UserNotifications` reminder when the car is due for a service based on odometer
- [ ] **Export** — CSV / PDF export of log entries for expense reports
- [ ] **Widgets: Interactive** — add an `.appIntent`-backed button to start/stop tracking directly from the Home Screen widget (requires iOS 17+ App Intents)
- [ ] **Lock Screen widget** — the accessory widget families are already implemented; test and polish on Lock Screen
- [ ] **Siri integration** — `AppIntents` to start/stop a trip or add a quick log entry by voice

### Engineering
- [ ] **Unit tests** — test `AppDashboardMetricsService`, `GarageService`, and `TripTrackingService` with mocked contexts
- [ ] **Centralise `LocationManager`** — currently instantiated separately in `ContentView`, `GarageMapView`, and `LogEntryFormView`; should be a single instance injected as `@EnvironmentObject`
- [ ] **`@Observable` migration** — `LocationManager` uses the older `@Published` + `ObservableObject` pattern; migrate to the Swift Observation framework (`@Observable`) introduced in iOS 17
- [ ] **Dependency injection** — `GarageService` and `AppDashboardMetricsService` are instantiated inline; move to protocol-based injection for testability
- [ ] **SwiftData migration plan** — add a `VersionedSchema` and `SchemaMigrationPlan` before changing any model fields in production

---

## Apple Documentation References

The following Apple frameworks, APIs, and documentation pages were used while building this application.

### SwiftUI & App Structure
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui) — Views, state, navigation, layout
- [NavigationStack](https://developer.apple.com/documentation/swiftui/navigationstack) — Modern navigation replacing deprecated `NavigationView`
- [TabView](https://developer.apple.com/documentation/swiftui/tabview) — 5-tab root navigation
- [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits) — Adaptive widget layouts
- [containerBackground(_:for:)](https://developer.apple.com/documentation/swiftui/view/containerbackground(_:for:)) — Widget background (replaces deprecated `.background` modifier)
- [Grid / GridRow](https://developer.apple.com/documentation/swiftui/grid) — Deterministic 2D layouts in widgets

### SwiftData
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata) — `@Model`, `@Query`, `ModelContainer`, `ModelContext`
- [ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration) — `groupContainer: .identifier(...)` for App Group storage shared with widget

### MapKit
- [MapKit Documentation](https://developer.apple.com/documentation/mapkit) — Map view, annotations, polylines
- [MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch) — Gas station search
- [MKPointOfInterestFilter](https://developer.apple.com/documentation/mapkit/mkpointofinterestfilter) — Scoped to `.gasStation`, `.automotiveRepair`
- [MKMapItem.address](https://developer.apple.com/documentation/mapkit/mkmapitem/address) — iOS 26 `MKAddress` API replacing deprecated `placemark.postalAddress`
- [MKMapItem.addressRepresentations](https://developer.apple.com/documentation/mapkit/mkmapitem/addressrepresentations) — iOS 26 `MKAddressRepresentations` fallback
- [MKMapItem.identifier](https://developer.apple.com/documentation/mapkit/mkmapitem/identifier) — Stable unique identifier per place (replaces using POI category as ID)
- [MKMapItem.location](https://developer.apple.com/documentation/mapkit/mkmapitem/location) — Non-deprecated `CLLocation` access (replaces `item.placemark.location`)
- [MKDirections](https://developer.apple.com/documentation/mapkit/mkdirections) — Route calculation for garage navigation
- [MapPolyline](https://developer.apple.com/documentation/mapkit/mappolyline) — Speed-gradient route segments

### Core Location
- [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager) — Background GPS tracking
- [allowsBackgroundLocationUpdates](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates) — Must set delegate before this property; requires `UIBackgroundModes = location`
- [CLActivityType.automotiveNavigation](https://developer.apple.com/documentation/corelocation/clactivitytype/automotivenavigation) — Optimises GPS for driving

### WidgetKit
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit) — `TimelineProvider`, `TimelineEntry`, widget families
- [WidgetCenter.reloadAllTimelines()](https://developer.apple.com/documentation/widgetkit/widgetcenter/reloadalltimelines()) — Forces immediate widget refresh after data changes
- [App Groups for WidgetKit](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget) — Sharing data between app and extension via `UserDefaults(suiteName:)`
- [WidgetFamily](https://developer.apple.com/documentation/widgetkit/widgetfamily) — `.systemSmall`, `.systemMedium`, `.systemLarge`, `.accessoryCircular`, `.accessoryRectangular`

### ActivityKit (Live Activities)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit) — `Activity`, `ActivityAttributes`, `ActivityConfiguration`
- [ActivityAuthorizationInfo](https://developer.apple.com/documentation/activitykit/activityauthorizationinfo) — `areActivitiesEnabled` (read-only; do not gate `Activity.request` on this)
- [DynamicIsland](https://developer.apple.com/documentation/activitykit/dynamicisland) — `DynamicIslandExpandedRegion`, compact leading/trailing/minimal
- [NSSupportsLiveActivities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) — Required `Info.plist` key

### Swift Charts
- [Swift Charts Documentation](https://developer.apple.com/documentation/charts) — Fuel economy trend chart, speed-over-time trip chart

### CarPlay
- [CarPlay Framework Documentation](https://developer.apple.com/documentation/carplay) — `CPTemplateApplicationScene`, `CPTemplateApplicationSceneDelegate`, `CPInformationTemplate`
- [CPTemplateApplicationSceneSessionRoleApplication](https://developer.apple.com/documentation/carplay/cptemplateapplicationscenesessionroleapplication) — Scene role registered in `Info.plist`
- [CarPlay Entitlement Request](https://developer.apple.com/contact/carplay/) — Required for App Store distribution

### Swift Concurrency
- [Swift Concurrency Documentation](https://developer.apple.com/documentation/swift/concurrency) — `async/await`, `Task`, `@MainActor`, structured concurrency
- [@MainActor](https://developer.apple.com/documentation/swift/mainactor) — All UI mutations and SwiftData writes run on the main actor

### App Architecture
- [App Groups](https://developer.apple.com/documentation/foundation/userdefaults) — `UserDefaults(suiteName:)` for cross-process data sharing (app → widget)
- [UIApplicationDelegate](https://developer.apple.com/documentation/uikit/uiapplicationdelegate) — `configurationForConnecting` for CarPlay scene routing
- [UIApplicationDelegateAdaptor](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor) — Bridging `UIApplicationDelegate` into a SwiftUI `App`
- [ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase) — Observing foreground/background transitions

---

*Built with ❤️ using the latest Apple frameworks. Last updated March 2026.*
