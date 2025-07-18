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
        static let appGroupIdentifier = "group.com.th.WorkOutTimer"
        static let workEndTimeKey = "workEndTime"
        static let workStartTimeKey = "workStartTime"
        static let workDateKey = "workDate"
    }
    
    private let defaults: UserDefaults
    
    init() {
        self.defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        return SimpleEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            endDate: Date().addingTimeInterval(3600),
            isValidWork: false,
            widgetFamily: context.family
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let (endDate, isValid) = getWorkStatus()
        return SimpleEntry(
            date: .now,
            configuration: configuration,
            endDate: endDate,
            isValidWork: isValid,
            widgetFamily: context.family
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let (endDate, isValid) = getWorkStatus()
        
        let entry = SimpleEntry(
            date: currentDate,
            configuration: configuration,
            endDate: endDate,
            isValidWork: isValid,
            widgetFamily: context.family
        )
        
        if isValid {
            // ✨ 간단한 타임라인: 퇴근 시간 + 1분 후에 한 번만 업데이트
            let refreshTime = endDate.addingTimeInterval(60) // 퇴근 후 1분 뒤 새로고침
            return Timeline(entries: [entry], policy: .after(refreshTime))
        } else {
            // 🎉 근무하지 않음: 업데이트 안함
            return Timeline(entries: [entry], policy: .never)
        }
    }
    
    // 🔍 현재 근무 상태 확인 및 만료된 데이터 정리
    private func getWorkStatus() -> (Date, Bool) {
        let endTime = defaults.double(forKey: Constants.workEndTimeKey)
        let workDateString = defaults.string(forKey: Constants.workDateKey)
        
        // 기본값 설정
        guard endTime > 0 else {
            return (Date().addingTimeInterval(3600), false)
        }
        
        let endDate = Date(timeIntervalSince1970: endTime)
        let currentDate = Date()
        
        // 🗓️ 날짜 검증
        let today = Self.dateFormatter.string(from: currentDate)
        let isValidWorkDay = workDateString == today
        
        // 🕰️ 시간 검증 (퇴근 시간이 지났는지)
        let isWorkTimeValid = endDate > currentDate
        
        let isValidWork = isValidWorkDay && isWorkTimeValid
        
        // 🧹 만료된 데이터 자동 정리
        if !isValidWork && endTime > 0 {
            print("🧹 위젯에서 만료된 근무 데이터 정리")
            defaults.set(0, forKey: Constants.workEndTimeKey)
            defaults.removeObject(forKey: Constants.workStartTimeKey)
            defaults.removeObject(forKey: Constants.workDateKey)
        }
        
        return (endDate, isValidWork)
    }
    
    // 날짜 포맷터
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let endDate: Date
    let isValidWork: Bool
    let widgetFamily: WidgetFamily
}

struct TimerWidgetEntryView: View {
    var entry: Provider.Entry
    
    // 시간 포맷터
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
            if Date() < entry.endDate {
                Text("퇴근까지")
                    .font(.system(size: 12))
                // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
                Text(entry.endDate, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text("🏠 \(formattedEndTime)")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                VStack(spacing: 4) {
                    Text("🎉")
                        .font(.system(size: 32))
                    Text("퇴근이다!")
                        .font(.system(size: 16, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("수고하셨습니다!")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.all, 8)
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if Date() < entry.endDate {
                    Text("퇴근까지")
                        .font(.headline)
                    // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
                    Text(entry.endDate, style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 32, weight: .bold))
                    Text("🏠 \(formattedEndTime)에 퇴근")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("🎉 수고하셨습니다!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("오늘 하루도 고생 많으셨어요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("푹 쉬세요! 😊")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
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
        if Date() < entry.endDate {
            // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
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
        HStack {
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                if Date() < entry.endDate {
                    Text("퇴근까지")
                        .font(.caption2)
                    // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
                    Text(entry.endDate, style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 16, weight: .bold))
                    Text("🏠 \(formattedEndTime)")
                        .font(.caption2)
                } else {
                    Text("퇴근 완료!")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            Spacer()
        }
    }
}

struct InlineWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        if Date() < entry.endDate {
            // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
            Text("퇴근까지 \(entry.endDate, style: .timer)")
                .monospacedDigit()
        } else {
            Text("퇴근 완료!")
        }
    }
}

struct WorkOutTimerWidget: Widget {
    let kind: String = "com.th.WorkOutTimer.WorkOutTimerWidget"
    
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
        isValidWork: true,
        widgetFamily: .systemSmall
    )
}
