//
//  MainTabView.swift
//  WorkOutTimer
//
//  Created by 김태훈 on 7/22/25.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WorkTimeView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("퇴근 타이머")
                }
            
            DutchPayView()
                .tabItem {
                    Image(systemName: "wonsign.circle.fill")
                    Text("더치페이")
                }
            
            RandomPickerView()
                .tabItem {
                    Image(systemName: "dice.fill")
                    Text("랜덤 뽑기")
                }
            AnimatedLadderView()
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("사다리 타기")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}
