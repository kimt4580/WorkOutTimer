//
//  WorkOutTimerApp.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 3/13/25.
//

import SwiftUI
import UserNotifications

// 🔔 알림 델리게이트 클래스
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // 앱이 포그라운드에 있을 때 알림이 왔을 때 호출
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 포그라운드에서도 알림을 표시
        completionHandler([.banner, .sound, .badge])
    }
    
    // 사용자가 알림을 탭했을 때 호출
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // 퇴근 알림인지 확인
        if let type = userInfo["type"] as? String, type == "workEnd" {
            print("🎉 퇴근 알림을 탭했습니다!")
            // 필요하다면 특정 액션 수행
        }
        
        // 🔔 Badge 초기화
        center.setBadgeCount(0) { error in
            if let error = error {
                print("Badge 초기화 실패: \(error.localizedDescription)")
            } else {
                print("📱 알림 탭으로 Badge 초기화 완료")
            }
        }
        
        completionHandler()
    }
}

@main
struct WorkOutTimerApp: App {
    @State private var notificationDelegate = NotificationDelegate()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    setupNotificationDelegate()
                }
        }
    }
    
    // 🔔 알림 델리게이트 설정
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "workoutTimer" else {
            print("Unknown URL scheme: \(url)")
            return
        }
        
        // 🔔 딥링크로 앱이 열릴 때 badge 초기화
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("딥링크에서 Badge 초기화 실패: \(error.localizedDescription)")
            } else {
                print("📱 딥링크에서 Badge 초기화 완료")
            }
        }
        
        switch url.host {
        case "open":
            // 위젯에서 앱을 열었을 때
            print("Opened from widget")
            // 필요하다면 특정 뷰로 이동하거나 액션 수행
        default:
            print("Unknown host: \(url.host ?? "nil")")
        }
    }
}
