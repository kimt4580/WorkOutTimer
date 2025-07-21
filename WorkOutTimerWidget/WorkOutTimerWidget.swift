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
            endDate: Date(), // 의미없는 값
            isValidWork: false, // 근무하지 않음
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
        
        // 🔧 수정: 근무 데이터가 없으면 무효한 상태로 반환
        guard endTime > 0 else {
            return (Date(), false) // 의미없는 날짜, 무효한 근무
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
            // 🔧 수정: 모든 위젯 크기에서 isValidWork 체크
            if entry.isValidWork {
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
            } else {
                // 🆕 근무하지 않을 때 표시할 뷰
                switch entry.widgetFamily {
                case .systemSmall:
                    NotWorkingSmallView()
                case .systemMedium:
                    NotWorkingMediumView()
                case .accessoryCircular:
                    NotWorkingCircularView()
                case .accessoryRectangular:
                    NotWorkingRectangularView()
                case .accessoryInline:
                    NotWorkingInlineView()
                default:
                    NotWorkingSmallView()
                }
            }
        }
        .widgetURL(URL(string: "workoutTimer://open"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - 근무 중일 때 위젯 뷰들

struct SmallWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        // 🔧 수정: HStack으로 전체 컨테이너를 중앙 정렬
        HStack {
            Spacer()
            VStack(spacing: 2) {
                if Date() < entry.endDate {
                    Text("퇴근까지")
                        .font(.system(size: 12))
                    // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
                    Text(entry.endDate, style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("🏠 \(formattedEndTime)")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    VStack(spacing: 4) {
                        Text("🎉")
                            .font(.system(size: 32))
                        Text("퇴근이다!")
                            .font(.system(size: 16, weight: .bold))
                        Text("수고하셨습니다!")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.all, 8)
    }
}

struct MediumWidgetView: View {
    let entry: Provider.Entry
    let formattedEndTime: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if Date() < entry.endDate {
                HStack {
                    Spacer()
                    Text("퇴근까지")
                        .font(.headline)
                    Spacer()
                }
                // ✨ SwiftUI 자동 타이머 - 0에 도달하면 자동 정지
                Text(entry.endDate, style: .timer)
                    .monospacedDigit()
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                HStack {
                    Spacer()
                    Text("🏠 \(formattedEndTime)에 퇴근")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
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
                        .multilineTextAlignment(.center)
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
                .multilineTextAlignment(.center)
        } else {
            Text("퇴근 완료!")
        }
    }
}

// MARK: - 🆕 근무하지 않을 때 위젯 뷰들

struct NotWorkingSmallView: View {
    var body: some View {
        // 🔧 수정: 여기도 중앙 정렬 적용
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Text("😴")
                    .font(.system(size: 32))
                Text("휴식 중")
                    .font(.system(size: 16, weight: .semibold))
                Text("앱에서 출근하기")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.all, 8)
    }
}

struct NotWorkingMediumView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("😴")
                        .font(.system(size: 24))
                    Text("휴식 중")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Text("퇴근 타이머가 설정되지 않았습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("앱을 열어서 출근 설정을 해주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

struct NotWorkingCircularView: View {
    var body: some View {
        Text("😴")
            .font(.system(size: 20))
    }
}

struct NotWorkingRectangularView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center, spacing: 2) {
                Text("😴 휴식 중")
                    .font(.system(size: 14, weight: .semibold))
                Text("앱에서 출근하기")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct NotWorkingInlineView: View {
    var body: some View {
        Text("😴 휴식 중 - 앱에서 출근하기")
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
