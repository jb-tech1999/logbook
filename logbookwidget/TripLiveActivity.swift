import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Trip Live Activity Widget

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripLiveActivityAttributes.self) { context in
            // Lock screen and banner presentation
            TripLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island presentation
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        Text("\(context.state.distanceTraveled, format: .number.precision(.fractionLength(1))) km")
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.orange)
                        Text("\(context.state.currentSpeed, format: .number.precision(.fractionLength(0)))")
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        if let make = context.attributes.carMake, let model = context.attributes.carModel {
                            Label("\(make) \(model)", systemImage: "car.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(context.state.startDate, style: .timer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        
                        // Stop trip button
                        Link(destination: URL(string: "logbook://stopTrip")!) {
                            Label("Stop Trip", systemImage: "stop.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact leading (left side of pill)
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text("\(context.state.distanceTraveled, format: .number.precision(.fractionLength(0)))")
                        .font(.caption2.weight(.semibold))
                }
            } compactTrailing: {
                // Compact trailing (right side of pill)
                HStack(spacing: 2) {
                    Text("\(context.state.currentSpeed, format: .number.precision(.fractionLength(0)))")
                        .font(.caption2.weight(.semibold))
                    Image(systemName: "speedometer")
                        .foregroundStyle(.orange)
                }
            } minimal: {
                // Minimal presentation (just icon when multiple activities)
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Lock Screen / Banner View

struct TripLiveActivityView: View {
    let context: ActivityViewContext<TripLiveActivityAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text("Trip in Progress")
                    .font(.headline)
                Spacer()
                Text(context.state.startDate, style: .timer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.caption)
                        Text("\(context.state.distanceTraveled, format: .number.precision(.fractionLength(1))) km")
                            .font(.title3.weight(.semibold))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("\(context.state.currentSpeed, format: .number.precision(.fractionLength(0))) km/h")
                            .font(.title3.weight(.semibold))
                        Image(systemName: "speedometer")
                            .font(.caption)
                    }
                }
            }
            
            // Vehicle info if available
            if let make = context.attributes.carMake, 
               let model = context.attributes.carModel,
               let year = context.attributes.carYear {
                Divider()
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.secondary)
                    Text("\(year) \(make) \(model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.2))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Preview

#Preview("Trip Live Activity", as: .dynamicIsland(.compact), using: TripLiveActivityAttributes(
    carMake: "Toyota",
    carModel: "Corolla",
    carYear: 2022,
    tripStartDate: Date()
)) {
    TripLiveActivity()
} contentStates: {
    TripLiveActivityAttributes.ContentState(
        distanceTraveled: 12.5,
        currentSpeed: 85,
        duration: 900,
        startDate: Date(),
        isActive: true
    )
    TripLiveActivityAttributes.ContentState(
        distanceTraveled: 45.2,
        currentSpeed: 120,
        duration: 1800,
        startDate: Date().addingTimeInterval(-1800),
        isActive: true
    )
}
