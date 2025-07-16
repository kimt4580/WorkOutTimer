//
//  ContentView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 3/13/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var selectedHours: Int = 9
    @State private var isWorking: Bool
    @State private var startTime: Date?
    @State private var workEndTime: Double
    @State private var selectedDate: Date
    @State private var isHalfDayOff: Bool = false
    
    // Constants
    private struct Constants {
        static let appGroupIdentifier = "group.com.kimtaehun.WorkOutTimer"
        static let workEndTimeKey = "workEndTime"
        static let workStartTimeKey = "workStartTime"
    }
    
    // App Group UserDefaults with fallback
    private let defaults: UserDefaults
    
    // Static formatter for better performance
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
    
    let availableHours = Array(1...8)
    
    init() {
        // UserDefaults with fallback
        self.defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
        
        let workEndTime = defaults.double(forKey: Constants.workEndTimeKey)
        let startTime = defaults.object(forKey: Constants.workStartTimeKey) as? Date
        let now = Date().timeIntervalSince1970
        
        // Initialize state variables
        _workEndTime = State(initialValue: workEndTime)
        _startTime = State(initialValue: startTime)
        _isWorking = State(initialValue: workEndTime > now)
        _selectedDate = State(initialValue: startTime ?? Date())
    }
    
    var progress: Double {
        guard isWorking, let startTime = startTime else { return 0 }
        let now = Date()
        let endDate = Date(timeIntervalSince1970: workEndTime)
        
        // 현재 시간이 종료 시간을 초과한 경우
        if now > endDate {
            return 1
        }
        
        let totalDuration = endDate.timeIntervalSince(startTime)
        let elapsedTime = now.timeIntervalSince(startTime)
        return max(0, min(1, elapsedTime / totalDuration))
    }
    
    var formattedEndTime: String {
        Self.timeFormatter.string(from: Date(timeIntervalSince1970: workEndTime))
    }
    
    // 현재 설정된 출근 시간과 근무 시간 표시
    var currentWorkInfo: String {
        guard isWorking, let startTime = startTime else { return "" }
        let startTimeString = Self.timeFormatter.string(from: startTime)
        let endTimeString = formattedEndTime
        let totalHours = Int((workEndTime - startTime.timeIntervalSince1970) / 3600)
        let displayHours = totalHours == 9 ? 8 : totalHours // 9시간이면 8시간으로 표시
        return "🕘 \(startTimeString) ~ 🏠 \(endTimeString) (\(displayHours)시간)"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !isWorking {
                // 출근 시간 선택
                VStack(spacing: 12) {
                    Text("출근 시간")
                        .font(.headline)
                    DatePicker("출근 시간", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }
                .padding(.horizontal)
                
                // 반차 토글
                HStack {
                    Text("반차 사용")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $isHalfDayOff)
                        .labelsHidden()
                }
                .padding(.horizontal)
                
                // 현재 설정 표시
                VStack(spacing: 8) {
                    Text("근무 설정")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("근무시간: \(isHalfDayOff ? 4 : 8)시간")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("퇴근시간: \(Self.timeFormatter.string(from: selectedDate.addingTimeInterval(TimeInterval((isHalfDayOff ? 4 : 9) * 3600))))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // 현재 근무 정보 표시
                Text(currentWorkInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            }
            
            if isWorking {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(lineWidth: 15)
                        .opacity(0.2)
                        .foregroundColor(.red)
                    
                    // Progress circle (역방향으로 줄어들도록)
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(-90))
                    
                    // Content
                    VStack(spacing: 4) {
                        Text(Date().timeIntervalSince1970 < workEndTime ? "퇴근까지" : "퇴근 한지")
                            .font(.headline)
                        Text(Date(timeIntervalSince1970: workEndTime), style: .timer)
                            .font(.system(size: 40, weight: .bold))
                            .monospacedDigit()
                        Text("🏠 \(formattedEndTime)")
                            .font(.system(size: 20, weight: .semibold))
                    }
                }
                .frame(width: 250, height: 250)
                .padding(.vertical, 20)
                .accessibilityLabel("퇴근 타이머")
                .accessibilityValue("퇴근까지 \(Date(timeIntervalSince1970: workEndTime), style: .timer)")
            }
            
            if isWorking {
                Button("퇴근하기") {
                    endWork()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("퇴근 처리를 합니다")
            } else {
                Button("😱 출근하기") {
                    startWork()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("출근 타이머를 시작합니다")
            }
        }
        .padding()
        .alert("저장 실패", isPresented: .constant(false)) {
            Button("확인") { }
        } message: {
            Text("데이터 저장에 실패했습니다. 다시 시도해주세요.")
        }
    }
    
    private func startWork() {
        // 실제 근무시간: 반차면 4시간, 풀타임이면 8시간 + 점심 1시간 (내부적으로 9시간)
        let totalHours = isHalfDayOff ? 4 : 9
        
        startTime = selectedDate
        workEndTime = selectedDate.addingTimeInterval(TimeInterval(totalHours * 3600)).timeIntervalSince1970
        
        // UserDefaults 저장
        defaults.set(workEndTime, forKey: Constants.workEndTimeKey)
        defaults.set(startTime, forKey: Constants.workStartTimeKey)
        
        // 위젯 업데이트
        WidgetCenter.shared.reloadAllTimelines()
        
        isWorking = true
    }
    
    private func endWork() {
        startTime = nil
        workEndTime = 0
        
        // UserDefaults 정리
        defaults.set(0, forKey: Constants.workEndTimeKey)
        defaults.removeObject(forKey: Constants.workStartTimeKey)
        
        // 위젯 업데이트
        WidgetCenter.shared.reloadAllTimelines()
        
        isWorking = false
    }
}

#Preview {
    ContentView()
}
