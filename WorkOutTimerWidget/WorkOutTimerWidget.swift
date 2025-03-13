//
//  WorkOutTimerWidget.swift
//  WorkOutTimerWidget
//
//  Created by Lukus on 3/13/25.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    let defaults = UserDefaults(suiteName: "group.com.taehun.WorkOutTimer")
    
    func placeholder(in context: Context) -> SimpleEntry {
        let endTime = defaults?.double(forKey: "workEndTime") ?? 0
        return SimpleEntry(date: .now, configuration: ConfigurationAppIntent(), endDate: Date(timeIntervalSince1970: endTime))
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let endTime = defaults?.double(forKey: "workEndTime") ?? 0
        return SimpleEntry(date: .now, configuration: configuration, endDate: Date(timeIntervalSince1970: endTime))
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let endTime = defaults?.double(forKey: "workEndTime") ?? 0
        let endDate = Date(timeIntervalSince1970: endTime)
        
        if endDate.timeIntervalSince1970 > currentDate.timeIntervalSince1970 {
            let entry = SimpleEntry(date: currentDate, configuration: configuration, endDate: endDate)
            return Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .second, value: 1, to: currentDate)!))
        } else {
            let entry = SimpleEntry(date: endDate, configuration: configuration, endDate: endDate)
            return Timeline(entries: [entry], policy: .never)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let endDate: Date
    
    var remainingTime: TimeInterval {
        max(0, endDate.timeIntervalSince(date))
    }
}

struct TimerWidgetEntryView : View {
    var entry: Provider.Entry
    
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.endDate)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            if entry.remainingTime > 0 {
                Text("퇴근까지")
                    .font(.system(size: 12))
                let remainingDate = Date(timeIntervalSinceNow: entry.remainingTime)
                Text(remainingDate, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text("🏠 \(formattedEndTime)")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text("퇴근이다!")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .padding(.all, 10)
        .widgetURL(URL(string: "workoutTimer://"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WorkOutTimerWidget: Widget {
    let kind: String = "com.taehun.WorkOutTimer.WorkOutTimerWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TimerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("퇴근 타이머")
        .description("퇴근까지 남은 시간을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    WorkOutTimerWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        endDate: .now.addingTimeInterval(32400)
    )
}
