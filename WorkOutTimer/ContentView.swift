//
//  ContentView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 3/13/25.
//

import SwiftUI
import WidgetKit
import UserNotifications

struct ContentView: View {
    @State private var selectedHours: Int = 9
    @State private var isWorking: Bool
    @State private var startTime: Date?
    @State private var workEndTime: Double
    @State private var selectedDate: Date
    @State private var isHalfDayOff: Bool = false
    @State private var notificationPermissionGranted: Bool = false
    
    // Constants
    private struct Constants {
        static let appGroupIdentifier = "group.com.th.WorkOutTimer"
        static let workEndTimeKey = "workEndTime"
        static let workStartTimeKey = "workStartTime"
        static let workDateKey = "workDate" // 추가: 근무 날짜 저장
        static let notificationIdentifier = "workEndNotification"
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
    
    // 날짜 포맷터 추가
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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
        let workDateString = defaults.string(forKey: Constants.workDateKey)
        
        let now = Date()
        let today = Self.dateFormatter.string(from: now)
        
        // 🔍 날짜 검증: 저장된 근무일이 오늘과 같은지 확인
        let isValidWorkDay = workDateString == today
        
        // 🕰️ 퇴근 시간 검증: 현재 시간이 퇴근 시간을 넘었는지 확인
        let isWorkTimeValid = workEndTime > now.timeIntervalSince1970
        
        let isCurrentlyWorking = workEndTime > 0 && isValidWorkDay && isWorkTimeValid
        
        // Initialize state variables
        _workEndTime = State(initialValue: workEndTime)
        _startTime = State(initialValue: startTime)
        _isWorking = State(initialValue: isCurrentlyWorking)
        _selectedDate = State(initialValue: startTime ?? now)
        
        // 🧹 데이터 정리: 오늘이 아니거나 퇴근 시간이 지난 경우
        if (!isValidWorkDay || !isWorkTimeValid) && workEndTime > 0 {
            self.cleanupOldWorkData()
        }
    }
    
    // 🧹 이전 날짜 데이터 정리
    private func cleanupOldWorkData() {
        defaults.set(0, forKey: Constants.workEndTimeKey)
        defaults.removeObject(forKey: Constants.workStartTimeKey)
        defaults.removeObject(forKey: Constants.workDateKey)
        
        // 기존 알림도 삭제
        cancelEndWorkNotification()
    }
    
