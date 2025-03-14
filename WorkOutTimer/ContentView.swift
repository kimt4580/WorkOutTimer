//
//  ContentView.swift
//  WorkOutTimer
//
//  Created by Lukus on 3/13/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var selectedHours: Int = 9
    @State private var isWorking: Bool = false
    // startTime을 옵셔널(Date?)로 변경 및 기본값 nil 적용
    @State private var startTime: Date? = nil
    @State private var workEndTime: Double = 0
    @State private var selectedDate = Date()
    
    // App Group UserDefaults
    private let defaults = UserDefaults(suiteName: "group.com.kimtaehun.WorkOutTimer")
    
    let availableHours = Array(1...9)
    
    var progress: Double {
        // startTime이 설정되지 않았으면 0 리턴
        guard isWorking, let startTime = startTime else { return 0 }
        let endDate = Date(timeIntervalSince1970: workEndTime)
        let totalDuration = endDate.timeIntervalSince(startTime)
        let remainingTime = endDate.timeIntervalSince(Date())
        return max(0, min(1, remainingTime / totalDuration))
    }
    
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: Date(timeIntervalSince1970: workEndTime))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !isWorking {
                // DatePicker는 selectedDate를 사용합니다.
                DatePicker("출근 시간", selection: $selectedDate, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                
                Picker("근무 시간", selection: $selectedHours) {
                    ForEach(availableHours, id: \.self) { hour in
                        Text("\(hour)시간")
                    }
                }
                .pickerStyle(.wheel)
            }
            
            if isWorking {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(lineWidth: 15)
                        .opacity(0.2)
                        .foregroundColor(.red)
                    
                    // Progress circle: 0부터 progress까지 채워지도록 변경
                    Circle()
                        .trim(from: 0, to: 1 - progress)
                        .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(-90))
                    
                    // Content
                    VStack(spacing: 4) {
                        Text("퇴근까지")
                            .font(.headline)
                        Text(Date(timeIntervalSince1970: workEndTime), style: .timer)
                            .font(.system(size: 40, weight: .bold))
                        Text("🏠 \(formattedEndTime)")
                            .font(.system(size: 20, weight: .semibold))
                    }
                }
                .frame(width: 250, height: 250)
                .padding(.vertical, 20)
            } else {
                Text("퇴근까지")
                    .font(.headline)
            }
            
            if isWorking {
                Button("퇴근하기") {
                    endWork()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("😱 출근하기") {
                    startWork()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            // 저장된 값을 불러올 때 Date 타입으로 변환합니다.
            workEndTime = defaults?.double(forKey: "workEndTime") ?? 0
            // 저장된 값이 없다면 startTime은 nil로 남깁니다.
            startTime = defaults?.object(forKey: "workStartTime") as? Date
            let now = Date().timeIntervalSince1970
            isWorking = workEndTime > now
            if !isWorking {
                selectedDate = Date()
            }
        }
    }
    
    private func startWork() {
        // DatePicker에서 선택된 값을 출근 시간으로 사용
        startTime = selectedDate
        workEndTime = selectedDate.addingTimeInterval(TimeInterval(selectedHours * 3600)).timeIntervalSince1970
        // UserDefaults에 저장 및 위젯 업데이트
        defaults?.set(workEndTime, forKey: "workEndTime")
        defaults?.set(startTime, forKey: "workStartTime")
        WidgetCenter.shared.reloadAllTimelines()
        isWorking = true
    }
    
    private func endWork() {
        // 종료 시 startTime을 nil로 설정해줍니다.
        startTime = nil
        workEndTime = 0
        // UserDefaults 저장 및 위젯 업데이트
        defaults?.set(0, forKey: "workEndTime")
        defaults?.removeObject(forKey: "workStartTime")
        WidgetCenter.shared.reloadAllTimelines()
        isWorking = false
    }
}

#Preview {
    ContentView()
}
