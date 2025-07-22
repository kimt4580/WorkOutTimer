//
//  WorkTimerViewModel.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import SwiftUI
import WidgetKit
import UserNotifications
import Combine

@MainActor
class WorkTimerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isWorking: Bool = false
    @Published var startTime: Date?
    @Published var workEndTime: Double = 0
    @Published var selectedDate: Date = Date()
    @Published var isHalfDayOff: Bool = false
    @Published var notificationPermissionGranted: Bool = false
    @Published var showingDataCleanupAlert: Bool = false
    
    // MARK: - Private Properties
    private let defaults: UserDefaults
    private var timerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private struct Constants {
        static let appGroupIdentifier = "group.com.th.WorkOutTimer"
        static let workEndTimeKey = "workEndTime"
        static let workStartTimeKey = "workStartTime"
        static let workDateKey = "workDate"
        static let notificationIdentifier = "workEndNotification"
        static let overdueNotificationIdentifier = "workOverdueNotification"
        
        static let fullDayHours = 8
        static let halfDayHours = 4
        static let lunchBreakHours = 1
        static let autoCleanupHours = 4 // 4시간 후 자동 정리
    }
    
    // MARK: - Formatters
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter
    }()
    
    // MARK: - Computed Properties
    var progress: Double {
        guard isWorking, let startTime = startTime else { return 0 }
        let now = Date()
        let endDate = Date(timeIntervalSince1970: workEndTime)
        
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
    
    var currentWorkInfo: String {
        guard isWorking, let startTime = startTime else { return "" }
        let startTimeString = Self.timeFormatter.string(from: startTime)
        let endTimeString = formattedEndTime
        let totalHours = Int((workEndTime - startTime.timeIntervalSince1970) / 3600)
        let displayHours = totalHours == 9 ? 8 : totalHours
        return "🕘 \(startTimeString) ~ 🏠 \(endTimeString) (\(displayHours)시간)"
    }
    
    var isOvertime: Bool {
        guard isWorking else { return false }
        return Date().timeIntervalSince1970 > workEndTime
    }
    
    var previewEndTime: String {
        let todayWorkTime = createTodayWorkTime(from: selectedDate)
        let totalHours = isHalfDayOff ? Constants.halfDayHours : (Constants.fullDayHours + Constants.lunchBreakHours)
        let endTime = todayWorkTime.addingTimeInterval(TimeInterval(totalHours * 3600))
        return Self.timeFormatter.string(from: endTime)
    }
    
    var workHoursText: String {
        return "\(isHalfDayOff ? Constants.halfDayHours : Constants.fullDayHours)시간"
    }
    
    // MARK: - Initialization
    init() {
        self.defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) ?? .standard
        
        loadWorkData()
        setupBindings()
        checkNotificationPermission()
    }
    
    deinit {
        // Timer와 다른 cancellables 모두 정리
        timerCancellable?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Data Management
    private func loadWorkData() {
        let savedWorkEndTime = defaults.double(forKey: Constants.workEndTimeKey)
        let savedStartTime = defaults.object(forKey: Constants.workStartTimeKey) as? Date
        let workDateString = defaults.string(forKey: Constants.workDateKey)
        
        let now = Date()
        let today = Self.dateFormatter.string(from: now)
        
        let isValidWorkDay = workDateString == today
        let isWorkTimeValid = savedWorkEndTime > now.timeIntervalSince1970
        let isCurrentlyWorking = savedWorkEndTime > 0 && isValidWorkDay && isWorkTimeValid
        
        workEndTime = savedWorkEndTime
        startTime = savedStartTime
        isWorking = isCurrentlyWorking
        selectedDate = savedStartTime ?? now
        
        if (!isValidWorkDay || !isWorkTimeValid) && savedWorkEndTime > 0 {
            cleanupOldWorkData()
        }
        
        if isWorking {
            startTimer()
        }
    }
    
    private func saveWorkData() {
        let today = Self.dateFormatter.string(from: Date())
        
        defaults.set(workEndTime, forKey: Constants.workEndTimeKey)
        defaults.set(startTime, forKey: Constants.workStartTimeKey)
        defaults.set(today, forKey: Constants.workDateKey)
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func cleanupOldWorkData() {
        defaults.set(0, forKey: Constants.workEndTimeKey)
        defaults.removeObject(forKey: Constants.workStartTimeKey)
        defaults.removeObject(forKey: Constants.workDateKey)
        
        cancelAllNotifications()
        WidgetCenter.shared.reloadAllTimelines()
        
        showingDataCleanupAlert = true
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        stopTimer() // 기존 타이머 정리
        
        // 전용 Timer cancellable로 더 정교한 관리
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    // MARK: - Notification Management
    func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]
                )
                notificationPermissionGranted = granted
                if granted {
                    clearNotificationBadge()
                }
            } catch {
                print("알림 권한 요청 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func checkNotificationPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationPermissionGranted = settings.authorizationStatus == .authorized
            if notificationPermissionGranted {
                clearNotificationBadge()
            }
        }
    }
    
    private func clearNotificationBadge() {
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("Badge 초기화 실패: \(error.localizedDescription)")
            }
        }
    }
    
    private func scheduleEndWorkNotification(endTime: Date) {
        cancelAllNotifications()
        
        guard endTime > Date() else {
            print("퇴근 시간이 현재 시간보다 과거입니다.")
            return
        }
        
        // 퇴근 시간 알림
        let endContent = UNMutableNotificationContent()
        endContent.title = "🎉 퇴근 시간!"
        endContent.body = "수고하셨습니다! 오늘 하루도 고생 많으셨어요."
        endContent.sound = UNNotificationSound.default
        endContent.badge = 1
        endContent.userInfo = ["type": "workEnd", "endTime": endTime.timeIntervalSince1970]
        
        let endTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: endTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let endRequest = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: endContent,
            trigger: endTrigger
        )
        
        // 연장근무 알림 (30분 후)
        let overtimeEndTime = endTime.addingTimeInterval(1800)
        if overtimeEndTime > Date() {
            let overtimeContent = UNMutableNotificationContent()
            overtimeContent.title = "⏰ 연장근무 중"
            overtimeContent.body = "퇴근 시간이 지났습니다. 오늘도 수고 많으셨어요!"
            overtimeContent.sound = UNNotificationSound.default
            overtimeContent.badge = 1
            overtimeContent.userInfo = ["type": "overtime"]
            
            let overtimeTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: overtimeEndTime.timeIntervalSinceNow,
                repeats: false
            )
            
            let overtimeRequest = UNNotificationRequest(
                identifier: Constants.overdueNotificationIdentifier,
                content: overtimeContent,
                trigger: overtimeTrigger
            )
            
            UNUserNotificationCenter.current().add(overtimeRequest) { error in
                if let error = error {
                    print("연장근무 알림 스케줄링 실패: \(error.localizedDescription)")
                }
            }
        }
        
        UNUserNotificationCenter.current().add(endRequest) { error in
            if let error = error {
                print("퇴근 알림 스케줄링 실패: \(error.localizedDescription)")
            } else {
                print("퇴근 알림이 \(Self.timeFormatter.string(from: endTime))에 설정되었습니다.")
            }
        }
    }
    
    private func cancelAllNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Constants.notificationIdentifier, Constants.overdueNotificationIdentifier]
        )
        clearNotificationBadge()
    }
    
    // MARK: - Helper Methods
    private func createTodayWorkTime(from selectedTime: Date) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 9,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: today
        ) ?? today
    }
    
    func validateWorkDate() {
        let today = Self.dateFormatter.string(from: Date())
        let savedWorkDate = defaults.string(forKey: Constants.workDateKey)
        
        if savedWorkDate != today && isWorking {
            endWork()
            return
        }
        
        if isWorking && workEndTime > 0 {
            let now = Date().timeIntervalSince1970
            let autoCleanupTime = workEndTime + TimeInterval(Constants.autoCleanupHours * 3600)
            
            if now > autoCleanupTime {
                print("⏰ 연장근무 시간이 너무 지났습니다. 자동으로 퇴근 처리합니다.")
                endWork()
            }
        }
    }
    
    func handleAppBecomeActive() {
        validateWorkDate()
        if notificationPermissionGranted {
            clearNotificationBadge()
        }
    }
    
    // MARK: - Bindings Setup
    private func setupBindings() {
        // 반차 상태 변경 시 미리보기 업데이트를 위한 바인딩
        $isHalfDayOff
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        $selectedDate
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Actions
    func startWork() {
        let todayWorkTime = createTodayWorkTime(from: selectedDate)
        let totalHours = isHalfDayOff ? Constants.halfDayHours : (Constants.fullDayHours + Constants.lunchBreakHours)
        let endTime = todayWorkTime.addingTimeInterval(TimeInterval(totalHours * 3600))
        
        let now = Date()
        if endTime <= now {
            // 내일로 설정
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: todayWorkTime) ?? todayWorkTime
            let tomorrowEndTime = tomorrow.addingTimeInterval(TimeInterval(totalHours * 3600))
            
            startTime = tomorrow
            workEndTime = tomorrowEndTime.timeIntervalSince1970
        } else {
            startTime = todayWorkTime
            workEndTime = endTime.timeIntervalSince1970
        }
        
        saveWorkData()
        
        if notificationPermissionGranted {
            scheduleEndWorkNotification(endTime: Date(timeIntervalSince1970: workEndTime))
        }
        
        isWorking = true
        startTimer()
    }
    
    func endWork() {
        startTime = nil
        workEndTime = 0
        
        defaults.set(0, forKey: Constants.workEndTimeKey)
        defaults.removeObject(forKey: Constants.workStartTimeKey)
        defaults.removeObject(forKey: Constants.workDateKey)
        
        cancelAllNotifications()
        WidgetCenter.shared.reloadAllTimelines()
        
        isWorking = false
        stopTimer()
    }
}
