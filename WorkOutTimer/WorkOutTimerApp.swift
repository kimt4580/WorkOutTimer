//
//  WorkOutTimerApp.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 3/13/25.
//

import SwiftUI

@main
struct WorkOutTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "workoutTimer" else {
            print("Unknown URL scheme: \(url)")
            return
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
