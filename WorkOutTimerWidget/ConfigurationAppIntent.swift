//
//  ConfigurationAppIntent.swift
//  WorkOutTimerWidgetExtension
//
//  Created by 김태훈 on 3/13/25.
//

import AppIntents
import SwiftUI

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "퇴근 타이머 설정"
    static var description: LocalizedStringResource = "위젯 설정을 변경합니다."
}
