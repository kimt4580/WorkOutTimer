//
//  WorkOutTimerApp.swift
//  WorkOutTimer
//
//  Created by Lukus on 3/13/25.
//

import SwiftUI

@main
struct WorkOutTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard url.scheme == "workoutTimer" else {
                        print("Opened from widget: \(url)")
                        return
                    }
                    
                }
        }
    }
}
