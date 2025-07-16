//
//  WorkOutTimerWidget.swift
//  WorkOutTimerWidget
//
//  Created by 김태훈 on 3/13/25.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    private struct Constants {
        static let appGroupIdentifier = "group.com.kimtaehun.WorkOutTimer"
        static let workEndTimeKey = "workEndTime"
        static let workStartTimeKey = "workStartTime"
        static let updateInterval: TimeInterval = 60 // 1분
    }
    
    private let defaults: UserDefaults
    
    init() {
        self.defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        let endTime = defaults.double(forKey: Constants.workEndTimeKey)
        return SimpleEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            endDate: Date(timeIntervalSince1970: endTime),
            widgetFamily: context.family
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let endTime = defaults.double(forKey: Constants.workEndTimeKey)
        return SimpleEntry(
            date: .now,
            configuration: configuration,
            endDate: Date(timeIntervalSince1970: endTime),
            widgetFamily: context.family
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let endTime = defaults.double(forKey: Constants.workEndTimeKey)
        let endDate = Date(timeIntervalSince1970: endTime)
        
        let entry = SimpleEntry(
            date: currentDate,
            configuration: configuration,
            endDate: endDate,
            widgetFamily: context.family
        )
        
        if endDate.timeIntervalSince1970 > currentDate.timeIntervalSince1970 {
            // 근무 중: 1분마다 업데이트 (배터리 최적화)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } else {
            // 퇴근 후: 업데이트 불필요
            return Timeline(entries: [entry], policy: .never)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let endDate: Date
    let widgetFamily: WidgetFamily
    
    var remainingTime: TimeInterval {
        max(0, endDate.timeIntervalSince(date))
    }
    
    var isWorkTime: Bool {
        endDate.timeIntervalSince1970 > Date().timeIntervalSince1970
    }
}

struct TimerWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Static formatter for better performance
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
    
    var formattedEndTime: String {
        Self.timeFormatter.string(from: entry.endDate)
    }
    
    var body: some View {
        Group {
            switch entry.widgetFamily {
            case .systemSmall:
                SmallWidgetView(entry: entry, formattedEndTime: formattedEndTime)
            case .systemMedium:
                MediumWidgetView(entry: entry, formattedEndTime: formattedEndTime)
            case .accessoryCircular:
                CircularWidgetView(entry: entry)
            case .accessoryRectangular:
                RectangularWidgetView(entry: entry, formattedEndTime: formattedEndTime)
            case .accessoryInline:
                InlineWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry, formattedEndTime: formattedEndTime)
            }
        }
        .widgetURL(URL(string: "workoutTimer://open"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Size Views

struct SmallWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        VStack(spacing: 2) {
            if entry.isWorkTime {
                Text("퇴근까지")
                    .font(.system(size: 12))
                Text(entry.endDate, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text("🏠 \(formattedEndTime)")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                VStack {
                    Image("dobi")
                        .resizable()
                        .scaledToFill()
                }
            }
        }
        .padding(.all, 8)
        .accessibilityLabel(entry.isWorkTime ? "퇴근까지 남은 시간" : "퇴근 완료")
        .accessibilityValue(entry.isWorkTime ? Text(entry.endDate, style: .timer) : Text("퇴근했습니다"))
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if entry.isWorkTime {
                    Text("퇴근까지")
                        .font(.headline)
                    Text(entry.endDate, style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 32, weight: .bold))
                    Text("🏠 \(formattedEndTime)에 퇴근")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("수고하셨습니다!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("오늘 하루도 고생 많으셨어요 🎉")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct CircularWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        if entry.isWorkTime {
            Text(entry.endDate, style: .timer)
                .monospacedDigit()
                .font(.system(size: 14, weight: .bold))
                .multilineTextAlignment(.center)
        } else {
            Text("완료")
                .font(.system(size: 12, weight: .bold))
        }
    }
}

struct RectangularWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isWorkTime {
                Text("퇴근까지")
                    .font(.caption2)
                Text(entry.endDate, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 16, weight: .bold))
                Text("🏠 \(formattedEndTime)")
                    .font(.caption2)
            } else {
                Text("도비는 자유에요!")
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        if entry.isWorkTime {
            Text("퇴근까지 \(entry.endDate, style: .timer)")
                .monospacedDigit()
        } else {
            Text("도비는 자유에요!")
        }
    }
}

struct WorkOutTimerWidget: Widget {
    let kind: String = "com.kimtaehun.WorkOutTimer.WorkOutTimerWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TimerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("퇴근 타이머")
        .description("퇴근까지 남은 시간을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    WorkOutTimerWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        endDate: .now.addingTimeInterval(32400),
        widgetFamily: .systemSmall
    )
}