    // 🔔 알림 badge 초기화 (iOS 16+ 호환)
    private func clearNotificationBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("Badge 초기화 실패: \(error.localizedDescription)")
                } else {
                    print("📱 Badge 초기화 완료")
                }
            }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
                print("📱 Badge 초기화 완료 (iOS 15 이하)")
            }
        }
    }
    
    // 📱 알림 권한 요청
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted
                if let error = error {
                    print("알림 권한 요청 실패: \(error.localizedDescription)")
                } else if granted {
                    // 권한 승인 시 badge 초기화
                    self.clearNotificationBadge()
                }
            }
        }
    }
    
    // 🔔 퇴근 시간 알림 스케줄링
    private func scheduleEndWorkNotification(endTime: Date) {
        // 🚫 기존 알림 먼저 취소
        cancelEndWorkNotification()
        
        // ⏰ 퇴근 시간이 현재 시간보다 미래인지 확인
        let now = Date()
        guard endTime > now else {
            print("퇴근 시간이 현재 시간보다 과거입니다. 알림을 설정하지 않습니다.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 퇴근 시간!"
        content.body = "수고하셨습니다! 오늘 하루도 고생 많으셨어요."
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        // 사용자 정보 추가 (알림 탭 시 앱에서 활용 가능)
        content.userInfo = ["type": "workEnd", "endTime": endTime.timeIntervalSince1970]
        
        // 퇴근 시간에 맞춰 트리거 설정
        let timeInterval = endTime.timeIntervalSinceNow
        guard timeInterval > 0 else {
            print("시간 간격이 음수입니다. 알림을 설정하지 않습니다.")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 스케줄링 실패: \(error.localizedDescription)")
            } else {
                print("퇴근 알림이 \(Self.timeFormatter.string(from: endTime))에 설정되었습니다.")
            }
        }
    }
    
    // 🗑️ 알림 취소
    private func cancelEndWorkNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])
        // 퇴근 알림을 취소할 때 badge도 초기화
        clearNotificationBadge()
    }
    
    // 🔍 알림 권한 상태 확인
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = settings.authorizationStatus == .authorized
                
                // 권한이 있으면 badge 초기화
                if self.notificationPermissionGranted {
                    self.clearNotificationBadge()
                }
            }
        }
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
    
    // 🗓️ 오늘 날짜 기준으로 근무 시간 생성
    private func createTodayWorkTime(from selectedTime: Date) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        return calendar.date(bySettingHour: timeComponents.hour ?? 9,
                           minute: timeComponents.minute ?? 0,
                           second: 0,
                           of: today) ?? today
    }
    
    // 🔍 근무 날짜 유효성 검증
    private func validateWorkDate() {
        let today = Self.dateFormatter.string(from: Date())
        let savedWorkDate = defaults.string(forKey: Constants.workDateKey)
        
        if savedWorkDate != today && isWorking {
            // 다른 날짜의 근무 데이터가 있으면 정리
            endWork()
            return
        }
        
        // 🕰️ 퇴근 시간이 지났는지 확인
        if isWorking && workEndTime > 0 {
            let now = Date().timeIntervalSince1970
            if now > workEndTime {
                // 퇴근 시간이 지났으면 자동으로 퇴근 처리
                print("⏰ 퇴근 시간이 지났습니다. 자동으로 퇴근 처리합니다.")
                endWork()
            }
        }
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
                    
                    // 🗓️ 오늘 날짜 기준으로 퇴근시간 계산
                    let todayWorkTime = createTodayWorkTime(from: selectedDate)
                    let endTime = todayWorkTime.addingTimeInterval(TimeInterval((isHalfDayOff ? 4 : 9) * 3600))
                    
                    Text("퇴근시간: \(Self.timeFormatter.string(from: endTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // 🔔 알림 상태 표시
                    HStack(spacing: 4) {
                        Image(systemName: notificationPermissionGranted ? "bell.fill" : "bell.slash")
                            .foregroundColor(notificationPermissionGranted ? .green : .orange)
                        Text(notificationPermissionGranted ? "퇴근 알림 활성화" : "알림 권한 필요")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 🔔 알림 권한 요청 버튼 (권한이 없을 때만 표시)
                if !notificationPermissionGranted {
                    Button("🔔 알림 허용하기") {
                        requestNotificationPermission()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.orange)
                }
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
        .onAppear {
            // 🔄 앱이 포그라운드로 올 때마다 날짜 검증
            validateWorkDate()
            // 🔔 알림 권한 상태 확인 및 badge 초기화
            checkNotificationPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // 🔄 앱이 활성화될 때마다 상태 검증 및 badge 초기화
            validateWorkDate()
            if notificationPermissionGranted {
                clearNotificationBadge()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // 🔄 앱이 포그라운드로 올 때마다 badge 초기화
            if notificationPermissionGranted {
                clearNotificationBadge()
            }
        }
        .alert("저장 실패", isPresented: .constant(false)) {
            Button("확인") { }
        } message: {
            Text("데이터 저장에 실패했습니다. 다시 시도해주세요.")
        }
    }
    
    private func startWork() {
        // 🗓️ 오늘 날짜 기준으로 출근 시간 설정
        let todayWorkTime = createTodayWorkTime(from: selectedDate)
        let totalHours = isHalfDayOff ? 4 : 9
        let endTime = todayWorkTime.addingTimeInterval(TimeInterval(totalHours * 3600))
        
        // ⚠️ 퇴근 시간이 현재 시간보다 과거인지 확인
        let now = Date()
        if endTime <= now {
            // 퇴근 시간이 과거라면 내일로 설정
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: todayWorkTime) ?? todayWorkTime
            let tomorrowEndTime = tomorrow.addingTimeInterval(TimeInterval(totalHours * 3600))
            
            startTime = tomorrow
            workEndTime = tomorrowEndTime.timeIntervalSince1970
            
            print("⚠️ 선택한 시간이 과거입니다. 내일 \(Self.timeFormatter.string(from: tomorrow))로 설정됩니다.")
        } else {
            startTime = todayWorkTime
            workEndTime = endTime.timeIntervalSince1970
        }
        
        // 📅 오늘 날짜도 함께 저장 (내일로 설정되어도 오늘 날짜로 저장)
        let today = Self.dateFormatter.string(from: Date())
        
        // UserDefaults 저장
        defaults.set(workEndTime, forKey: Constants.workEndTimeKey)
        defaults.set(startTime, forKey: Constants.workStartTimeKey)
        defaults.set(today, forKey: Constants.workDateKey) // 날짜 저장
        
        // 🔔 알림 권한이 있으면 퇴근 알림 스케줄링
        if notificationPermissionGranted {
            let finalEndTime = Date(timeIntervalSince1970: workEndTime)
            scheduleEndWorkNotification(endTime: finalEndTime)
        }
        
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
        defaults.removeObject(forKey: Constants.workDateKey) // 날짜 정보도 삭제
        
        // 🔔 예약된 알림 취소 및 badge 초기화
        cancelEndWorkNotification()
        
        // 위젯 업데이트
        WidgetCenter.shared.reloadAllTimelines()
        
        isWorking = false
    }
}

#Preview {
    ContentView()
}
